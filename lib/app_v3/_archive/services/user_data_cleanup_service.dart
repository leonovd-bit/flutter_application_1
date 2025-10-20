import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to clean up user data and prevent cross-account contamination
class UserDataCleanupService {
  
  /// Clear all cached data that isn't user-specific to prevent mixing between accounts
  static Future<void> clearCachedAddressData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear address-related cached data
      await prefs.remove('user_addresses');
      await prefs.remove('cached_addresses');
      
      if (kDebugMode) {
        print('[UserDataCleanup] Cleared cached address data');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[UserDataCleanup] Error clearing cached address data: $e');
      }
    }
  }
  
  /// Comprehensive cleanup for switching between accounts
  static Future<void> clearAllNonUserSpecificData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Keys that should be cleared when switching users to prevent contamination
      final globalKeysToRemove = [
        // Address data
        'user_addresses',
        'cached_addresses',
        
        // Meal plan data (global keys, not user-scoped)
        'selected_meal_plan_id',
        'selected_meal_plan_name', 
        'selected_meal_plan_display_name',
        
        // Delivery schedules (global)
        'saved_schedules',
        
        // Onboarding state
        'setup_completed',
        'onboarding_plan_selected',
        'has_seen_welcome',
        
        // AI preferences (global)
        'ai_user_preferences',
        'ai_meal_history',
        
        // Reorder history (global)
        'reorder_history',
        'favorite_reorders',
        
        // Order lifecycle data
        'completed_orders',
      ];
      
      // Remove all global keys
      for (final key in globalKeysToRemove) {
        await prefs.remove(key);
      }
      
      // Also remove any delivery schedule keys that aren't user-scoped
      final allKeys = prefs.getKeys();
      final scheduleKeysToRemove = allKeys.where((key) => 
        key.startsWith('delivery_schedule_') && !key.contains('_uid') ||
        key.startsWith('meal_schedule_') && !key.contains('_uid')
      ).toList();
      
      for (final key in scheduleKeysToRemove) {
        await prefs.remove(key);
      }
      
      if (kDebugMode) {
        print('[UserDataCleanup] Cleared ${globalKeysToRemove.length + scheduleKeysToRemove.length} global data keys');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[UserDataCleanup] Error clearing global data: $e');
      }
    }
  }
  
  /// Clear data for a specific user (for account deletion or switching)
  static Future<void> clearUserSpecificData(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get all keys and find user-specific ones
      final allKeys = prefs.getKeys();
      final userKeysToRemove = allKeys.where((key) => 
        key.contains(userId) ||
        key.endsWith('_$userId')
      ).toList();
      
      // Remove all user-specific keys
      for (final key in userKeysToRemove) {
        await prefs.remove(key);
      }
      
      if (kDebugMode) {
        print('[UserDataCleanup] Cleared ${userKeysToRemove.length} user-specific keys for $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[UserDataCleanup] Error clearing user-specific data: $e');
      }
    }
  }
  
  /// Full cleanup when signing out to prevent data leakage
  static Future<void> performFullLogoutCleanup() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      // Clear global data that could contaminate next user
      await clearAllNonUserSpecificData();
      
      // Clear current user's specific data if we have a user
      if (user != null) {
        await clearUserSpecificData(user.uid);
      }
      
      if (kDebugMode) {
        print('[UserDataCleanup] Performed full logout cleanup');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[UserDataCleanup] Error in full logout cleanup: $e');
      }
    }
  }
  
  /// Debug function to list all SharedPreferences keys
  static Future<void> debugListAllKeys() async {
    if (kDebugMode) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final keys = prefs.getKeys().toList()..sort();
        
        print('[UserDataCleanup] All SharedPreferences keys:');
        for (final key in keys) {
          final value = prefs.get(key);
          final valueStr = value.toString();
          final truncated = valueStr.length > 100 
              ? '${valueStr.substring(0, 100)}...' 
              : valueStr;
          print('  $key: $truncated');
        }
        print('[UserDataCleanup] Total keys: ${keys.length}');
      } catch (e) {
        print('[UserDataCleanup] Error listing keys: $e');
      }
    }
  }
}