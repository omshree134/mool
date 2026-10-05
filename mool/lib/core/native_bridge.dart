import 'package:flutter/services.dart';

/// Talks to MainActivity.kt for things Flutter plugins can't do reliably.
class NativeBridge {
  static const _channel = MethodChannel('app.mool/native');

  /// Returns true when Android accepted the message for sending.
  /// Throws [PlatformException] with a reason when it can't.
  static Future<bool> sendSms(String phone, String message) async {
    final ok = await _channel.invokeMethod<bool>('sendSms', {'phone': phone, 'message': message});
    return ok == true;
  }

  /// Starts a call directly if CALL_PHONE is granted, otherwise opens the
  /// dialer with the number filled in. Returns true for a direct call.
  static Future<bool> placeCall(String number) async {
    final direct = await _channel.invokeMethod<bool>('placeCall', {'number': number});
    return direct == true;
  }
}
