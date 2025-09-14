import 'dart:io' show Platform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'order_functions_service.dart';

class NotificationsServiceV1 {
  NotificationsServiceV1._();
  static final instance = NotificationsServiceV1._();

  Future<void> initAndRegisterToken() async {
    // Web notifications use a different flow (service worker); skip here for now.
    if (kIsWeb) return;

    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) return;

    // Request permission (Android 13+, iOS)
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    final token = await messaging.getToken();
    if (token == null || token.isEmpty) return;

    final platform = Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'other';
    try {
      await OrderFunctionsService.instance
          .registerFcmToken(token: token, platform: platform);
    } catch (_) {
      // Best-effort; ignore failures
    }

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        await OrderFunctionsService.instance
            .registerFcmToken(token: newToken, platform: platform);
      } catch (_) {}
    });
  }
}
