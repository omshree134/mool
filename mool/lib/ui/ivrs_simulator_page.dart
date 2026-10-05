import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../app/theme.dart';
import '../core/settings.dart';
import '../services/ivrs_simulator_service.dart';

class IvrsSimulatorPage extends StatefulWidget {
  const IvrsSimulatorPage({super.key});

  @override
  State<IvrsSimulatorPage> createState() => _IvrsSimulatorPageState();
}

class _IvrsSimulatorPageState extends State<IvrsSimulatorPage> {
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _callActive = false;
  int _callDuration = 0;
  Timer? _callTimer;

  String _language = 'hi';
  String _beneficiaryId = 'BEN-LKO-001';

  IvrsCallSession? _session;
  bool _loading = false;
  bool _threatTriggered = false;

  // Audio Recording State
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  String? _recordedAudioPath;

  // Real-time Telemetry & Event Audit Log
  final List<({String time, String text, String type})> _eventLogs = [];

  @override
  void initState() {
    super.initState();
    final name = Settings.instance.displayName.trim();
    if (name.isNotEmpty) {
      _beneficiaryId = 'BEN-${name.replaceAll(' ', '-').toUpperCase()}';
    }
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _recordingTimer?.cancel();
    if (_isRecording) {
      _audioRecorder.stop();
    }
    _audioRecorder.dispose();
    super.dispose();
  }

  void _addLog(String text, {String type = 'info'}) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() {
      _eventLogs.insert(0, (time: timeStr, text: text, type: type));
    });
  }

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startCall() async {
    setState(() {
      _loading = true;
      _threatTriggered = false;
    });
    _addLog('Dialing Mool Automated Helpline (1800-MOOL-CARE)...', type: 'info');

    try {
      final session = await IvrsSimulatorService.instance.startCall(
        beneficiaryId: _beneficiaryId,
        lang: _language,
      );

      setState(() {
        _session = session;
        _callActive = true;
        _callDuration = 0;
        _loading = false;
      });

      _callTimer?.cancel();
      _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _callDuration++);
      });

      final promptText = _language == 'hi' ? session.prompt.textHi : session.prompt.textEn;
      _addLog('Connected. Prompt: "${promptText.substring(0, promptText.length > 40 ? 40 : promptText.length)}..."',
          type: 'info');
    } catch (e) {
      setState(() => _loading = false);
      _addLog('Call failed to connect: $e', type: 'alert');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initiate call: $e')),
        );
      }
    }
  }

  Future<void> _endCall() async {
    if (_isRecording) {
      await _stopRecording(sendToWorker: false);
    }
    _callTimer?.cancel();
    setState(() {
      _callActive = false;
      _session = null;
      _isRecording = false;
    });
    _addLog('Call disconnected by caller.', type: 'info');
  }

  Future<void> _onKeyPress(String digit) async {
    HapticFeedback.lightImpact();
    if (!_callActive || _session == null || _loading) return;

    _addLog('DTMF Keypad Pressed: [ $digit ]', type: 'info');

    // If recording was active, user pressed digit to complete recording
    String? audioDataUri;
    if (_isRecording) {
      audioDataUri = await _stopRecording(sendToWorker: false);
    }

    setState(() => _loading = true);

    try {
      final updatedSession = await IvrsSimulatorService.instance.sendInput(
        state: _session!.state,
        dtmf: digit,
        recordingUrl: audioDataUri,
      );

      setState(() {
        _session = updatedSession;
        _loading = false;
      });

      if (updatedSession.intimidationTriggered) {
        setState(() => _threatTriggered = true);
        _addLog(
          '🚨 THREAT DETECTED: Caller pressed 1. Intimidation event created with 4h SLA deadline!',
          type: 'alert',
        );
      }

      final promptText = _language == 'hi' ? updatedSession.prompt.textHi : updatedSession.prompt.textEn;
      _addLog(
        'System responded: "${promptText.substring(0, promptText.length > 40 ? 40 : promptText.length)}..."',
        type: 'info',
      );

      // If prompt requires voice recording, trigger microphone
      if (updatedSession.prompt.requiresRecording) {
        await _startRecording();
      }

      if (updatedSession.callCompleted) {
        _addLog('✅ Call completed successfully. Check-in observation recorded in database.', type: 'success');
      }
    } catch (e) {
      setState(() => _loading = false);
      _addLog('Error processing DTMF input: $e', type: 'alert');
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) {
        _addLog('Microphone permission not granted; using simulated voice token.', type: 'info');
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/ivrs_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 22050),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
        _recordedAudioPath = path;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordingDuration++);
      });

      _addLog('Microphone listening... Speak reflection now (press any digit to complete).', type: 'info');
    } catch (e) {
      _addLog('Microphone initialisation notice: $e', type: 'info');
    }
  }

  Future<String?> _stopRecording({bool sendToWorker = true}) async {
    _recordingTimer?.cancel();
    if (!_isRecording) return null;

    String? path;
    try {
      path = await _audioRecorder.stop() ?? _recordedAudioPath;
    } catch (_) {
      path = _recordedAudioPath;
    }

    setState(() => _isRecording = false);

    String? dataUri;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        dataUri = 'data:audio/mp4;base64,${base64Encode(bytes)}';
        _addLog('Voice reflection captured (${bytes.length} bytes). Dispatched to Render ML pipeline!',
            type: 'success');
      }
    }

    if (sendToWorker && _session != null) {
      _onKeyPress('#');
    }

    return dataUri;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('IVRS Phone Simulator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'View Telephony Log',
            onPressed: () => _showAuditLogSheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Adapter Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? MoolPalette.duskDark : const Color(0xFFEFF3F7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3E433C) : const Color(0xFFCDC6B8),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MoolPalette.moss.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.cell_tower_rounded, color: MoolPalette.moss, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'TELEPHONY CHANNEL ADAPTER',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: MoolPalette.moss,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: MoolPalette.moss,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Zero Cost',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Simulates toll-free IVRS check-in, threat detection, and audio features with zero telephony cost.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: isDark ? const Color(0xFFA5ABA3) : MoolPalette.slate,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Threat Alert Notification Banner (if triggered)
              if (_threatTriggered)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MoolPalette.signal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MoolPalette.signal, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: MoolPalette.signal, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Section 15A Witness Intimidation Alert triggered! Escalation dispatched with 4h SLA.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: MoolPalette.signal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Language and Beneficiary Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Language Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? MoolPalette.nightSurface : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _langButton('hi', 'हिन्दी'),
                        _langButton('en', 'English'),
                      ],
                    ),
                  ),

                  // Beneficiary Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? MoolPalette.nightSurface : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: MoolPalette.moss),
                        const SizedBox(width: 6),
                        Text(
                          _beneficiaryId,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // THE PHONE DEVICE BODY
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 360),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161816) : Colors.black,
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFF333833), width: 3),
                ),
                child: Column(
                  children: [
                    // Speaker notch
                    Container(
                      width: 60,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Phone screen header
                    Text(
                      'MOOL AUTOMATED HEALTHLINE',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: MoolPalette.sandrose,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '1800-MOOL-CARE',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Call status indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _callActive ? Colors.greenAccent : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _callActive
                              ? 'Connected • ${_formatTimer(_callDuration)}'
                              : 'Ready to Call',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _callActive ? Colors.greenAccent : Colors.white60,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Dynamic Prompt Speaker Display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E221E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2E342E)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.volume_up_rounded,
                                size: 14,
                                color: _callActive ? MoolPalette.mossLight : Colors.white38,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Audio Prompt:',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white54,
                                ),
                              ),
                              const Spacer(),
                              if (_loading)
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _session != null
                                ? (_language == 'hi' ? _session!.prompt.textHi : _session!.prompt.textEn)
                                : 'Tap the green Call button below to dial into the Mool trauma check-in line.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white,
                              height: 1.45,
                            ),
                          ),
                          if (_isRecording) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: MoolPalette.signal.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: MoolPalette.signal),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.mic, color: MoolPalette.signal, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Listening... ${_formatTimer(_recordingDuration)} (tap any digit to end)',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tactile 12-key Keypad
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.35,
                      children: [
                        _keypadButton('1', subtitle: 'GOOD / YES'),
                        _keypadButton('2', subtitle: 'FAIR / NO'),
                        _keypadButton('3', subtitle: 'POOR / RESTLESS'),
                        _keypadButton('4', subtitle: 'GHI'),
                        _keypadButton('5', subtitle: 'JKL'),
                        _keypadButton('6', subtitle: 'MNO'),
                        _keypadButton('7', subtitle: 'PQRS'),
                        _keypadButton('8', subtitle: 'TUV'),
                        _keypadButton('9', subtitle: 'WXYZ'),
                        _keypadButton('*', subtitle: ''),
                        _keypadButton('0', subtitle: '+'),
                        _keypadButton('#', subtitle: 'DONE'),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Call & Hangup Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!_callActive)
                          GestureDetector(
                            onTap: _loading ? null : _startCall,
                            child: Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF2E7D32),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2E7D32).withValues(alpha: 0.5),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.call, color: Colors.white, size: 28),
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: _endCall,
                            child: Container(
                              width: 62,
                              height: 62,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFC62828),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFC62828).withValues(alpha: 0.5),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.call_end, color: Colors.white, size: 28),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Live Telemetry Mini-Preview
              GestureDetector(
                onTap: () => _showAuditLogSheet(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? MoolPalette.nightSurface : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.terminal_rounded, size: 18, color: MoolPalette.moss),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _eventLogs.isNotEmpty
                              ? '[${_eventLogs.first.time}] ${_eventLogs.first.text}'
                              : 'Tap to view live webhook stream and audit telemetry',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : MoolPalette.slate,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langButton(String code, String label) {
    final active = _language == code;
    return GestureDetector(
      onTap: () => setState(() => _language = code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? MoolPalette.moss : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _keypadButton(String digit, {required String subtitle}) {
    final enabled = _callActive && !_loading;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => _onKeyPress(digit) : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFF242A24) : const Color(0xFF1A1E1A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: enabled ? const Color(0xFF353D35) : const Color(0xFF202620),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                digit,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: enabled ? Colors.white : Colors.white24,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: enabled ? MoolPalette.sandrose : Colors.white12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAuditLogSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sync_alt, size: 20, color: MoolPalette.moss),
                    const SizedBox(width: 8),
                    Text(
                      'Live Telephony Webhooks & Audit Log',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _eventLogs.isEmpty
                      ? const Center(
                          child: Text(
                            'No telephony events recorded yet.\nDial the phone to generate logs.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _eventLogs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final log = _eventLogs[i];
                            Color bgColor = Colors.black12;
                            Color textColor = Colors.black87;
                            if (log.type == 'alert') {
                              bgColor = Colors.red.withValues(alpha: 0.15);
                              textColor = Colors.red.shade900;
                            } else if (log.type == 'success') {
                              bgColor = Colors.green.withValues(alpha: 0.15);
                              textColor = Colors.green.shade900;
                            }
                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '[${log.time}] ',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      log.text,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
