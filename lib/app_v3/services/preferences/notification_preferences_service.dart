import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class NotificationPreferencesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Keys for local storage
  static const String _pushNotificationsKey = 'pref_push_notifications';
  static const String _emailNotificationsKey = 'pref_email_notifications';
  static const String _orderUpdatesKey = 'pref_order_updates';

  /// Load notification preferences from Firestore and cache locally
  static Future<Map<String, bool>> loadPreferences() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return _getDefaultPreferences();
      }

      // Try to load from Firestore
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final prefs = data?['notificationPreferences'] as Map<String, dynamic>?;
        
        if (prefs != null) {
          final result = {
            'pushNotifications': prefs['pushNotifications'] as bool? ?? true,
            'emailNotifications': prefs['emailNotifications'] as bool? ?? true,
            'orderUpdates': prefs['orderUpdates'] as bool? ?? true,
          };
          
          // Cache locally
          await _cachePreferences(result);
          return result;
        }
      }

      // If not in Firestore, try local cache
      final localPrefs = await _loadFromCache();
      if (localPrefs != null) {
        return localPrefs;
      }

      // Return defaults
      return _getDefaultPreferences();
    } catch (e) {
      debugPrint('[NotificationPrefs] Error loading preferences: $e');
      // Try to return cached values
      final cached = await _loadFromCache();
      return cached ?? _getDefaultPreferences();
    }
  }

  /// Save notification preference
  static Future<bool> savePreference(String key, bool value) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('[NotificationPrefs] No user logged in');
        return false;
      }

      // Update Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({
        'notificationPreferences': {
          key: value,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update local cache
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _getCacheKey(key);
      await prefs.setBool(cacheKey, value);

      debugPrint('[NotificationPrefs] Saved $key = $value');
      return true;
    } catch (e) {
      debugPrint('[NotificationPrefs] Error saving preference: $e');
      return false;
    }
  }

  /// Save push notifications preference
  static Future<bool> setPushNotifications(bool enabled) async {
    return await savePreference('pushNotifications', enabled);
  }

  /// Save email notifications preference
  static Future<bool> setEmailNotifications(bool enabled) async {
    return await savePreference('emailNotifications', enabled);
  }

  /// Save order updates preference
  static Future<bool> setOrderUpdates(bool enabled) async {
    return await savePreference('orderUpdates', enabled);
  }

  /// Get specific preference value
  static Future<bool> getPushNotifications() async {
    final prefs = await loadPreferences();
    return prefs['pushNotifications'] ?? true;
  }

  static Future<bool> getEmailNotifications() async {
    final prefs = await loadPreferences();
    return prefs['emailNotifications'] ?? true;
  }

  static Future<bool> getOrderUpdates() async {
    final prefs = await loadPreferences();
    return prefs['orderUpdates'] ?? true;
  }

  // Private helper methods

  static Map<String, bool> _getDefaultPreferences() {
    return {
      'pushNotifications': true,
      'emailNotifications': true,
      'orderUpdates': true,
    };
  }

  static String _getCacheKey(String key) {
    switch (key) {
      case 'pushNotifications':
        return _pushNotificationsKey;
      case 'emailNotifications':
        return _emailNotificationsKey;
      case 'orderUpdates':
        return _orderUpdatesKey;
      default:
        return 'pref_$key';
    }
  }

  static Future<void> _cachePreferences(Map<String, bool> prefs) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool(_pushNotificationsKey, prefs['pushNotifications'] ?? true);
      await sp.setBool(_emailNotificationsKey, prefs['emailNotifications'] ?? true);
      await sp.setBool(_orderUpdatesKey, prefs['orderUpdates'] ?? true);
    } catch (e) {
      debugPrint('[NotificationPrefs] Error caching preferences: $e');
    }
  }

  static Future<Map<String, bool>?> _loadFromCache() async {
    try {
      final sp = await SharedPreferences.getInstance();
      
      // Check if we have any cached values
      if (!sp.containsKey(_pushNotificationsKey) &&
          !sp.containsKey(_emailNotificationsKey) &&
          !sp.containsKey(_orderUpdatesKey)) {
        return null;
      }

      return {
        'pushNotifications': sp.getBool(_pushNotificationsKey) ?? true,
        'emailNotifications': sp.getBool(_emailNotificationsKey) ?? true,
        'orderUpdates': sp.getBool(_orderUpdatesKey) ?? true,
      };
    } catch (e) {
      debugPrint('[NotificationPrefs] Error loading from cache: $e');
      return null;
    }
  }
}
