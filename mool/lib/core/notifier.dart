import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Discreet notifications. The text never says what Mool is for, because the
/// phone may be shared with family or seen by others.
class Notifier {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const reminderId = 1;
  static const attentionId = 2;

  static Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  static Future<void> show(int id, String body) async {
    await init();
    if (!_ready) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mool_gentle',
        'Reminders and notices',
        channelDescription: 'Gentle reminders from Mool',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    try {
      await _plugin.show(id, 'Mool', body, details);
    } catch (e) {
      debugPrint('Could not show notification: $e');
    }
  }
}
