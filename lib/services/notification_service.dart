import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order.dart' as app_models;
import '../services/order_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  static Future<void> initialize() async {
    // Skip notification setup on web for now
    if (kIsWeb) return;
    
    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Initialize Firebase Messaging
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  }

  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    debugPrint('Handling background message: ${message.messageId}');
    // Handle background message here
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Handling foreground message: ${message.messageId}');
    
    // Show local notification for foreground messages
    if (message.notification != null) {
      _showLocalNotification(
        title: message.notification!.title ?? 'FreshPunk',
        body: message.notification!.body ?? '',
        payload: message.data['orderId'],
      );
    }
  }

  static void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle notification tap - could navigate to specific order
  }

  // Schedule 1-hour reminder notification
  static Future<void> scheduleOrderReminder(app_models.Order order) async {
    final notificationTime = order.scheduledDeliveryTime.subtract(const Duration(hours: 1));
    
    // Only schedule if the time is in the future
    if (notificationTime.isAfter(DateTime.now())) {
      // For now, we'll use a simple approach - store the reminder time and check it periodically
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('reminder_${order.id}', notificationTime.toIso8601String());
      
      // In a production app, you would use a proper scheduling mechanism
      // For demo purposes, we'll check reminders when the app is opened
    }
  }

  // Schedule auto-confirm for 15 minutes before delivery
  static Future<void> scheduleAutoConfirm(app_models.Order order) async {
    final autoConfirmTime = order.scheduledDeliveryTime.subtract(const Duration(minutes: 15));
    
    // Store the auto-confirm time in SharedPreferences for background processing
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auto_confirm_${order.id}', autoConfirmTime.toIso8601String());
  }

  // Show immediate local notification
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'general',
          'General Notifications',
          channelDescription: 'General app notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  // Send order status update notification
  static Future<void> notifyOrderStatusUpdate(app_models.Order order) async {
    String title = 'Order Update';
    String body = '';
    
    switch (order.status) {
      case app_models.OrderStatus.confirmed:
        body = 'Your ${order.mealName} order has been confirmed!';
        break;
      case app_models.OrderStatus.ready:
        body = 'Your ${order.mealName} is ready for pickup!';
        break;
      case app_models.OrderStatus.pickedUp:
        body = 'Your ${order.mealName} has been picked up and is on the way!';
        break;
      case app_models.OrderStatus.outForDelivery:
        body = 'Your ${order.mealName} is out for delivery!';
        break;
      case app_models.OrderStatus.delivered:
        body = 'Your ${order.mealName} has been delivered! Enjoy your meal!';
        break;
      default:
        return; // Don't send notification for other statuses
    }
    
    await _showLocalNotification(
      title: title,
      body: body,
      payload: order.id,
    );
  }

  // Cancel order notifications
  static Future<void> cancelOrderNotifications(String orderId) async {
    await _localNotifications.cancel(orderId.hashCode);
    await _localNotifications.cancel('${orderId}_autoconfirm'.hashCode);
    
    // Remove from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auto_confirm_$orderId');
    await prefs.remove('reminder_$orderId');
  }

  // Check and process reminders and auto-confirm orders (call this periodically)
  static Future<void> processScheduledActions() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    
    // Process reminders
    final reminderKeys = prefs.getKeys().where((key) => key.startsWith('reminder_'));
    for (final key in reminderKeys) {
      final timeString = prefs.getString(key);
      if (timeString != null) {
        final reminderTime = DateTime.parse(timeString);
        final orderId = key.replaceFirst('reminder_', '');
        
        if (now.isAfter(reminderTime)) {
          await _showLocalNotification(
            title: 'Order Reminder',
            body: 'Your meal will be delivered in 1 hour. Tap to confirm or make changes.',
            payload: orderId,
          );
          await prefs.remove(key);
        }
      }
    }
    
    // Process auto-confirmations
    final autoConfirmKeys = prefs.getKeys().where((key) => key.startsWith('auto_confirm_'));
    for (final key in autoConfirmKeys) {
      final timeString = prefs.getString(key);
      if (timeString != null) {
        final autoConfirmTime = DateTime.parse(timeString);
        final orderId = key.replaceFirst('auto_confirm_', '');
        
        if (now.isAfter(autoConfirmTime)) {
          await OrderService.autoConfirmOrder(orderId);
          await prefs.remove(key);
          
          await _showLocalNotification(
            title: 'Order Auto-Confirmed',
            body: 'Your meal order has been automatically confirmed.',
            payload: orderId,
          );
        }
      }
    }
  }

  // Get FCM token for backend integration
  static Future<String?> getFCMToken() async {
    return await _messaging.getToken();
  }
}
