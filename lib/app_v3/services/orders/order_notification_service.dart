import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../sms_service.dart';
import '../../models/meal_model_v3.dart';

/// Order Notification Service
/// Handles all SMS notifications for order lifecycle
class OrderNotificationService {
  OrderNotificationService._();
  static final OrderNotificationService instance = OrderNotificationService._();

  /// Send order confirmation when order is placed
  static Future<void> sendOrderConfirmation({
    required String orderId,
    required String customerName,
    required String customerPhone,
    required List<MealModelV3> meals,
    required DateTime estimatedDeliveryTime,
  }) async {
    try {
      // Format estimated delivery time
      final estimatedTime = _formatDeliveryTime(estimatedDeliveryTime);
      
      // Get meal names
      final mealNames = meals.map((meal) => meal.name).toList();
      
      final success = await SMSService.sendOrderConfirmation(
        toNumber: customerPhone,
        orderNumber: orderId,
        customerName: customerName,
        estimatedTime: estimatedTime,
        items: mealNames,
      );

      if (success) {
        debugPrint('[OrderNotification] Confirmation SMS sent for order $orderId');
        
        // Log notification in Firestore
        await _logNotification(
          orderId: orderId,
          type: 'order_confirmation',
          phone: customerPhone,
          status: 'sent',
        );
      } else {
        await _logNotification(
          orderId: orderId,
          type: 'order_confirmation',
          phone: customerPhone,
          status: 'failed',
        );
      }
    } catch (e) {
      debugPrint('[OrderNotification] Error sending confirmation: $e');
    }
  }

  /// Send status update notifications
  static Future<void> sendStatusUpdate({
    required String orderId,
    required String customerPhone,
    required String status,
    DateTime? estimatedDeliveryTime,
    String? driverName,
  }) async {
    try {
      final eta = estimatedDeliveryTime != null 
          ? _formatDeliveryTime(estimatedDeliveryTime)
          : null;

      final success = await SMSService.sendDeliveryUpdate(
        toNumber: customerPhone,
        orderNumber: orderId,
        status: status,
        eta: eta,
        driverName: driverName,
      );

      if (success) {
        debugPrint('[OrderNotification] Status update SMS sent for order $orderId: $status');
        
        await _logNotification(
          orderId: orderId,
          type: 'status_update',
          phone: customerPhone,
          status: 'sent',
          metadata: {'order_status': status},
        );
      }
    } catch (e) {
      debugPrint('[OrderNotification] Error sending status update: $e');
    }
  }

  /// Send driver arrival notification
  static Future<void> sendDriverArrival({
    required String orderId,
    required String customerPhone,
    required String driverName,
    String? driverPhone,
  }) async {
    try {
      final success = await SMSService.sendDriverArrival(
        toNumber: customerPhone,
        orderNumber: orderId,
        driverName: driverName,
        driverPhone: driverPhone,
      );

      if (success) {
        debugPrint('[OrderNotification] Driver arrival SMS sent for order $orderId');
        
        await _logNotification(
          orderId: orderId,
          type: 'driver_arrival',
          phone: customerPhone,
          status: 'sent',
          metadata: {'driver_name': driverName},
        );
      }
    } catch (e) {
      debugPrint('[OrderNotification] Error sending driver arrival: $e');
    }
  }

  /// Send delivery completion notification
  static Future<void> sendDeliveryComplete({
    required String orderId,
    required String customerPhone,
    required String customerName,
  }) async {
    try {
      final success = await SMSService.sendDeliveryUpdate(
        toNumber: customerPhone,
        orderNumber: orderId,
        status: 'delivered',
        eta: null,
        driverName: null,
      );

      if (success) {
        debugPrint('[OrderNotification] Delivery complete SMS sent for order $orderId');
        
        await _logNotification(
          orderId: orderId,
          type: 'delivery_complete',
          phone: customerPhone,
          status: 'sent',
        );
      }
    } catch (e) {
      debugPrint('[OrderNotification] Error sending delivery complete: $e');
    }
  }

  /// Send subscription reminder
  static Future<void> sendSubscriptionReminder({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String planName,
    required DateTime nextDeliveryDate,
  }) async {
    try {
      final deliveryDateStr = _formatDeliveryDate(nextDeliveryDate);
      
      final success = await SMSService.sendSubscriptionReminder(
        toNumber: customerPhone,
        customerName: customerName,
        nextDeliveryDate: deliveryDateStr,
        planName: planName,
      );

      if (success) {
        debugPrint('[OrderNotification] Subscription reminder sent to $customerName');
        
        await _logNotification(
          orderId: customerId,
          type: 'subscription_reminder',
          phone: customerPhone,
          status: 'sent',
          metadata: {'plan_name': planName},
        );
      }
    } catch (e) {
      debugPrint('[OrderNotification] Error sending subscription reminder: $e');
    }
  }

  /// Test SMS functionality
  static Future<bool> testSMS(String phoneNumber) async {
    return await SMSService.sendTestSMS(phoneNumber);
  }

  /// Check if SMS is properly configured
  static bool get isConfigured => SMSService.isConfigured;

  /// Format delivery time for SMS
  static String _formatDeliveryTime(DateTime deliveryTime) {
    final now = DateTime.now();
    final difference = deliveryTime.difference(now);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;
      if (minutes == 0) {
        return '$hours hour${hours == 1 ? '' : 's'}';
      } else {
        return '$hours hour${hours == 1 ? '' : 's'} $minutes min';
      }
    } else {
      // Format as date/time
      final hour = deliveryTime.hour > 12 
          ? deliveryTime.hour - 12 
          : deliveryTime.hour;
      final period = deliveryTime.hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour == 0 ? 12 : hour;
      
      return '${deliveryTime.month}/${deliveryTime.day} at $displayHour:${deliveryTime.minute.toString().padLeft(2, '0')} $period';
    }
  }

  /// Format delivery date for reminders
  static String _formatDeliveryDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final deliveryDate = DateTime(date.year, date.month, date.day);
    
    if (deliveryDate == today) {
      return 'today';
    } else if (deliveryDate == tomorrow) {
      return 'tomorrow';
    } else {
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final weekday = weekdays[date.weekday - 1];
      return '$weekday, ${date.month}/${date.day}';
    }
  }

  /// Log notification to Firestore for tracking
  static Future<void> _logNotification({
    required String orderId,
    required String type,
    required String phone,
    required String status,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'orderId': orderId,
        'type': type,
        'phone': phone,
        'status': status,
        'timestamp': DateTime.now(),
        'metadata': metadata ?? {},
      });
    } catch (e) {
      debugPrint('[OrderNotification] Error logging notification: $e');
    }
  }
}
