import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'order_functions_service.dart';

/// Enhanced Firebase Cloud Messaging (Push Notifications) Service
/// Handles:
/// - FCM token registration and refresh
/// - Foreground notification display
/// - Notification permissions
/// - Background message handling
class FCMServiceV3 {
  FCMServiceV3._();
  static final instance = FCMServiceV3._();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _localNotificationsInitialized = false;

  /// Initialize FCM service and register for push notifications
  Future<void> initAndRegisterToken() async {
    if (_initialized) return;

    // Web notifications use a different flow; basic support for now
    if (kIsWeb) {
      await _initWeb();
      return;
    }

    await _initMobile();
    _initialized = true;
  }

  /// Initialize for web platform
  Future<void> _initWeb() async {
    try {
      final messaging = FirebaseMessaging.instance;
      
      // Request permission
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      // Get token for web
      final token = await messaging.getToken(
        vapidKey: 'BDO-7nG8Qj9N4YX_K8RJ6vL5hF2P9M3C1K7H4X2J9S8E6F1R3V5G8N2M4Q6W8Y7U5E9R2T4', // Replace with your VAPID key
      );

      if (token != null) {
        await _registerToken(token, 'web');
      }

      // Listen for messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      _initialized = true;
    } catch (e) {
      debugPrint('[FCMServiceV3] Web init error: $e');
      _initialized = true; // Mark as initialized even on error to prevent retry loops
    }
  }

  /// Initialize for mobile platforms (Android/iOS)
  Future<void> _initMobile() async {
    try {
      final messaging = FirebaseMessaging.instance;
      
      // Initialize local notifications for foreground display
      await _initLocalNotifications();

      // Request permission
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCMServiceV3] User denied notifications');
        return;
      }

      // Get FCM token
      final token = await messaging.getToken();
      if (token != null) {
        final platform = Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'other';
        await _registerToken(token, platform);
      }

      // Handle token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final platform = Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'other';
        await _registerToken(newToken, platform);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background message clicks
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageClick);

      // Handle app launch from notification
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageClick(initialMessage);
      }

    } catch (e) {
      debugPrint('[FCMServiceV3] Mobile init error: $e');
    }
  }

  /// Initialize local notifications for displaying foreground messages
  Future<void> _initLocalNotifications() async {
    if (_localNotificationsInitialized) return;
    
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleLocalNotificationClick,
      );

      // Create notification channel for Android
      if (Platform.isAndroid) {
        const channel = AndroidNotificationChannel(
          'order_updates',
          'Order Updates',
          description: 'Notifications about your FreshPunk orders',
          importance: Importance.high,
          sound: RawResourceAndroidNotificationSound('notification'),
        );

        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.createNotificationChannel(channel);
      }
      
      _localNotificationsInitialized = true;
      debugPrint('[FCMServiceV3] Local notifications initialized successfully');
    } catch (e) {
      debugPrint('[FCMServiceV3] Local notifications init error: $e');
      rethrow;
    }
  }

  /// Register FCM token with backend
  Future<void> _registerToken(String token, String platform) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await OrderFunctionsService.instance.registerFcmToken(
        token: token,
        platform: platform,
      );
      debugPrint('[FCMServiceV3] Token registered: ${token.substring(0, 20)}...');
    } catch (e) {
      debugPrint('[FCMServiceV3] Token registration failed: $e');
    }
  }

  /// Handle foreground messages (when app is open)
  void _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCMServiceV3] Foreground message: ${message.messageId}');

    // Show local notification for foreground messages
    final notification = message.notification;
    if (notification != null && !kIsWeb) {
      await _showLocalNotification(
        title: notification.title ?? 'FreshPunk',
        body: notification.body ?? '',
        data: message.data,
      );
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'order_updates',
      'Order Updates',
      channelDescription: 'Notifications about your FreshPunk orders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: data != null ? data['orderId'] : null,
    );
  }

  /// Handle notification click (background message)
  void _handleMessageClick(RemoteMessage message) {
    debugPrint('[FCMServiceV3] Message clicked: ${message.data}');
    
    // Navigate to order details if orderId is provided
    final orderId = message.data['orderId'];
    if (orderId != null) {
      // TODO: Navigate to order details page
      debugPrint('[FCMServiceV3] Should navigate to order: $orderId');
    }
  }

  /// Handle local notification click
  void _handleLocalNotificationClick(NotificationResponse response) {
    debugPrint('[FCMServiceV3] Local notification clicked: ${response.payload}');
    
    if (response.payload != null) {
      // TODO: Navigate to order details page
      debugPrint('[FCMServiceV3] Should navigate to order: ${response.payload}');
    }
  }

  /// Test push notification functionality
  Future<void> sendTestNotification() async {
    try {
      // Ensure local notifications are initialized
      if (!_localNotificationsInitialized) {
        debugPrint('[FCMServiceV3] Initializing local notifications for test...');
        await _initLocalNotifications();
      }
      
      await _showLocalNotification(
        title: '🍽️ FreshPunk Test',
        body: 'Push notifications are working! Your orders will appear here.',
        data: {'test': 'true'},
      );
      debugPrint('[FCMServiceV3] Test notification sent successfully');
    } catch (e) {
      debugPrint('[FCMServiceV3] Test notification failed: $e');
      rethrow;
    }
  }

  /// Get current FCM token
  Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('[FCMServiceV3] Get token error: $e');
      return null;
    }
  }

  /// Check notification permissions
  Future<bool> hasPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      debugPrint('[FCMServiceV3] Permission check error: $e');
      return false;
    }
  }

  /// Request notification permissions
  Future<bool> requestPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (e) {
      debugPrint('[FCMServiceV3] Permission request error: $e');
      return false;
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCMServiceV3] Background message: ${message.messageId}');
  // Handle background message processing here
}
