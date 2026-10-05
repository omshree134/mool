import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/permissions.dart';
import '../services/daily_pipeline.dart';
import '../services/member_profile.dart';
import '../services/repository.dart';
import '../services/safety/evidence_service.dart';
import 'widgets/common.dart';

/// Threats, pressure to withdraw a complaint, being followed. Reports reach
/// the counsellor (and the district officer if not acknowledged) and feed the
/// engine's context signal: intimidation is a known driver of distress.
class ReportPage extends StatefulWidget {
  const ReportPage({super.key, this.prefill});
  final String? prefill;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  late final _what = TextEditingController(text: widget.prefill ?? '');
  final _who = TextEditingController();
  final String _id = Repo.instance.newId();
  String _when = 'Just now';
  bool _includeLocation = false;
  bool _recording = false;
  String? _evidenceId;
  Timer? _clock;
  int _seconds = 0;
  bool _saving = false;

  static const _whenOptions = ['Just now', 'Earlier today', 'Yesterday', 'In the last week', 'Longer ago'];

  @override
  void dispose() {
    _clock?.cancel();
    if (_recording) unawaited(EvidenceService.instance.stopAudio());
    _what.dispose();
    _who.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      _clock?.cancel();
      final id = await EvidenceService.instance.stopAudio();
      setState(() {
        _recording = false;
        _evidenceId = id ?? _evidenceId;
      });
      return;
    }
    if (EvidenceService.instance.recording) {
      showQuietSnack(context, 'Another recording is already running.');
      return;
    }
    if (!await Perms.requestAll(Perms.audio)) {
      if (mounted) showQuietSnack(context, 'Allow the microphone for Mool to record.');
      return;
    }
    try {
      await EvidenceService.instance.startAudio(linkedTo: 'reports/$_id', kind: 'report');
      _seconds = 0;
      _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
      setState(() => _recording = true);
    } catch (_) {
      if (mounted) showQuietSnack(context, 'Recording could not start.');
    }
  }

  Future<void> _submit() async {
    if (_what.text.trim().isEmpty && _evidenceId == null && !_recording) {
      showQuietSnack(context, 'Write a few words or make a recording first.');
      return;
    }
    setState(() => _saving = true);
    if (_recording) await _toggleRecording();

    Position? pos;
    if (_includeLocation) {
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
        );
      } catch (_) {
        try {
          pos = await Geolocator.getLastKnownPosition();
        } catch (_) {
          pos = null;
        }
      }
    }

    final audioUri = EvidenceService.instance.lastAudioDataUri;
    await Repo.instance.addReport(_id, {
      'what': _what.text.trim(),
      'when': _when,
      'who': _who.text.trim().isEmpty ? null : _who.text.trim(),
      'evidenceIds': [if (_evidenceId != null) _evidenceId],
      if (_evidenceId != null) 'audioEvidenceId': _evidenceId,
      if (audioUri != null) 'audioUrl': audioUri,
      'hasAudio': _evidenceId != null,
      'deviceTime': DateTime.now().toIso8601String(),
      if (pos != null) 'location': {'lat': pos.latitude, 'lng': pos.longitude, 'accuracyM': pos.accuracy},
    });
    unawaited(DailyPipeline.instance.run());
    if (!mounted) return;
    final linked = MemberProfile.instance.linked;
    showQuietSnack(
      context,
      linked
          ? 'Your report is saved and your support team has been told.'
          : 'Your report is saved. Connect with your counsellor so they can see it.',
    );
    Navigator.of(context).pop();
  }

  String get _elapsed => '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Report something')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Threats, pressure to change your statement, being followed or watched. '
            'Write as much or as little as you want.',
            style: t.bodyLarge,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _what,
            minLines: 4,
            maxLines: 10,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'What happened'),
          ),
          const SizedBox(height: 20),
          Text('When', style: t.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final w in _whenOptions)
                ChoiceChip(label: Text(w), selected: _when == w, onSelected: (_) => setState(() => _when = w)),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _who,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Who was involved (optional)'),
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: Icon(_recording ? Icons.stop_circle_outlined : Icons.mic_none,
                  color: _recording ? scheme.error : scheme.primary),
              title: Text(_recording
                  ? 'Recording $_elapsed. Tap to stop'
                  : _evidenceId != null
                      ? 'Recording saved and sealed'
                      : 'Record audio (optional)'),
              subtitle: Text(
                'Recordings are fingerprinted so they can be shown to be unaltered.',
                style: t.bodySmall,
              ),
              onTap: _saving ? null : _toggleRecording,
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Add where I am now'),
            subtitle: Text('Only if it happened here.', style: t.bodySmall),
            value: _includeLocation,
            onChanged: (v) async {
              if (v && !await Perms.requestAll(const [Permission.locationWhenInUse])) {
                if (mounted) showQuietSnack(this.context, 'Allow location for Mool to add where you are.');
                return;
              }
              setState(() => _includeLocation = v);
            },
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _submit, child: Text(_saving ? 'Saving…' : 'Save report')),
        ],
      ),
    );
  }
}
