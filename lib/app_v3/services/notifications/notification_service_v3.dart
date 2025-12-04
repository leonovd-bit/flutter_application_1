import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

// Local notification service used to remind users 1 hour before delivery.
// Note: Not supported on web - all operations are no-ops on web platform.
class NotificationServiceV3 {
  NotificationServiceV3._();
  static final NotificationServiceV3 instance = NotificationServiceV3._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    
    // Local notifications not supported on web
    if (kIsWeb) {
      debugPrint('[NotificationServiceV3] Skipping init on web (not supported)');
      _initialized = true;
      return;
    }

    // Initialize timezone database; default to local if available.
    try {
      tzdata.initializeTimeZones();
      // Best-effort: if we can't detect a proper IANA name on Windows, default to New York.
      // This app defaults to NYC in address model, so this is a reasonable fallback.
      tz.setLocalLocation(tz.getLocation('America/New_York'));
    } catch (e) {
      debugPrint('[NotificationServiceV3] TZ init failed: $e');
    }

    // Android init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // iOS/macOS init
    const darwinInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _fln.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        debugPrint('[NotificationServiceV3] tapped payload=${resp.payload}');
      },
    );

    // Android 13+ runtime permission
    try {
      await _fln
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}

    // iOS/macOS permissions
    try {
      await _fln
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
    try {
      await _fln
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}

    _initialized = true;
  }

  Future<bool> isScheduled(int id) async {
    if (!_initialized) await init();
    try {
      final pending = await _fln.pendingNotificationRequests();
      return pending.any((p) => p.id == id);
    } catch (e) {
      debugPrint('[NotificationServiceV3] isScheduled error: $e');
      return false;
    }
  }

  Future<void> scheduleIfNotExists({
    required int id,
    required DateTime deliveryTime,
    required String title,
    required String body,
    String? payload,
  }) async {
    // No-op on web
    if (kIsWeb) {
      debugPrint('[NotificationServiceV3] Skipping scheduleIfNotExists on web');
      return;
    }
    
    // Respect user preference
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('notifications_enabled') ?? true;
      if (!enabled) {
        debugPrint('[NotificationServiceV3] notifications disabled; skip id=$id');
        return;
      }
    } catch (_) {}
    if (await isScheduled(id)) {
      debugPrint('[NotificationServiceV3] already scheduled id=$id');
      return;
    }
    await scheduleOneHourBefore(
      id: id,
      deliveryTime: deliveryTime,
      title: title,
      body: body,
      payload: payload,
    );
  }

  Future<void> scheduleOneHourBefore({
    required int id,
    required DateTime deliveryTime,
    required String title,
    required String body,
    String? payload,
  }) async {
    // No-op on web
    if (kIsWeb) {
      debugPrint('[NotificationServiceV3] Skipping scheduleOneHourBefore on web');
      return;
    }
    
    try {
      if (!_initialized) await init();
      final scheduled = deliveryTime.subtract(const Duration(hours: 1));
      final now = DateTime.now();
      if (!scheduled.isAfter(now.add(const Duration(minutes: 1)))) {
        // Skip if already in the past or nearly now
        debugPrint('[NotificationServiceV3] skip scheduling id=$id (scheduled=$scheduled < now)');
        return;
      }

      final tzTime = tz.TZDateTime.from(scheduled, tz.local);

      const androidDetails = AndroidNotificationDetails(
        'delivery_reminders',
        'Delivery Reminders',
        channelDescription: 'Reminders one hour before your FreshPunk delivery',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
      );
      const darwinDetails = DarwinNotificationDetails();
      const details = NotificationDetails(android: androidDetails, iOS: darwinDetails, macOS: darwinDetails);

      await _fln.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: null,
        payload: payload,
      );
      debugPrint('[NotificationServiceV3] scheduled id=$id at $scheduled');
    } catch (e) {
      debugPrint('[NotificationServiceV3] schedule failed: $e');
    }
  }

  Future<void> cancel(int id) async {
    // No-op on web
    if (kIsWeb) {
      debugPrint('[NotificationServiceV3] Skipping cancel on web');
      return;
    }
    
    try {
      if (!_initialized) await init();
      await _fln.cancel(id);
      debugPrint('[NotificationServiceV3] cancel id=$id');
    } catch (e) {
      debugPrint('[NotificationServiceV3] cancel failed: $e');
    }
  }

  Future<void> cancelAll() async {
    // No-op on web
    if (kIsWeb) {
      debugPrint('[NotificationServiceV3] Skipping cancelAll on web');
      return;
    }
    
    try {
      if (!_initialized) await init();
      await _fln.cancelAll();
      debugPrint('[NotificationServiceV3] cancel all pending notifications');
    } catch (e) {
      debugPrint('[NotificationServiceV3] cancelAll failed: $e');
    }
  }

  Future<void> showTestNotification() async {
    // No-op on web
    if (kIsWeb) {
      debugPrint('[NotificationServiceV3] Skipping showTestNotification on web');
      return;
    }
    
    try {
      if (!_initialized) await init();
      const androidDetails = AndroidNotificationDetails(
        'delivery_reminders',
        'Delivery Reminders',
        channelDescription: 'Reminders one hour before your Victus delivery',
        importance: Importance.high,
        priority: Priority.high,
      );
      const darwinDetails = DarwinNotificationDetails();
      const details = NotificationDetails(android: androidDetails, iOS: darwinDetails, macOS: darwinDetails);
      await _fln.show(
        999999, // test id unlikely to collide
        'Victus test',
        'This is a test notification.',
        details,
      );
    } catch (e) {
      debugPrint('[NotificationServiceV3] showTestNotification failed: $e');
    }
  }
}

