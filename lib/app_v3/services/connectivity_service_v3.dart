import 'dart:io';
import 'package:flutter/foundation.dart';

class ConnectivityServiceV3 {
  static Future<bool> hasInternetConnection() async {
    try {
  // On web, skip dart:io checks and allow Firebase SDK to surface errors
  if (kIsWeb) return true;
      // Try to resolve a DNS lookup to check connectivity
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Connectivity check error: $e');
      }
      return false;
    }
  }

  static Future<bool> canReachFirebase() async {
    try {
  if (kIsWeb) return true;
      // Try to reach Firebase services
      final result = await InternetAddress.lookup('firebase.google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Firebase connectivity check error: $e');
      }
      return false;
    }
  }

  static String getNetworkErrorMessage() {
    return '''
It looks like you're having trouble connecting to our servers. Here are some things you can try:

• Check your internet connection
• Try switching between WiFi and mobile data
• Restart your app
• Make sure you're not using a VPN that might block connections

If the problem persists, please try again in a few minutes.
    ''';
  }
}
