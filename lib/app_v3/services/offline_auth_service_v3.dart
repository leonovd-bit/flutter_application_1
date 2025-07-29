import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineAuthServiceV3 {
  static const String _isLoggedInKey = 'offline_logged_in';
  static const String _userEmailKey = 'offline_user_email';

  // Store demo accounts locally for offline testing
  static const Map<String, String> _demoAccounts = {
    'demo@freshpunk.com': 'demo123456',
    'test@freshpunk.com': 'test123456',
    'offline@freshpunk.com': 'offline123',
  };

  static Future<bool> signInOffline(String email, String password) async {
    try {
      // Check if credentials match any demo account
      if (_demoAccounts.containsKey(email) && _demoAccounts[email] == password) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_isLoggedInKey, true);
        await prefs.setString(_userEmailKey, email);
        
        if (kDebugMode) {
          print('Offline sign in successful for: $email');
        }
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Offline sign in error: $e');
      }
      return false;
    }
  }

  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isLoggedInKey) ?? false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking offline login status: $e');
      }
      return false;
    }
  }

  static Future<String?> getCurrentUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userEmailKey);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting current user email: $e');
      }
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_userEmailKey);
      
      if (kDebugMode) {
        print('Offline sign out successful');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error signing out offline: $e');
      }
    }
  }

  static String getOfflineAccountsInfo() {
    return '''
Available Demo Accounts (offline mode):

• demo@freshpunk.com / demo123456
• test@freshpunk.com / test123456  
• offline@freshpunk.com / offline123

These accounts work without internet connection and are perfect for testing the app's functionality when you have connectivity issues.
    ''';
  }

  static bool isDemoAccount(String email) {
    return _demoAccounts.containsKey(email);
  }
}
