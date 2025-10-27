import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/meal_model_v3.dart';
import '../../config/doordash_config.dart';
import '../doordash_auth_service.dart';

/// DoorDash Drive API Integration Service
/// Handles delivery requests, tracking, and status updates
class DoorDashService {
  DoorDashService._();
  static final DoorDashService instance = DoorDashService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DoorDashAuthService _authService = DoorDashAuthService.instance;

  /// Create a delivery request with DoorDash
  Future<DoorDashDeliveryResponse> createDelivery({
    required String orderId,
    required AddressModelV3 pickupAddress,
    required AddressModelV3 deliveryAddress,
    required List<MealModelV3> items,
    required String customerName,
    required String customerPhone,
    DateTime? requestedDeliveryTime,
    String? specialInstructions,
  }) async {
    try {
      debugPrint('[DoorDash] Creating delivery for order: $orderId');

      final requestBody = {
        'external_delivery_id': orderId,
        'locale': 'en-US',
        'order_fulfillment_method': 'delivery',
        'origin_facility_id': await _getOrCreateFacilityId(),
        'pickup_address': _formatAddress(pickupAddress),
        'pickup_business_name': 'FreshPunk Kitchen',
        'pickup_phone_number': '+1-555-FRESHPUNK', // Your business phone
        'pickup_instructions': 'Please ring bell at kitchen entrance',
        'pickup_time': DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
        'dropoff_address': _formatAddress(deliveryAddress),
        'dropoff_business_name': customerName,
        'dropoff_phone_number': customerPhone,
        'dropoff_instructions': specialInstructions ?? 'Leave at door if no answer',
        'dropoff_cash_on_delivery': 0,
        'order_value': _calculateOrderValue(items),
        'items': _formatItems(items),
        'pickup_window': {
          'start_time': DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
          'end_time': DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
        },
        'dropoff_window': {
          'start_time': requestedDeliveryTime?.toIso8601String() ?? 
                        DateTime.now().add(const Duration(minutes: 45)).toIso8601String(),
          'end_time': requestedDeliveryTime?.add(const Duration(minutes: 30)).toIso8601String() ?? 
                     DateTime.now().add(const Duration(minutes: 75)).toIso8601String(),
        },
        'contactless_dropoff': true,
        'action_if_undeliverable': 'return_to_pickup',
        'tip': 500, // $5.00 tip in cents
      };

      final response = await _makeRequest(
        'POST',
        '/deliveries',
        body: requestBody,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final deliveryResponse = DoorDashDeliveryResponse.fromJson(data);
        
        // Store delivery info in Firestore
        await _storeDeliveryInfo(orderId, deliveryResponse);
        
        debugPrint('[DoorDash] Delivery created successfully: ${deliveryResponse.deliveryId}');
        return deliveryResponse;
      } else {
        throw DoorDashException(
          'Failed to create delivery: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[DoorDash] Error creating delivery: $e');
      rethrow;
    }
  }

  /// Get delivery status and tracking info
  Future<DoorDashDeliveryStatus> getDeliveryStatus(String deliveryId) async {
    try {
      final response = await _makeRequest('GET', '/deliveries/$deliveryId');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DoorDashDeliveryStatus.fromJson(data);
      } else {
        throw DoorDashException(
          'Failed to get delivery status: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[DoorDash] Error getting delivery status: $e');
      rethrow;
    }
  }

  /// Cancel a delivery request
  Future<bool> cancelDelivery(String deliveryId, String reason) async {
    try {
      final response = await _makeRequest(
        'PUT',
        '/deliveries/$deliveryId/cancel',
        body: {'cancellation_reason': reason},
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[DoorDash] Error cancelling delivery: $e');
      return false;
    }
  }

  /// Get delivery quote (pricing estimate)
  Future<DoorDashQuoteResponse> getDeliveryQuote({
    required AddressModelV3 pickupAddress,
    required AddressModelV3 deliveryAddress,
    required List<MealModelV3> items,
    DateTime? requestedDeliveryTime,
  }) async {
    try {
      final requestBody = {
        'pickup_address': _formatAddress(pickupAddress),
        'dropoff_address': _formatAddress(deliveryAddress),
        'order_value': _calculateOrderValue(items),
        'pickup_time': DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
        'dropoff_time': requestedDeliveryTime?.toIso8601String() ?? 
                       DateTime.now().add(const Duration(minutes: 45)).toIso8601String(),
      };

      final response = await _makeRequest(
        'POST',
        '/deliveries/quotes',
        body: requestBody,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DoorDashQuoteResponse.fromJson(data);
      } else {
        throw DoorDashException(
          'Failed to get delivery quote: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[DoorDash] Error getting quote: $e');
      rethrow;
    }
  }

  /// Set up webhook endpoint (for production)
  Future<bool> setupWebhooks(String webhookUrl) async {
    try {
      final response = await _makeRequest(
        'POST',
        '/webhooks',
        body: {
          'url': webhookUrl,
          'events': [
            'delivery_created',
            'delivery_assigned',
            'delivery_picked_up',
            'delivery_delivered',
            'delivery_cancelled',
            'delivery_returned',
          ],
        },
        useDeveloperApi: true,
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('[DoorDash] Error setting up webhooks: $e');
      return false;
    }
  }

  // Helper Methods

  Future<String> _getOrCreateFacilityId() async {
    // In production, register your kitchen/restaurant with DoorDash
    // For now, return a placeholder
    return 'freshpunk_kitchen_001';
  }

  Map<String, dynamic> _formatAddress(AddressModelV3 address) {
    return {
      'street': address.streetAddress,
      'city': address.city,
      'state': address.state,
      'zip': address.zipCode,
      'country': 'US',
    };
  }

  int _calculateOrderValue(List<MealModelV3> items) {
    // Calculate total order value in cents
    return items.fold<int>(0, (sum, item) => sum + (item.price * 100).round());
  }

  List<Map<String, dynamic>> _formatItems(List<MealModelV3> items) {
    return items.map((item) => {
      'name': item.name,
      'description': item.description,
      'quantity': 1,
      'price': (item.price * 100).round(), // Price in cents
    }).toList();
  }

  Future<http.Response> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    bool useDeveloperApi = false,
  }) async {
    final baseUrl = useDeveloperApi ? DoorDashConfig.developerUrl : DoorDashConfig.baseUrl;
    final uri = Uri.parse('$baseUrl$endpoint');
    
    final headers = _authService.getAuthHeaders();

    switch (method.toUpperCase()) {
      case 'GET':
        return await http.get(uri, headers: headers);
      case 'POST':
        return await http.post(
          uri,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
      case 'PUT':
        return await http.put(
          uri,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        );
      case 'DELETE':
        return await http.delete(uri, headers: headers);
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }
  }

  /// Test connection to DoorDash API
  Future<bool> testConnection() async {
    try {
      debugPrint('[DoorDash] Testing API connection...');
      
      // First test authentication
      final authTest = await _authService.testAuthentication();
      if (!authTest) {
        debugPrint('[DoorDash] Authentication test failed');
        return false;
      }

      // Test basic API connectivity (ping endpoint)
      final response = await _makeRequest('GET', '/ping');
      
      if (response.statusCode == 200) {
        debugPrint('[DoorDash] API connection successful');
        return true;
      } else {
        debugPrint('[DoorDash] API connection failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('[DoorDash] Connection test error: $e');
      return false;
    }
  }

  Future<void> _storeDeliveryInfo(String orderId, DoorDashDeliveryResponse delivery) async {
    await _firestore.collection('doordash_deliveries').doc(orderId).set({
      'orderId': orderId,
      'deliveryId': delivery.deliveryId,
      'status': delivery.status,
      'trackingUrl': delivery.trackingUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }
}

// Data Models

class DoorDashDeliveryResponse {
  final String deliveryId;
  final String status;
  final String trackingUrl;
  final String? quotedPrice;
  final DateTime? estimatedPickupTime;
  final DateTime? estimatedDropoffTime;

  DoorDashDeliveryResponse({
    required this.deliveryId,
    required this.status,
    required this.trackingUrl,
    this.quotedPrice,
    this.estimatedPickupTime,
    this.estimatedDropoffTime,
  });

  factory DoorDashDeliveryResponse.fromJson(Map<String, dynamic> json) {
    return DoorDashDeliveryResponse(
      deliveryId: json['delivery_id'] ?? '',
      status: json['delivery_status'] ?? 'created',
      trackingUrl: json['tracking_url'] ?? '',
      quotedPrice: json['fee']?.toString(),
      estimatedPickupTime: json['pickup_time'] != null 
          ? DateTime.parse(json['pickup_time'])
          : null,
      estimatedDropoffTime: json['dropoff_time'] != null 
          ? DateTime.parse(json['dropoff_time'])
          : null,
    );
  }
}

class DoorDashDeliveryStatus {
  final String deliveryId;
  final String status;
  final String? driverName;
  final String? driverPhone;
  final double? driverLatitude;
  final double? driverLongitude;
  final DateTime? estimatedPickupTime;
  final DateTime? estimatedDropoffTime;
  final DateTime? actualPickupTime;
  final DateTime? actualDropoffTime;

  DoorDashDeliveryStatus({
    required this.deliveryId,
    required this.status,
    this.driverName,
    this.driverPhone,
    this.driverLatitude,
    this.driverLongitude,
    this.estimatedPickupTime,
    this.estimatedDropoffTime,
    this.actualPickupTime,
    this.actualDropoffTime,
  });

  factory DoorDashDeliveryStatus.fromJson(Map<String, dynamic> json) {
    final dasher = json['dasher_info'];
    final location = dasher?['location'];
    
    return DoorDashDeliveryStatus(
      deliveryId: json['delivery_id'] ?? '',
      status: json['delivery_status'] ?? '',
      driverName: dasher?['name'],
      driverPhone: dasher?['phone_number'],
      driverLatitude: location?['lat']?.toDouble(),
      driverLongitude: location?['lng']?.toDouble(),
      estimatedPickupTime: json['pickup_time'] != null 
          ? DateTime.parse(json['pickup_time'])
          : null,
      estimatedDropoffTime: json['dropoff_time'] != null 
          ? DateTime.parse(json['dropoff_time'])
          : null,
      actualPickupTime: json['picked_up_at'] != null 
          ? DateTime.parse(json['picked_up_at'])
          : null,
      actualDropoffTime: json['delivered_at'] != null 
          ? DateTime.parse(json['delivered_at'])
          : null,
    );
  }
}

class DoorDashQuoteResponse {
  final int deliveryFee; // in cents
  final int estimatedDurationMinutes;
  final String currency;

  DoorDashQuoteResponse({
    required this.deliveryFee,
    required this.estimatedDurationMinutes,
    required this.currency,
  });

  factory DoorDashQuoteResponse.fromJson(Map<String, dynamic> json) {
    return DoorDashQuoteResponse(
      deliveryFee: json['fee'] ?? 0,
      estimatedDurationMinutes: json['duration'] ?? 0,
      currency: json['currency'] ?? 'USD',
    );
  }

  double get deliveryFeeInDollars => deliveryFee / 100.0;
}

class DoorDashException implements Exception {
  final String message;
  DoorDashException(this.message);

  @override
  String toString() => 'DoorDashException: $message';
}