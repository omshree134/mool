import 'package:cloud_functions/cloud_functions.dart';

/// Links the person to their counsellor with a one-time code made on the
/// counsellor website.
///
/// Abhaya accepted any QR that started with "abhaya://guardian-pair" and
/// trusted the watch ID inside it, so anyone could make a QR that paired a
/// phone to them. Here the code is checked on the server: it must exist, be
/// unused and unexpired, and it can only be used once.
class LinkService {
  static String normalize(String raw) => raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  /// Pulls the code out of a QR such as "mool://link?code=ABCD1234".
  static String? codeFromQr(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != 'mool' || uri.host != 'link') return null;
    final code = uri.queryParameters['code'];
    return code == null ? null : normalize(code);
  }

  /// Returns the counsellor's display name. Throws [LinkException] with a
  /// message that can be shown as-is.
  static Future<String> redeem(String rawCode) async {
    final code = normalize(rawCode);
    if (code.length != 8) throw const LinkException('Codes have 8 letters and numbers. Check and try again.');
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('redeemPairingCode');
      final result = await callable.call({'code': code});
      final data = result.data;
      if (data is Map && data['counsellorName'] is String) return data['counsellorName'] as String;
      return 'your counsellor';
    } on FirebaseFunctionsException catch (e) {
      throw LinkException(switch (e.code) {
        'not-found' => "That code wasn't found. Check it with your counsellor.",
        'failed-precondition' => 'That code has expired or was already used. Ask your counsellor for a new one.',
        'unauthenticated' => 'Sign in again, then try the code.',
        'unavailable' || 'deadline-exceeded' => 'No internet connection. Try again when you are online.',
        _ => 'The code could not be checked. Try again in a moment.',
      });
    }
  }
}

class LinkException implements Exception {
  const LinkException(this.message);
  final String message;
  @override
  String toString() => message;
}
