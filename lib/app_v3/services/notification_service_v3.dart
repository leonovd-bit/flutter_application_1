import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationServiceV3 {
  NotificationServiceV3._();
  static final NotificationServiceV3 instance = NotificationServiceV3._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Timezone init
    try {
      tz.initializeTimeZones();
      final String timeZoneName = tz.local.name; // tz resolves local
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      // best-effort; continue
    }

    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> scheduleOneHourBefore({
    required int id,
    required DateTime deliveryTime,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();

    final dt = deliveryTime.toLocal();
    final scheduleAt = dt.subtract(const Duration(hours: 1));
    if (scheduleAt.isBefore(DateTime.now())) {
      // Don't schedule past notifications
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'orders_channel',
      'Orders',
      channelDescription: 'Order reminders and updates',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduleAt, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
