import 'package:permission_handler/permission_handler.dart';

/// Permissions are asked for at the moment a feature is switched on, with a
/// reason shown first. Abhaya asked for camera and microphone in the middle of
/// an SOS, which put a system dialog in front of someone in danger.
class Perms {
  static Future<bool> requestAll(List<Permission> list) async {
    if (list.isEmpty) return true;
    final results = await list.request();
    return results.values.every((s) => s.isGranted || s.isLimited);
  }

  static Future<bool> allGranted(List<Permission> list) async {
    for (final p in list) {
      if (!(await p.isGranted)) return false;
    }
    return true;
  }

  static const passiveSensing = [
    Permission.activityRecognition,
    Permission.locationWhenInUse,
    Permission.notification,
  ];

  static const followWatch = [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.locationWhenInUse,
    Permission.notification,
  ];

  static const emergency = [Permission.sms, Permission.phone];

  static const audio = [Permission.microphone];
}
