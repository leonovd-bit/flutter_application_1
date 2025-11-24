import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../utils/cloud_functions_helper.dart';

/// Service for managing restaurant notifications and partnerships
class RestaurantNotificationService {
  static const _region = 'us-central1';
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: _region);
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static HttpsCallable _callable(String name) {
    return callableForPlatform(
      functions: _functions,
      functionName: name,
      region: _region,
    );
  }

  // ============================================================================
  // RESTAURANT REGISTRATION
  // ============================================================================

  /// Register a new restaurant partner
  static Future<Map<String, dynamic>> registerRestaurant({
    required String restaurantName,
    required String contactEmail,
    String? contactPhone,
    String? address,
    String businessType = 'restaurant',
    String? description,
    Map<String, bool>? notificationPreferences,
  }) async {
    try {
  final callable = _callable('registerRestaurantPartner');
      final result = await callable.call({
        'restaurantName': restaurantName,
        'contactEmail': contactEmail,
        'contactPhone': contactPhone,
        'address': address,
        'businessType': businessType,
        'description': description,
        'notificationPreferences': notificationPreferences ?? {
          'email': true,
          'sms': contactPhone != null,
          'dashboard': true,
        },
      });

      return {
        'success': true,
        'restaurantId': result.data['restaurantId'],
        'message': result.data['message'],
      };

    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Validate restaurant registration data
  static Map<String, dynamic> validateRestaurantData({
    required String restaurantName,
    required String contactEmail,
    String? contactPhone,
  }) {
    List<String> errors = [];

    if (restaurantName.trim().isEmpty) {
      errors.add('Restaurant name is required');
    }

    if (contactEmail.trim().isEmpty) {
      errors.add('Contact email is required');
    } else if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(contactEmail)) {
      errors.add('Please enter a valid email address');
    }

    if (contactPhone != null && contactPhone.isNotEmpty) {
      // Basic phone validation
      final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{10,}$');
      if (!phoneRegex.hasMatch(contactPhone)) {
        errors.add('Please enter a valid phone number');
      }
    }

    return {
      'isValid': errors.isEmpty,
      'errors': errors,
    };
  }

  // ============================================================================
  // ORDER NOTIFICATIONS
  // ============================================================================

  /// Send notification to restaurants about new orders
  static Future<Map<String, dynamic>> sendOrderNotification({
    required String orderId,
    String? restaurantId,
  }) async {
    try {
  final callable = _callable('sendRestaurantOrderNotification');
      final result = await callable.call({
        'orderId': orderId,
        if (restaurantId != null) 'restaurantId': restaurantId,
      });

      return {
        'success': true,
        'message': result.data['message'],
      };

    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get restaurant orders and notifications
  static Future<Map<String, dynamic>> getRestaurantOrders({
    required String restaurantId,
    int limit = 50,
  }) async {
    try {
  final callable = _callable('getRestaurantOrders');
      final result = await callable.call({
        'restaurantId': restaurantId,
        'limit': limit,
      });

      return {
        'success': true,
        'notifications': result.data['notifications'],
        'restaurant': result.data['restaurant'],
        'total': result.data['total'],
      };

    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'notifications': [],
        'total': 0,
      };
    }
  }

  /// Stream restaurant notifications in real-time
  static Stream<QuerySnapshot> streamRestaurantNotifications(String restaurantId) {
    return _firestore
        .collection('restaurant_notifications')
        .where('restaurantId', isEqualTo: restaurantId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  /// Mark notification as read
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('restaurant_notifications')
          .doc(notificationId)
          .update({
        'readAt': FieldValue.serverTimestamp(),
        'status': 'read',
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Acknowledge notification (restaurant confirms they received it)
  static Future<void> acknowledgeNotification(String notificationId) async {
    try {
      await _firestore
          .collection('restaurant_notifications')
          .doc(notificationId)
          .update({
        'acknowledgedAt': FieldValue.serverTimestamp(),
        'status': 'acknowledged',
      });
    } catch (e) {
      print('Error acknowledging notification: $e');
    }
  }

  // ============================================================================
  // RESTAURANT MANAGEMENT
  // ============================================================================

  /// Get restaurant profile data
  static Future<Map<String, dynamic>?> getRestaurantProfile(String restaurantId) async {
    try {
      final doc = await _firestore
          .collection('restaurant_partners')
          .doc(restaurantId)
          .get();

      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    } catch (e) {
      print('Error getting restaurant profile: $e');
      return null;
    }
  }

  /// Update restaurant notification preferences
  static Future<bool> updateNotificationPreferences(
    String restaurantId,
    Map<String, bool> preferences,
  ) async {
    try {
      await _firestore
          .collection('restaurant_partners')
          .doc(restaurantId)
          .update({
        'notificationMethods': preferences,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error updating notification preferences: $e');
      return false;
    }
  }

  /// Stream restaurant statistics
  static Stream<DocumentSnapshot> streamRestaurantStats(String restaurantId) {
    return _firestore
        .collection('restaurant_partners')
        .doc(restaurantId)
        .snapshots();
  }

  // ============================================================================
  // UTILITY FUNCTIONS
  // ============================================================================

  /// Format notification for display
  static String formatNotificationSummary(Map<String, dynamic> notification) {
    final customerName = notification['customerName'] ?? 'Customer';
    final deliveryDate = notification['deliveryDate'] ?? 'TBD';
    final meals = notification['meals'] as List? ?? [];
    final mealCount = meals.length;

    return '$customerName - $mealCount items for $deliveryDate';
  }

  /// Get notification icon based on status
  static String getNotificationIcon(String status) {
    switch (status) {
      case 'pending':
        return '🔔';
      case 'read':
        return '👁️';
      case 'acknowledged':
        return '✅';
      default:
        return '📋';
    }
  }

  /// Calculate time since notification
  static String getTimeAgo(String createdAt) {
    try {
      final dateTime = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Get business type display name
  static String getBusinessTypeDisplayName(String businessType) {
    switch (businessType) {
      case 'restaurant':
        return 'Restaurant';
      case 'cafe':
        return 'Café';
      case 'bakery':
        return 'Bakery';
      case 'food_truck':
        return 'Food Truck';
      case 'catering':
        return 'Catering Service';
      default:
        return businessType.split('_').map((word) => 
          word[0].toUpperCase() + word.substring(1)).join(' ');
    }
  }

  /// Get sample notification data for UI testing
  static List<Map<String, dynamic>> getSampleNotifications() {
    return [
      {
        'id': 'sample_1',
        'orderId': 'order_123',
        'customerName': 'John Doe',
        'deliveryDate': '2025-09-24',
        'deliveryTime': '12:30 PM',
        'meals': [
          {'name': 'Caesar Salad', 'quantity': 2, 'price': '12.99'},
          {'name': 'Grilled Chicken', 'quantity': 1, 'price': '18.99'},
        ],
        'totalAmount': 44.97,
        'status': 'pending',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
      },
      {
        'id': 'sample_2',
        'orderId': 'order_124',
        'customerName': 'Jane Smith',
        'deliveryDate': '2025-09-25',
        'deliveryTime': '6:00 PM',
        'meals': [
          {'name': 'Vegetarian Pasta', 'quantity': 1, 'price': '15.99'},
        ],
        'totalAmount': 15.99,
        'status': 'read',
        'createdAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      },
    ];
  }

  /// Validate notification data
  static bool isValidNotification(Map<String, dynamic> notification) {
    return notification.containsKey('orderId') &&
           notification.containsKey('customerName') &&
           notification.containsKey('deliveryDate') &&
           notification.containsKey('meals') &&
           (notification['meals'] as List).isNotEmpty;
  }

  /// Format phone number for display
  static String formatPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    
    // Basic formatting for US phone numbers
    final cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length == 10) {
      return '(${cleaned.substring(0, 3)}) ${cleaned.substring(3, 6)}-${cleaned.substring(6)}';
    } else if (cleaned.length == 11 && cleaned.startsWith('1')) {
      return '+1 (${cleaned.substring(1, 4)}) ${cleaned.substring(4, 7)}-${cleaned.substring(7)}';
    }
    return phone; // Return original if formatting fails
  }
}