import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../utils/cloud_functions_helper.dart';

class OrderGenerationService {
  static const _region = 'us-central1';
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: _region);

  static HttpsCallable _callable(String name) {
    return callableForPlatform(
      functions: _functions,
      functionName: name,
      region: _region,
    );
  }

  /// Generates orders from meal selections and delivery schedule
  /// This replaces the manual order creation with server-side validation
  static Future<Map<String, dynamic>> generateOrdersFromMealSelection({
    required List<Map<String, dynamic>> mealSelections,
    required Map<String, dynamic> deliverySchedule,
    required String deliveryAddress,
  }) async {
    try {
      debugPrint('[OrderGenerationService] Generating orders from meal selection...');
      debugPrint('[OrderGenerationService] Meal selections: ${mealSelections.length}');
      debugPrint('[OrderGenerationService] Delivery schedule days: ${deliverySchedule.keys.length}');
      debugPrint('[OrderGenerationService] Delivery address: $deliveryAddress');

      // Get user's timezone offset in hours (e.g., -5 for EST, -4 for EDT)
      final now = DateTime.now();
      final timezoneOffsetHours = now.timeZoneOffset.inHours;
      debugPrint('[OrderGenerationService] Timezone offset: $timezoneOffsetHours hours');

  final callable = _callable('generateOrderFromMealSelection');
      
      final result = await callable.call({
        'mealSelections': mealSelections,
        'deliverySchedule': deliverySchedule,
        'deliveryAddress': deliveryAddress,
        'timezoneOffsetHours': timezoneOffsetHours,
      });

      final data = result.data as Map<String, dynamic>;
      debugPrint('[OrderGenerationService] Successfully generated ${data['ordersGenerated']} orders');
      
      return {
        'success': true,
        'ordersGenerated': data['ordersGenerated'] ?? 0,
        'orders': data['orders'] ?? [],
        'message': 'Orders generated successfully',
      };

    } catch (e) {
      debugPrint('[OrderGenerationService] Error generating orders: $e');
      
      String errorMessage = 'Failed to generate orders';
      if (e.toString().contains('unauthenticated')) {
        errorMessage = 'Please log in to continue';
      } else if (e.toString().contains('invalid-argument')) {
        errorMessage = 'Invalid meal selections or delivery schedule';
      } else if (e.toString().contains('resource-exhausted')) {
        errorMessage = 'Too many requests, please try again later';
      }
      
      return {
        'success': false,
        'error': errorMessage,
        'details': e.toString(),
      };
    }
  }

  /// Sends order confirmation via email and optionally SMS
  static Future<Map<String, dynamic>> sendOrderConfirmation({
    required String orderId,
    List<String> notificationTypes = const ['email'],
  }) async {
    try {
      debugPrint('[OrderGenerationService] Sending order confirmation for: $orderId');
      debugPrint('[OrderGenerationService] Notification types: $notificationTypes');

  final callable = _callable('sendOrderConfirmation');
      
      final result = await callable.call({
        'orderId': orderId,
        'notificationTypes': notificationTypes,
      });

      final data = result.data as Map<String, dynamic>;
      debugPrint('[OrderGenerationService] Order confirmation sent successfully');
      
      return {
        'success': true,
        'orderId': data['orderId'],
        'confirmations': data['confirmations'] ?? {},
        'message': 'Order confirmation sent',
      };

    } catch (e) {
      debugPrint('[OrderGenerationService] Error sending confirmation: $e');
      
      String errorMessage = 'Failed to send order confirmation';
      if (e.toString().contains('not-found')) {
        errorMessage = 'Order not found';
      } else if (e.toString().contains('permission-denied')) {
        errorMessage = 'Access denied to this order';
      }
      
      return {
        'success': false,
        'error': errorMessage,
        'details': e.toString(),
      };
    }
  }

  /// Confirms the user's next pending order via Cloud Function
  static Future<Map<String, dynamic>> confirmNextOrder({required String orderId}) async {
    try {
      debugPrint('[OrderGenerationService] Confirming next order: $orderId');
      final callable = _callable('confirmNextOrder');
      final result = await callable.call({'orderId': orderId});
      final data = (result.data is Map<String, dynamic>)
          ? result.data as Map<String, dynamic>
          : <String, dynamic>{};

      return {
        'success': true,
        ...data,
      };
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[OrderGenerationService] confirmNextOrder failed: ${e.code} ${e.message}');
      return {
        'success': false,
        'code': e.code,
        'error': e.message ?? 'Failed to confirm order',
        'details': e.details,
      };
    } catch (e) {
      debugPrint('[OrderGenerationService] confirmNextOrder error: $e');
      return {
        'success': false,
        'error': 'Failed to confirm order',
        'details': e.toString(),
      };
    }
  }

  /// Helper method to validate meal selections before sending to server
  static bool validateMealSelections(List<Map<String, dynamic>> mealSelections) {
    if (mealSelections.isEmpty) {
      debugPrint('[OrderGenerationService] Validation failed: No meals selected');
      return false;
    }

    for (int i = 0; i < mealSelections.length; i++) {
      final meal = mealSelections[i];
      if (!meal.containsKey('id') || meal['id'] == null || meal['id'].toString().isEmpty) {
        debugPrint('[OrderGenerationService] Validation failed: Meal $i missing ID');
        return false;
      }
      if (!meal.containsKey('name') || meal['name'] == null || meal['name'].toString().isEmpty) {
        debugPrint('[OrderGenerationService] Validation failed: Meal $i missing name');
        return false;
      }
    }

    debugPrint('[OrderGenerationService] Meal selections validation passed');
    return true;
  }

  /// Helper method to validate delivery schedule
  static bool validateDeliverySchedule(Map<String, dynamic> deliverySchedule) {
    if (deliverySchedule.isEmpty) {
      debugPrint('[OrderGenerationService] Validation failed: No delivery schedule');
      return false;
    }

    final validDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    int validDayCount = 0;

    for (final day in deliverySchedule.keys) {
      if (!validDays.contains(day.toLowerCase())) {
        debugPrint('[OrderGenerationService] Validation failed: Invalid day $day');
        return false;
      }

      final daySchedule = deliverySchedule[day] as Map<String, dynamic>?;
      if (daySchedule == null) continue;

      bool hasValidMeal = false;
      for (final mealType in ['breakfast', 'lunch', 'dinner']) {
        final mealConfig = daySchedule[mealType] as Map<String, dynamic>?;
        if (mealConfig != null && mealConfig['time'] != null) {
          // Validate time format (HH:mm)
          final timeStr = mealConfig['time'].toString();
          if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(timeStr)) {
            hasValidMeal = true;
          }
        }
      }

      if (hasValidMeal) {
        validDayCount++;
      }
    }

    if (validDayCount == 0) {
      debugPrint('[OrderGenerationService] Validation failed: No valid meal times found');
      return false;
    }

    debugPrint('[OrderGenerationService] Delivery schedule validation passed ($validDayCount valid days)');
    return true;
  }

  /// Get current user ID for order operations
  static String? getCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  /// Check if user is authenticated
  static bool isUserAuthenticated() {
    return FirebaseAuth.instance.currentUser != null;
  }
}