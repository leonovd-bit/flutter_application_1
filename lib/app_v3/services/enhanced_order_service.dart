import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meal_model_v3.dart';
import 'doordash_service.dart';
import 'order_notification_service.dart';

/// Enhanced Order Service with DoorDash Integration
/// Manages order lifecycle from placement to delivery completion
class EnhancedOrderService {
  EnhancedOrderService._();
  static final EnhancedOrderService instance = EnhancedOrderService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DoorDashService _doorDashService = DoorDashService.instance;

  /// Create order with DoorDash delivery integration
  Future<OrderCreationResult> createOrderWithDelivery({
    required String userId,
    required List<MealModelV3> meals,
    required AddressModelV3 deliveryAddress,
    required String customerName,
    required String customerPhone,
    DateTime? requestedDeliveryTime,
    String? specialInstructions,
    bool useDoorDashDelivery = true,
  }) async {
    try {
      debugPrint('[EnhancedOrder] Creating order for user: $userId');

      // 1. Create order document in Firestore
      final orderId = _firestore.collection('orders').doc().id;
      final orderTotal = meals.fold<double>(0, (sum, meal) => sum + meal.price);

      final orderData = {
        'id': orderId,
        'userId': userId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'status': 'pending',
        'meals': meals.map((meal) => meal.toJson()).toList(),
        'deliveryAddress': deliveryAddress.toJson(),
        'specialInstructions': specialInstructions,
        'orderTotal': orderTotal,
        'createdAt': FieldValue.serverTimestamp(),
        'requestedDeliveryTime': requestedDeliveryTime,
        'deliveryMethod': useDoorDashDelivery ? 'doordash' : 'internal',
      };

      await _firestore.collection('orders').doc(orderId).set(orderData);

      // 2. Get delivery quote first
      DoorDashQuoteResponse? quote;
      if (useDoorDashDelivery) {
        try {
          quote = await _doorDashService.getDeliveryQuote(
            pickupAddress: await _getKitchenAddress(),
            deliveryAddress: deliveryAddress,
            items: meals,
            requestedDeliveryTime: requestedDeliveryTime,
          );
          
          // Update order with delivery fee
          await _firestore.collection('orders').doc(orderId).update({
            'deliveryFee': quote.deliveryFeeInDollars,
            'estimatedDeliveryDuration': quote.estimatedDurationMinutes,
          });
        } catch (e) {
          debugPrint('[EnhancedOrder] Failed to get DoorDash quote: $e');
          // Continue without DoorDash if quote fails
          useDoorDashDelivery = false;
        }
      }

      // 3. Send order confirmation
      await OrderNotificationService.sendOrderConfirmation(
        orderId: orderId,
        customerName: customerName,
        customerPhone: customerPhone,
        meals: meals,
        estimatedDeliveryTime: requestedDeliveryTime ?? 
            DateTime.now().add(Duration(minutes: quote?.estimatedDurationMinutes ?? 45)),
      );

      // 4. Update order status to confirmed
      await _updateOrderStatus(orderId, 'confirmed');

      return OrderCreationResult(
        success: true,
        orderId: orderId,
        deliveryQuote: quote,
        useDoorDashDelivery: useDoorDashDelivery,
      );

    } catch (e) {
      debugPrint('[EnhancedOrder] Error creating order: $e');
      return OrderCreationResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Request DoorDash delivery for an existing order
  Future<bool> requestDoorDashDelivery(String orderId) async {
    try {
      debugPrint('[EnhancedOrder] Requesting DoorDash delivery for order: $orderId');

      // Get order details
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }

      final orderData = orderDoc.data()!;
      final meals = (orderData['meals'] as List)
          .map((mealData) => MealModelV3.fromJson(mealData))
          .toList();
      final deliveryAddress = AddressModelV3.fromJson(orderData['deliveryAddress']);

      // Create DoorDash delivery
      final deliveryResponse = await _doorDashService.createDelivery(
        orderId: orderId,
        pickupAddress: await _getKitchenAddress(),
        deliveryAddress: deliveryAddress,
        items: meals,
        customerName: orderData['customerName'],
        customerPhone: orderData['customerPhone'],
        requestedDeliveryTime: orderData['requestedDeliveryTime']?.toDate(),
        specialInstructions: orderData['specialInstructions'],
      );

      // Update order with DoorDash delivery info
      await _firestore.collection('orders').doc(orderId).update({
        'deliveryMethod': 'doordash',
        'doorDashDeliveryId': deliveryResponse.deliveryId,
        'trackingUrl': deliveryResponse.trackingUrl,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Update status to preparing
      await _updateOrderStatus(orderId, 'preparing');

      debugPrint('[EnhancedOrder] DoorDash delivery created: ${deliveryResponse.deliveryId}');
      return true;

    } catch (e) {
      debugPrint('[EnhancedOrder] Error requesting DoorDash delivery: $e');
      return false;
    }
  }

  /// Update order status and trigger appropriate notifications
  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'status': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Get order data for notifications
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) return;

      final orderData = orderDoc.data()!;
      final customerPhone = orderData['customerPhone'];
      final customerName = orderData['customerName'];

      // Send status update notification
      switch (newStatus) {
        case 'preparing':
          await OrderNotificationService.sendStatusUpdate(
            orderId: orderId,
            customerPhone: customerPhone,
            status: 'preparing',
            estimatedDeliveryTime: DateTime.now().add(const Duration(minutes: 30)),
          );
          break;

        case 'ready_for_pickup':
          await OrderNotificationService.sendStatusUpdate(
            orderId: orderId,
            customerPhone: customerPhone,
            status: 'ready',
            estimatedDeliveryTime: DateTime.now().add(const Duration(minutes: 15)),
          );
          break;

        case 'out_for_delivery':
          await OrderNotificationService.sendStatusUpdate(
            orderId: orderId,
            customerPhone: customerPhone,
            status: 'out_for_delivery',
          );
          break;

        case 'delivered':
          await OrderNotificationService.sendDeliveryComplete(
            orderId: orderId,
            customerPhone: customerPhone,
            customerName: customerName,
          );
          break;
      }

      debugPrint('[EnhancedOrder] Order $orderId status updated to: $newStatus');

    } catch (e) {
      debugPrint('[EnhancedOrder] Error updating order status: $e');
    }
  }

  /// Monitor DoorDash delivery status and sync with local order
  Future<void> syncDoorDashDeliveryStatus(String orderId) async {
    try {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) return;

      final orderData = orderDoc.data()!;
      final doorDashDeliveryId = orderData['doorDashDeliveryId'];
      
      if (doorDashDeliveryId == null) return;

      // Get current DoorDash status
      final deliveryStatus = await _doorDashService.getDeliveryStatus(doorDashDeliveryId);

      // Map DoorDash status to internal status
      String internalStatus = _mapDoorDashStatus(deliveryStatus.status);
      
      // Update if status changed
      if (orderData['status'] != internalStatus) {
        await _updateOrderStatus(orderId, internalStatus);
        
        // Update driver info if available
        if (deliveryStatus.driverName != null) {
          await _firestore.collection('orders').doc(orderId).update({
            'driverName': deliveryStatus.driverName,
            'driverPhone': deliveryStatus.driverPhone,
            'driverLocation': deliveryStatus.driverLatitude != null ? {
              'latitude': deliveryStatus.driverLatitude,
              'longitude': deliveryStatus.driverLongitude,
            } : null,
          });
        }
      }

    } catch (e) {
      debugPrint('[EnhancedOrder] Error syncing DoorDash status: $e');
    }
  }

  /// Get real-time delivery tracking information
  Future<DeliveryTrackingInfo?> getDeliveryTracking(String orderId) async {
    try {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) return null;

      final orderData = orderDoc.data()!;
      final doorDashDeliveryId = orderData['doorDashDeliveryId'];

      if (doorDashDeliveryId != null) {
        // Get DoorDash tracking info
        final deliveryStatus = await _doorDashService.getDeliveryStatus(doorDashDeliveryId);
        
        return DeliveryTrackingInfo(
          orderId: orderId,
          status: deliveryStatus.status,
          driverName: deliveryStatus.driverName,
          driverPhone: deliveryStatus.driverPhone,
          driverLatitude: deliveryStatus.driverLatitude,
          driverLongitude: deliveryStatus.driverLongitude,
          estimatedDeliveryTime: deliveryStatus.estimatedDropoffTime,
          trackingUrl: orderData['trackingUrl'],
        );
      } else {
        // Return basic tracking info for internal delivery
        return DeliveryTrackingInfo(
          orderId: orderId,
          status: orderData['status'],
          estimatedDeliveryTime: orderData['requestedDeliveryTime']?.toDate(),
        );
      }

    } catch (e) {
      debugPrint('[EnhancedOrder] Error getting delivery tracking: $e');
      return null;
    }
  }

  /// Cancel order and DoorDash delivery if applicable
  Future<bool> cancelOrder(String orderId, String reason) async {
    try {
      final orderDoc = await _firestore.collection('orders').doc(orderId).get();
      if (!orderDoc.exists) return false;

      final orderData = orderDoc.data()!;
      final doorDashDeliveryId = orderData['doorDashDeliveryId'];

      // Cancel DoorDash delivery if exists
      if (doorDashDeliveryId != null) {
        await _doorDashService.cancelDelivery(doorDashDeliveryId, reason);
      }

      // Update order status
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'cancelled',
        'cancellationReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[EnhancedOrder] Order $orderId cancelled');
      return true;

    } catch (e) {
      debugPrint('[EnhancedOrder] Error cancelling order: $e');
      return false;
    }
  }

  // Helper Methods

  Future<AddressModelV3> _getKitchenAddress() async {
    // Return your kitchen/restaurant address
    // In production, store this in Firestore or configuration
    return AddressModelV3(
      id: 'kitchen_001',
      userId: 'system',
      label: 'FreshPunk Kitchen',
      streetAddress: '123 Kitchen Street',
      city: 'Foodville',
      state: 'CA',
      zipCode: '90210',
    );
  }

  String _mapDoorDashStatus(String doorDashStatus) {
    switch (doorDashStatus.toLowerCase()) {
      case 'created':
      case 'estimated':
        return 'confirmed';
      case 'assigned':
        return 'preparing';
      case 'picked_up':
        return 'out_for_delivery';
      case 'delivered':
        return 'delivered';
      case 'cancelled':
      case 'returned':
        return 'cancelled';
      default:
        return 'pending';
    }
  }
}

// Data Models

class OrderCreationResult {
  final bool success;
  final String? orderId;
  final String? error;
  final DoorDashQuoteResponse? deliveryQuote;
  final bool useDoorDashDelivery;

  OrderCreationResult({
    required this.success,
    this.orderId,
    this.error,
    this.deliveryQuote,
    this.useDoorDashDelivery = false,
  });
}

class DeliveryTrackingInfo {
  final String orderId;
  final String status;
  final String? driverName;
  final String? driverPhone;
  final double? driverLatitude;
  final double? driverLongitude;
  final DateTime? estimatedDeliveryTime;
  final String? trackingUrl;

  DeliveryTrackingInfo({
    required this.orderId,
    required this.status,
    this.driverName,
    this.driverPhone,
    this.driverLatitude,
    this.driverLongitude,
    this.estimatedDeliveryTime,
    this.trackingUrl,
  });

  bool get hasDriverLocation => driverLatitude != null && driverLongitude != null;
}