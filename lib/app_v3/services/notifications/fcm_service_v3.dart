import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../environment_service.dart';
import '../orders/order_functions_service.dart';

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
      final vapidKey = EnvironmentService.fcmVapidKey;
      
      // Debug: log first/last 6 chars to verify key is present
      if (vapidKey.isNotEmpty) {
        final preview = vapidKey.length > 12 
          ? '${vapidKey.substring(0, 6)}...${vapidKey.substring(vapidKey.length - 6)}'
          : vapidKey;
        debugPrint('[FCMServiceV3] VAPID key loaded: $preview (length: ${vapidKey.length})');
      } else {
        debugPrint('[FCMServiceV3] VAPID key is empty');
      }
      
      // Request permission (ignore result; web often grants default or prompts)
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
      );

      // If missing VAPID key, surface actionable guidance
      if (vapidKey.isEmpty) {
        debugPrint('[FCMServiceV3] Web push disabled – supply --dart-define=FCM_VAPID_KEY=YOUR_PUBLIC_VAPID_KEY');
        debugPrint('[FCMServiceV3] Firebase Console > Cloud Messaging > Web Push certificates');
      }

      // Get token for web (only if we have a valid VAPID key)
      String? token;
      if (vapidKey.isNotEmpty && vapidKey.length > 50) {
        token = await messaging.getToken(
          vapidKey: vapidKey,
        );
      } else {
        debugPrint('[FCMServiceV3] Skipping web push subscription: missing/invalid VAPID key');
      }

      if (token != null) {
        await _registerToken(token, 'web');
      } else if (vapidKey.isNotEmpty) {
        debugPrint('[FCMServiceV3] Web token acquisition returned null – check service worker scope or browser permission');
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
        final platform = kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'other');
        await _registerToken(token, platform);
      }

      // Handle token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final platform = kIsWeb ? 'web' : (Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'other');
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
  /// Note: Not supported on web - only mobile platforms
  Future<void> _initLocalNotifications() async {
    if (_localNotificationsInitialized) return;
    
    // Local notifications not supported on web
    if (kIsWeb) {
      debugPrint('[FCMServiceV3] Skipping local notifications on web');
      _localNotificationsInitialized = true;
      return;
    }
    
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
      if (!kIsWeb && Platform.isAndroid) {
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

  /// Show local notification (no-op on web)
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // No-op on web
    if (kIsWeb) {
      debugPrint('[FCMServiceV3] Skipping local notification display on web');
      return;
    }
    
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
