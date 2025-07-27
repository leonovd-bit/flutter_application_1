import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order.dart' as app_models;

class OrderService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'orders';

  // Get upcoming order for user
  static Future<app_models.Order?> getUpcomingOrder(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['OrderStatus.scheduled', 'OrderStatus.confirmed'])
          .orderBy('scheduledDeliveryTime')
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      return app_models.Order.fromMap(querySnapshot.docs.first.data());
    } catch (e) {
      print('Error getting upcoming order: $e');
      return null;
    }
  }

  // Get active order (confirmed, ready, picked up, out for delivery)
  static Future<app_models.Order?> getActiveOrder(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: [
            'OrderStatus.confirmed',
            'OrderStatus.ready',
            'OrderStatus.pickedUp',
            'OrderStatus.outForDelivery'
          ])
          .orderBy('scheduledDeliveryTime')
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return null;

      return app_models.Order.fromMap(querySnapshot.docs.first.data());
    } catch (e) {
      print('Error getting active order: $e');
      return null;
    }
  }

  // Stream real-time order updates
  static Stream<app_models.Order?> streamOrderUpdates(String orderId) {
    return _firestore
        .collection(_collection)
        .doc(orderId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return app_models.Order.fromMap(snapshot.data()!);
    });
  }

  // Confirm order
  static Future<bool> confirmOrder(String orderId) async {
    try {
      await _firestore.collection(_collection).doc(orderId).update({
        'status': app_models.OrderStatus.confirmed.toString(),
        'confirmedAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error confirming order: $e');
      return false;
    }
  }

  // Cancel order
  static Future<bool> cancelOrder(String orderId) async {
    try {
      await _firestore.collection(_collection).doc(orderId).update({
        'status': app_models.OrderStatus.cancelled.toString(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error cancelling order: $e');
      return false;
    }
  }

  // Update order status (for admin/kitchen use)
  static Future<bool> updateOrderStatus(String orderId, app_models.OrderStatus status) async {
    try {
      final updateData = {
        'status': status.toString(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Add timestamp for specific status
      switch (status) {
        case app_models.OrderStatus.confirmed:
          updateData['confirmedAt'] = DateTime.now().toIso8601String();
          break;
        case app_models.OrderStatus.ready:
          updateData['readyAt'] = DateTime.now().toIso8601String();
          break;
        case app_models.OrderStatus.pickedUp:
          updateData['pickedUpAt'] = DateTime.now().toIso8601String();
          break;
        case app_models.OrderStatus.outForDelivery:
          updateData['outForDeliveryAt'] = DateTime.now().toIso8601String();
          break;
        case app_models.OrderStatus.delivered:
          updateData['deliveredAt'] = DateTime.now().toIso8601String();
          break;
        default:
          break;
      }

      await _firestore.collection(_collection).doc(orderId).update(updateData);
      return true;
    } catch (e) {
      print('Error updating order status: $e');
      return false;
    }
  }

  // Replace meal in order
  static Future<bool> replaceMeal(String orderId, String newMealId, String newMealName, String newMealDescription, String newMealImageUrl) async {
    try {
      await _firestore.collection(_collection).doc(orderId).update({
        'mealId': newMealId,
        'mealName': newMealName,
        'mealDescription': newMealDescription,
        'mealImageUrl': newMealImageUrl,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error replacing meal: $e');
      return false;
    }
  }

  // Update notification sent flag
  static Future<bool> markNotificationSent(String orderId) async {
    try {
      await _firestore.collection(_collection).doc(orderId).update({
        'notificationSent': true,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error marking notification sent: $e');
      return false;
    }
  }

  // Auto-confirm order
  static Future<bool> autoConfirmOrder(String orderId) async {
    try {
      await _firestore.collection(_collection).doc(orderId).update({
        'status': app_models.OrderStatus.confirmed.toString(),
        'confirmedAt': DateTime.now().toIso8601String(),
        'autoConfirmed': true,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error auto-confirming order: $e');
      return false;
    }
  }

  // Create mock upcoming order for testing
  static Future<String?> createMockOrder(String userId) async {
    try {
      final order = app_models.Order(
        id: _firestore.collection(_collection).doc().id,
        userId: userId,
        mealId: 'meal_1',
        mealName: 'Mediterranean Quinoa Bowl',
        mealDescription: 'Fresh quinoa with grilled vegetables, feta cheese, and tahini dressing',
        mealImageUrl: 'https://example.com/mediterranean-bowl.jpg',
        scheduledDeliveryTime: DateTime.now().add(const Duration(hours: 2)),
        deliveryAddressId: 'addr_1',
        deliveryAddressText: '123 Main St, Apt 4B, New York, NY 10001',
        status: app_models.OrderStatus.scheduled,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection(_collection).doc(order.id).set(order.toMap());
      return order.id;
    } catch (e) {
      print('Error creating mock order: $e');
      return null;
    }
  }
}
