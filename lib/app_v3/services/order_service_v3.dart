import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meal_model_v3.dart';
import 'notification_service_v3.dart';
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
        title: 'FreshPunk delivery',
        body: 'Your ${schedule.mealType} arrives in 1 hour at ${address.label}.',
        payload: orderId,
      );
    } catch (e) {
      debugPrint('Failed to create scheduled order: $e');
      rethrow;
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
