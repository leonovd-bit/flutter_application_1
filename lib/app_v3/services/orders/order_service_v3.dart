import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/meal_model_v3.dart';
import '../notifications/notification_service_v3.dart';
// No direct dependency needed here; Firestore writes are local in this service.

class OrderServiceV3 {
  // Creates a single scheduled order document from a delivery schedule entry
  static Future<void> createScheduledOrder({
    required String userId,
    required MealPlanModelV3 plan,
    required DeliveryScheduleModelV3 schedule,
    required AddressModelV3 address,
    required DateTime deliveryDate,
  }) async {
    try {
      final total = plan.pricePerMeal.toDouble();
      final meal = _defaultMealForType(schedule.mealType);

      // Persist to top-level orders for simplicity
      final orderId = FirebaseFirestore.instance.collection('orders').doc().id;
      await FirebaseFirestore.instance.collection('orders').doc(orderId).set({
        'id': orderId,
        'userId': userId,
        'mealPlanId': plan.id,
        'deliveryScheduleId': schedule.id,
        'addressId': address.id,
        'deliveryAddress': address.fullAddress,
        'meals': [meal.toFirestore()],
        'totalAmount': total,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'orderDate': Timestamp.fromDate(DateTime.now()),
        'deliveryDate': Timestamp.fromDate(deliveryDate),
        'estimatedDeliveryTime': Timestamp.fromDate(deliveryDate),
      });
      debugPrint('[Scheduler] Created order $orderId for $userId at $deliveryDate');

      // Schedule a local reminder one hour before delivery
      final notifId = deliveryDate.millisecondsSinceEpoch ~/ 60000; // minute-granularity id
  await NotificationServiceV3.instance.scheduleIfNotExists(
        id: notifId,
        deliveryTime: deliveryDate,
        title: 'Victus delivery',
        body: 'Your ${schedule.mealType} arrives in 1 hour at ${address.label}.',
        payload: orderId,
      );
    } catch (e) {
      debugPrint('Failed to create scheduled order: $e');
      rethrow;
    }
  }

  // Get recent orders for a user
  static Future<List<Map<String, dynamic>>> getUserRecentOrders(String userId, {int limit = 5}) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': _getMealNameFromOrder(data),
          'image': _getMealImageFromOrder(data),
          'date': _formatOrderDate(data['createdAt']),
          'status': data['status'] ?? 'unknown',
        };
      }).toList();
    } catch (e) {
      debugPrint('Failed to fetch user orders: $e');
      return [];
    }
  }

  // Extract meal name from order data
  static String _getMealNameFromOrder(Map<String, dynamic> orderData) {
    final meals = orderData['meals'] as List?;
    if (meals != null && meals.isNotEmpty) {
      final firstMeal = meals.first as Map<String, dynamic>;
      return firstMeal['name'] ?? 'Unknown Meal';
    }
    return 'Custom Order';
  }

  // Extract meal image from order data
  static String _getMealImageFromOrder(Map<String, dynamic> orderData) {
    final meals = orderData['meals'] as List?;
    if (meals != null && meals.isNotEmpty) {
      final firstMeal = meals.first as Map<String, dynamic>;
      return firstMeal['imageUrl'] ?? 'assets/images/meals/default.jpg';
    }
    return 'assets/images/meals/default.jpg';
  }

  // Format order date for display
  static String _formatOrderDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown date';
    
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return 'Unknown date';
      }

      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.month}/${date.day}/${date.year}';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }

  // Minimal default meal by type when we don't have a custom selection
  static MealModelV3 _defaultMealForType(String type) {
    final samples = MealModelV3.getSampleMeals();
    return samples.firstWhere(
      (m) => m.mealType.toLowerCase() == type.toLowerCase(),
      orElse: () => samples.first,
    );
  }
}
