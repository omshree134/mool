import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/dates.dart';
import '../../core/local_store.dart';
import '../../core/notifier.dart';
import '../sensing/mobility_service.dart';

class _Sighting {
  _Sighting(this.at, this.lat, this.lng, this.fast);
  final DateTime at;
  final double lat;
  final double lng;
  final bool fast;
}

class _Track {
  final List<_Sighting> sightings = [];
  bool tracker = false;
}

class SuspiciousDevice {
  SuspiciousDevice({required this.id, required this.tracker, required this.places, required this.minutes});
  final String id;
  final bool tracker;
  final int places;
  final int minutes;
}

/// Looks for a Bluetooth device that keeps turning up in different places
/// the person goes. It never raises an SOS; it only asks the person.
///
/// Why Abhaya's detector flagged almost everything:
///  * FlutterBluePlus.scanResults re-emits the whole result list on every
///    advertisement, and Abhaya added +1 "seen" per emission. Every device in
///    a café hit full persistence within seconds. Here each device counts
///    once per scan cycle.
///  * Your own earbuds and watch go everywhere with you, so they always looked
///    like followers. Here paired devices, devices at home overnight and
///    devices marked "mine" are ignored.
///  * Distance was measured over only ~60 seconds of GPS points.
///  * Scanning every 2 seconds breaks Android's limit (5 scan starts per
///    30 s), after which Android silently returns nothing. Here one 8-second
///    scan runs per minute.
///
/// A device is only flagged when it's been seen at 3+ places at least 400 m
/// apart, over 30+ minutes (15 for known tracker tags). For non-tracker
/// devices, sightings while moving fast are ignored, so people on the same
/// bus don't count.
///
/// Limit: phones rotate their Bluetooth address every ~15 minutes, so this
/// works best for tracker tags and fixed-address devices. The UI says this
/// honestly rather than implying full protection.
class IntimidationWatch extends ChangeNotifier {
  IntimidationWatch._();
  static final IntimidationWatch instance = IntimidationWatch._();

  static const _ignoredKey = 'follow.ignored';
  static const _householdKey = 'follow.household';

  final Map<String, _Track> _tracks = {};
  final List<SuspiciousDevice> alerts = [];
  final Map<String, DateTime> _alertedAt = {};
  Timer? _cycle;
  bool _scanning = false;

  bool get running => _cycle != null;

  Set<String> get _ignored => (LocalStore.instance.getJsonList(_ignoredKey).map((m) => m['id'] as String)).toSet();

  Future<void> start() async {
    if (_cycle != null) return;
    await _ignorePairedDevices();
    _cycle = Timer.periodic(const Duration(seconds: 60), (_) => _scanCycle());
    unawaited(_scanCycle());
  }

  void stop() {
    _cycle?.cancel();
    _cycle = null;
    _tracks.clear();
    alerts.clear();
    notifyListeners();
    FlutterBluePlus.stopScan().catchError((Object _) {});
  }

  Future<void> markAsKnown(String id) async {
    final list = LocalStore.instance.getJsonList(_ignoredKey)..add({'id': id});
    await LocalStore.instance.setJsonList(_ignoredKey, list);
    _tracks.remove(id);
    alerts.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  void dismiss(String id) {
    alerts.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  Future<void> _ignorePairedDevices() async {
    try {
      final bonded = await FlutterBluePlus.bondedDevices;
      final list = LocalStore.instance.getJsonList(_ignoredKey);
      final known = list.map((m) => m['id']).toSet();
      for (final d in bonded) {
        if (!known.contains(d.remoteId.str)) list.add({'id': d.remoteId.str});
      }
      await LocalStore.instance.setJsonList(_ignoredKey, list);
    } catch (e) {
      debugPrint('Could not read paired devices: $e');
    }
  }

  Future<void> _scanCycle() async {
    if (_scanning) return;
    _scanning = true;
    StreamSubscription<List<ScanResult>>? sub;
    try {
      if (!await FlutterBluePlus.isSupported) return;
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) return;

      final seen = <String, bool>{}; // id → looks like a tracker tag
      sub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          if (r.rssi < -80) continue; // too far away to matter
          final id = r.device.remoteId.str;
          if (id.isEmpty) continue;
          seen[id] = (seen[id] ?? false) || _looksLikeTracker(r.advertisementData);
        }
      });
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
      await FlutterBluePlus.isScanning.where((s) => !s).first.timeout(
            const Duration(seconds: 15),
            onTimeout: () => false,
          );

      final pos = await _position();
      if (pos == null) return; // without location we can't tell "following" from "nearby"
      _record(seen, pos);
      _evaluate();
    } catch (e) {
      debugPrint('Follow watch scan: $e');
    } finally {
      await sub?.cancel();
      _scanning = false;
    }
  }

  Future<Position?> _position() async {
    final last = MobilityService.instance.lastPosition;
    if (last != null && DateTime.now().difference(last.timestamp) < const Duration(minutes: 3)) return last;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Apple Find My (offline-finding frame 0x12), Tile (0xFEED/0xFEEC) and
  /// Samsung SmartTag (0xFD5A), as documented in open tracker-detection
  /// research such as AirGuard. A heuristic, not a guarantee.
  static bool _looksLikeTracker(AdvertisementData a) {
    final apple = a.manufacturerData[0x004C];
    if (apple != null && apple.isNotEmpty && apple[0] == 0x12) return true;
    for (final g in a.serviceUuids) {
      final s = g.toString().toLowerCase();
      for (final short in const ['feed', 'feec', 'fd5a']) {
        if (s == short || s.startsWith('0000$short-')) return true;
      }
    }
    return false;
  }

  void _record(Map<String, bool> seen, Position pos) {
    final now = DateTime.now();
    final ignored = _ignored;
    final household = LocalStore.instance.getJson(_householdKey);
    final atHomeAtNight = (now.hour >= 22 || now.hour < 6) &&
        MobilityService.instance.isNearHome(pos.latitude, pos.longitude);
    final fast = pos.speed > 8.3; // ~30 km/h
    var householdChanged = false;

    seen.forEach((id, tracker) {
      if (ignored.contains(id)) return;
      if (atHomeAtNight) {
        // Devices that sleep at home on 2+ nights belong to the household.
        final nights = List<String>.from((household[id] as List?) ?? const []);
        final key = dateKey(now);
        if (!nights.contains(key)) {
          nights.add(key);
          household[id] = nights;
          householdChanged = true;
        }
        return;
      }
      if (((household[id] as List?)?.length ?? 0) >= 2) return;
      final track = _tracks.putIfAbsent(id, _Track.new);
      track.tracker = track.tracker || tracker;
      track.sightings.add(_Sighting(now, pos.latitude, pos.longitude, fast));
    });

    if (householdChanged) LocalStore.instance.setJson(_householdKey, household);

    // Keep two hours of history.
    for (final t in _tracks.values) {
      t.sightings.removeWhere((s) => now.difference(s.at) > const Duration(hours: 2));
    }
    _tracks.removeWhere((_, t) => t.sightings.isEmpty);
  }

  void _evaluate() {
    final now = DateTime.now();
    var changed = false;
    _tracks.forEach((id, track) {
      final window = track.sightings
          .where((s) => now.difference(s.at) <= const Duration(minutes: 90))
          .where((s) => track.tracker || !s.fast)
          .toList();
      if (window.length < 4) return;
      final minutes = window.last.at.difference(window.first.at).inMinutes;
      final needed = track.tracker ? 15 : 30;
      if (minutes < needed) return;

      final places = <_Sighting>[];
      for (final s in window) {
        final isNew = places.every((p) => Geolocator.distanceBetween(p.lat, p.lng, s.lat, s.lng) >= 400);
        if (isNew) places.add(s);
      }
      if (places.length < 3) return;

      final last = _alertedAt[id];
      if (last != null && now.difference(last) < const Duration(hours: 6)) return;
      _alertedAt[id] = now;
      alerts.removeWhere((a) => a.id == id);
      alerts.add(SuspiciousDevice(id: id, tracker: track.tracker, places: places.length, minutes: minutes));
      changed = true;
    });
    if (changed) {
      notifyListeners();
      Notifier.show(Notifier.attentionId, "Something may need your attention. Open Mool when it's safe.");
    }
  }
}
