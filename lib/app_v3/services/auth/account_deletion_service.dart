import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../../utils/cloud_functions_helper.dart';

class AccountDeletionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const _region = 'us-central1';
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: _region);

  static HttpsCallable _callable(String name) {
    return callableForPlatform(
      functions: _functions,
      functionName: name,
      region: _region,
    );
  }

  /// Completely deletes user account and all associated data
  static Future<void> deleteUserAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    final userId = user.uid;
    debugPrint('[AccountDeletion] Starting account deletion for user: $userId');

    try {
      // Step 1: Cancel/pause all active subscriptions
      await _cancelUserSubscriptions(userId);
      
      // Step 2: Delete all user data from Firestore
      await _deleteAllUserData(userId);
      
      // Step 3: Clear local storage
      await _clearLocalStorage(userId);
      
      // Step 4: Delete Firebase Auth user
      await user.delete();
      
      debugPrint('[AccountDeletion] Account deletion completed successfully');
    } catch (e) {
      debugPrint('[AccountDeletion] Error during account deletion: $e');
      rethrow;
    }
  }

  /// Cancel all user subscriptions via Cloud Functions
  static Future<void> _cancelUserSubscriptions(String userId) async {
    try {
      debugPrint('[AccountDeletion] Canceling subscriptions for user: $userId');
      
      // Get all active subscriptions
      final subscriptionsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .where('status', isEqualTo: 'active')
          .get();

      // Cancel each subscription via Stripe
      for (final doc in subscriptionsSnapshot.docs) {
        final data = doc.data();
        final stripeSubscriptionId = data['stripeSubscriptionId'] as String?;
        
        if (stripeSubscriptionId != null && stripeSubscriptionId != 'local') {
          try {
            // Call Cloud Function to cancel subscription
            final callable = _callable('cancelSubscription');
            await callable.call({
              'subscriptionId': stripeSubscriptionId,
            });
            debugPrint('[AccountDeletion] Canceled subscription: $stripeSubscriptionId');
          } catch (e) {
            debugPrint('[AccountDeletion] Failed to cancel subscription $stripeSubscriptionId: $e');
            // Continue with other subscriptions even if one fails
          }
        }
      }
    } catch (e) {
      debugPrint('[AccountDeletion] Error canceling subscriptions: $e');
      // Don't throw here - continue with data deletion even if subscription cancellation fails
    }
  }

  /// Delete all user data from Firestore
  static Future<void> _deleteAllUserData(String userId) async {
    debugPrint('[AccountDeletion] Deleting Firestore data for user: $userId');
    
    try {
      final batch = _firestore.batch();
      
      // List of subcollections to delete
      final subcollections = [
        'addresses',
        'meal_plans', 
        'delivery_schedules',
        'subscriptions',
        'health_data',
        'orders',
        'reviews',
        'notifications',
        'payment_methods',
      ];

      // Delete all subcollections
      for (final subcollection in subcollections) {
        final snapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection(subcollection)
            .get();
        
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        debugPrint('[AccountDeletion] Queued deletion of ${snapshot.docs.length} documents from $subcollection');
      }

      // Delete user's orders from main orders collection
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .get();
      
      for (final doc in ordersSnapshot.docs) {
        batch.delete(doc.reference);
      }
      debugPrint('[AccountDeletion] Queued deletion of ${ordersSnapshot.docs.length} orders');

      // Delete user profile document
      batch.delete(_firestore.collection('users').doc(userId));
      
      // Execute batch deletion
      await batch.commit();
      debugPrint('[AccountDeletion] Firestore data deletion completed');
      
    } catch (e) {
      debugPrint('[AccountDeletion] Error deleting Firestore data: $e');
      throw Exception('Failed to delete user data: $e');
    }
  }

  /// Clear all local storage data
  static Future<void> _clearLocalStorage(String userId) async {
    debugPrint('[AccountDeletion] Clearing local storage for user: $userId');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // List of keys to remove (both user-specific and general)
      final keysToRemove = [
        // User-specific keys
        'selected_meal_plan_id_$userId',
        'selected_meal_plan_display_name_$userId',
        'saved_schedules_$userId',
        'delivery_schedule_$userId',
        'meal_schedule_$userId',
        'user_preferences_$userId',
        'cached_addresses_$userId',
        'health_data_$userId',
        
        // General keys that might contain user data
        'selected_meal_plan_id',
        'selected_meal_plan_name', 
        'selected_meal_plan_display_name',
        'saved_schedules',
        'cached_addresses',
        'user_addresses',
        'setup_completed',
        'current_step',
        'signup_data',
        'schedule_data',
        'payment_data',
        'step_timestamp',
        'has_seen_welcome',
        'biometric_enabled',
        'push_notifications',
        'email_notifications',
        'order_updates',
        'promotional_emails',
      ];

      // Remove all keys
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      
      // Also remove any keys that start with delivery_schedule_ or meal_schedule_
      final allKeys = prefs.getKeys();
      final scheduleKeys = allKeys.where((key) => 
        key.startsWith('delivery_schedule_') || 
        key.startsWith('meal_schedule_') ||
        key.contains(userId)
      ).toList();
      
      for (final key in scheduleKeys) {
        await prefs.remove(key);
      }
      
      debugPrint('[AccountDeletion] Local storage cleared');
      
    } catch (e) {
      debugPrint('[AccountDeletion] Error clearing local storage: $e');
      // Don't throw here - local storage errors shouldn't prevent account deletion
    }
  }

  /// Check if user has any active subscriptions
  static Future<bool> hasActiveSubscriptions(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('[AccountDeletion] Error checking subscriptions: $e');
      return false;
    }
  }

  /// Get user's subscription details for confirmation dialog
  static Future<List<Map<String, dynamic>>> getUserSubscriptions(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('subscriptions')
          .where('status', isEqualTo: 'active')
          .get();
      
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('[AccountDeletion] Error getting subscriptions: $e');
      return [];
    }
  }
}
