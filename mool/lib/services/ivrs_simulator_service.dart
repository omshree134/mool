import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Models representing the IVRS call state and prompt
class IvrsPrompt {
  const IvrsPrompt({
    required this.step,
    required this.textHi,
    required this.textEn,
    required this.requiresDtmf,
    required this.requiresRecording,
    this.validDigits,
  });

  final String step;
  final String textHi;
  final String textEn;
  final bool requiresDtmf;
  final bool requiresRecording;
  final List<String>? validDigits;

  factory IvrsPrompt.fromJson(Map<String, dynamic> json) {
    return IvrsPrompt(
      step: json['step'] as String? ?? 'sleep',
      textHi: json['textHi'] as String? ?? '',
      textEn: json['textEn'] as String? ?? '',
      requiresDtmf: json['requiresDtmf'] as bool? ?? false,
      requiresRecording: json['requiresRecording'] as bool? ?? false,
      validDigits: (json['validDigits'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }
}

class IvrsCallSession {
  const IvrsCallSession({
    required this.callId,
    required this.state,
    required this.prompt,
    this.intimidationTriggered = false,
    this.callCompleted = false,
  });

  final String callId;
  final Map<String, dynamic> state;
  final IvrsPrompt prompt;
  final bool intimidationTriggered;
  final bool callCompleted;

  factory IvrsCallSession.fromJson(Map<String, dynamic> json) {
    return IvrsCallSession(
      callId: json['callId'] as String? ?? '',
      state: (json['state'] as Map<String, dynamic>?) ?? {},
      prompt: IvrsPrompt.fromJson((json['prompt'] as Map<String, dynamic>?) ?? {}),
      intimidationTriggered: json['intimidationTriggered'] as bool? ?? false,
      callCompleted: json['callCompleted'] as bool? ?? false,
    );
  }
}

/// Service that interacts directly with the Cloudflare Edge Worker's
/// provider-neutral IVRS simulator adapter.
class IvrsSimulatorService {
  IvrsSimulatorService._();
  static final IvrsSimulatorService instance = IvrsSimulatorService._();

  static const _workerUrl = String.fromEnvironment(
    'MOOL_API_URL',
    defaultValue: 'https://mool-worker.omshreechoudhary7.workers.dev',
  );

  /// Starts a new simulated IVRS check-in session.
  Future<IvrsCallSession> startCall({
    String beneficiaryId = 'BEN-LKO-001',
    String lang = 'hi',
  }) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_workerUrl/ivrs/simulator/start?bid=$beneficiaryId&lang=$lang');
      final req = await client.postUrl(uri);
      req.headers.set('Content-Type', 'application/json');
      final res = await req.close().timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final map = jsonDecode(body) as Map<String, dynamic>;
        return IvrsCallSession.fromJson(map);
      } else {
        throw HttpException('Worker returned HTTP status ${res.statusCode}');
      }
    } finally {
      client.close();
    }
  }

  /// Sends DTMF keypad digit or voice recording URL to the simulator adapter.
  Future<IvrsCallSession> sendInput({
    required Map<String, dynamic> state,
    String? dtmf,
    String? recordingUrl,
  }) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$_workerUrl/ivrs/simulator/input');
      final req = await client.postUrl(uri);
      req.headers.set('Content-Type', 'application/json');
      req.add(utf8.encode(jsonEncode({
        'state': state,
        if (dtmf != null) 'dtmf': dtmf,
        if (recordingUrl != null) 'recordingUrl': recordingUrl,
      })));
      final res = await req.close().timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final map = jsonDecode(body) as Map<String, dynamic>;
        return IvrsCallSession.fromJson(map);
      } else {
        throw HttpException('Worker returned HTTP status ${res.statusCode}');
      }
    } finally {
      client.close();
    }
  }
}
