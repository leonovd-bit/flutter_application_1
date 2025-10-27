import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class DataClearService {
  /// Clear all local data from SharedPreferences
  static Future<void> clearAllLocalData() async {
    debugPrint('[DataClear] Clearing all local data...');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get all keys
      final allKeys = prefs.getKeys();
      
      // Remove all keys
      for (final key in allKeys) {
        await prefs.remove(key);
      }
      
      debugPrint('[DataClear] All local data cleared successfully');
      
    } catch (e) {
      debugPrint('[DataClear] Error clearing local data: $e');
      rethrow;
    }
  }

  /// Clear only user-specific data (keeps app settings)
  static Future<void> clearUserData() async {
    debugPrint('[DataClear] Clearing user-specific data...');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      // Remove user-specific keys
      final userKeys = allKeys.where((key) => 
        key.contains('_') && // Contains user ID separator
        (key.startsWith('selected_meal_plan_id_') ||
         key.startsWith('selected_meal_plan_display_name_') ||
         key.startsWith('saved_schedules_') ||
         key.startsWith('delivery_schedule_') ||
         key.startsWith('meal_schedule_') ||
         key.startsWith('user_preferences_') ||
         key.startsWith('cached_addresses_') ||
         key.startsWith('health_data_') ||
         key.startsWith('meal_selections_') ||
         key.contains('_signup_') ||
         key.contains('_schedule_') ||
         key.contains('_payment_'))
      ).toList();
      
      for (final key in userKeys) {
        await prefs.remove(key);
      }
      
      debugPrint('[DataClear] User-specific data cleared successfully');
      
    } catch (e) {
      debugPrint('[DataClear] Error clearing user data: $e');
      rethrow;
    }
  }

  /// Clear only app settings (keeps user data)
  static Future<void> clearAppSettings() async {
    debugPrint('[DataClear] Clearing app settings...');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // List of app setting keys to remove
      final settingKeys = [
        'has_seen_welcome',
        'biometric_enabled',
        'push_notifications',
        'email_notifications',
        'order_updates',
        'promotional_emails',
        'setup_completed',
        'current_step',
        'step_timestamp',
      ];
      
      for (final key in settingKeys) {
        await prefs.remove(key);
      }
      
      debugPrint('[DataClear] App settings cleared successfully');
      
    } catch (e) {
      debugPrint('[DataClear] Error clearing app settings: $e');
      rethrow;
    }
  }
}
