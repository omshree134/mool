import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/native_bridge.dart';
import '../../core/settings.dart';
import '../repository.dart';
import 'evidence_service.dart';
import 'trusted_contacts.dart';

enum SosStepState { pending, running, done, failed, skipped }

class SosStep {
  SosStep(this.label);
  final String label;
  SosStepState state = SosStepState.pending;
  String? note;
}

/// "I'm in danger".
///
/// Fixes compared with Abhaya's _triggerSos:
///  * Abhaya awaited a high-accuracy GPS fix and then a Firestore write before
///    sending any SMS. Indoors or offline this could take minutes or never
///    finish. Here location waits at most 6 s (falling back to the last known
///    fix) and the Firestore write runs alongside the SMS, never before it.
///  * One failure no longer stops everything. Each step reports its own
///    result so the person can see what worked, and try the next thing.
///  * Abhaya's catch block swallowed every error and left `_busy` set, so a
///    single failure disabled SOS until the app restarted.
///  * Abhaya dialled 999 (a demo number) and opened the dialer. Here 112 is
///    called directly when the phone permission is granted.
///  * No fake telemetry. Abhaya sent a hard-coded heart rate of 72 and
///    battery of 88% to the dashboard as if they were real.
class SosService extends ChangeNotifier {
  SosService._();
  static final SosService instance = SosService._();

  bool _active = false;
  String? _sosId;
  DateTime? startedAt;
  List<SosStep> steps = [];

  bool get active => _active;

  Future<void> trigger({required String reason}) async {
    if (_active) return;
    _active = true;
    final id = Repo.instance.newId();
    _sosId = id;
    startedAt = DateTime.now();

    final s = Settings.instance;
    final contacts = TrustedContacts.instance.all;
    final locate = SosStep('Finding your location');
    final sms = SosStep(contacts.isEmpty
        ? 'Messaging trusted people'
        : 'Messaging ${contacts.length} trusted ${contacts.length == 1 ? 'person' : 'people'}');
    final team = SosStep('Alerting your support team');
    final audio = SosStep('Recording audio');
    final call = SosStep('Calling 112');
    steps = [locate, sms, team, if (s.recordAudioOnSos) audio, if (s.call112OnSos) call];
    notifyListeners();

    // Audio doesn't depend on anything else, so it starts first.
    final audioDone = s.recordAudioOnSos
        ? _run<void>(audio, () => EvidenceService.instance.startAudio(linkedTo: 'sos/$id', kind: 'sos'))
        : Future<void>.value();

    final pos = await _run<Position?>(locate, _quickPosition,
        problem: (p) => p == null ? 'Location unavailable; messages will go without it' : null);

    final smsDone = contacts.isEmpty
        ? _mark(sms, SosStepState.skipped, 'No trusted people added yet')
        : _run<int>(sms, () => _messageContacts(contacts, pos),
            problem: (sent) => sent == 0
                ? 'Messages could not be sent'
                : sent < contacts.length
                    ? 'Sent to $sent of ${contacts.length}'
                    : null);

    final teamDone = _run<bool>(team, () async {
      final share = s.shareLocationOnSos && pos != null;
      final confirmed = await Repo.instance.createSos(
        id,
        reason: reason,
        lat: share ? pos.latitude : null,
        lng: share ? pos.longitude : null,
        accuracy: share ? pos.accuracy : null,
      );
      if (!confirmed) team.note = "Queued. It'll send as soon as you have internet.";
      return confirmed;
    });

    // SMS goes out before the call takes over the screen.
    await smsDone;
    if (s.call112OnSos) {
      await _run<bool>(call, () async {
        final direct = await NativeBridge.placeCall('112');
        if (!direct) call.note = 'Opened the dialer. Press call.';
        return direct;
      });
    }
    await teamDone;
    await audioDone;
  }

  Future<void> end() async {
    if (!_active) return;
    final id = _sosId;
    _active = false;
    _sosId = null;
    startedAt = null;
    steps = [];
    notifyListeners();
    if (EvidenceService.instance.recording) unawaited(EvidenceService.instance.stopAudio());
    if (id != null) Repo.instance.resolveSos(id);
  }

  Future<void> _mark(SosStep step, SosStepState state, String note) async {
    step.state = state;
    step.note = note;
    notifyListeners();
  }

  Future<T?> _run<T>(SosStep step, Future<T> Function() op, {String? Function(T value)? problem}) async {
    step.state = SosStepState.running;
    notifyListeners();
    try {
      final value = await op();
      final issue = problem?.call(value);
      step.state = issue == null ? SosStepState.done : SosStepState.failed;
      step.note = issue ?? step.note;
      return value;
    } catch (e) {
      step.state = SosStepState.failed;
      step.note = _friendly(e);
      return null;
    } finally {
      notifyListeners();
    }
  }

  String _friendly(Object e) {
    final text = e.toString();
    if (text.contains('PERMISSION')) return 'Permission is off in phone settings';
    if (text.contains('Microphone')) return 'Microphone is off for Mool';
    return 'Could not complete this step';
  }

  Future<Position?> _quickPosition() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
    final last = await Geolocator.getLastKnownPosition();
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
    } catch (_) {
      return last;
    }
  }

  Future<int> _messageContacts(List<TrustedContact> contacts, Position? pos) async {
    if (!await Permission.sms.isGranted) {
      throw StateError('PERMISSION');
    }
    final body = _message(pos);
    final results = await Future.wait(contacts.map((c) async {
      try {
        return await NativeBridge.sendSms(c.phone, body);
      } catch (e) {
        debugPrint('SMS to a contact failed: $e');
        return false;
      }
    }));
    return results.where((ok) => ok).length;
  }

  String _message(Position? p) {
    final s = Settings.instance;
    final name = s.displayName.trim().isEmpty ? 'Someone who trusts you' : s.displayName.trim();
    final b = StringBuffer('URGENT: $name may be in danger and needs help. ');
    if (p != null && s.shareLocationOnSos) {
      final ageMin = DateTime.now().difference(p.timestamp).inMinutes;
      b.write('Location: https://maps.google.com/?q=${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}');
      if (ageMin >= 2) b.write(' (from $ageMin min ago)');
      b.write('. ');
    }
    b.write('Please call them now. If you cannot reach them, call 112.');
    return b.toString();
  }

  /// A test message so trusted people know they've been added, and so the
  /// person finds out now, not in an emergency, if SMS doesn't work.
  Future<bool> sendTestMessage(TrustedContact c) async {
    if (!await Permission.sms.request().isGranted) return false;
    final name = Settings.instance.displayName.trim();
    final who = name.isEmpty ? 'A friend' : name;
    try {
      return await NativeBridge.sendSms(
        c.phone,
        '$who has added you as a trusted person. If they ever press their emergency button, '
        "you'll get a message with their location. No need to reply.",
      );
    } catch (_) {
      return false;
    }
  }
}
