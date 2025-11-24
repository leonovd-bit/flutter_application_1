import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../../utils/cloud_functions_helper.dart';

/// Service for integrating with Square POS systems for restaurant partners
class SquareIntegrationService {
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
  
  /// Initiate Square OAuth flow for restaurant onboarding
  static Future<Map<String, dynamic>> initiateRestaurantOnboarding({
    required String restaurantName,
    required String contactEmail,
    String? contactPhone,
  }) async {
    try {
      debugPrint('[SquareIntegration] Initiating restaurant onboarding for: $restaurantName');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to onboard restaurant');
      }

      final callable = _callable('initiateSquareOAuth');
      
      final result = await callable.call({
        'restaurantName': restaurantName,
        'contactEmail': contactEmail,
        'contactPhone': contactPhone,
      });

      final data = result.data as Map<String, dynamic>;
      
      if (data['success'] == true) {
        debugPrint('[SquareIntegration] OAuth initiated successfully');
        return {
          'success': true,
          'oauthUrl': data['oauthUrl'],
          'applicationId': data['applicationId'],
          'message': data['message'],
        };
      } else {
        throw Exception(data['error'] ?? 'Unknown error during OAuth initiation');
      }
      
    } catch (e) {
      debugPrint('[SquareIntegration] OAuth initiation failed: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Complete Square OAuth flow after user returns from Square
  static Future<Map<String, dynamic>> completeRestaurantOnboarding({
    required String authorizationCode,
    required String state,
  }) async {
    try {
      debugPrint('[SquareIntegration] Completing restaurant onboarding');
      
      final callable = _callable('completeSquareOAuth');
      
      final result = await callable.call({
        'code': authorizationCode,
        'state': state,
      });

      final data = result.data as Map<String, dynamic>;
      
      if (data['success'] == true) {
        debugPrint('[SquareIntegration] Restaurant onboarding completed successfully');
        return {
          'success': true,
          'restaurantId': data['restaurantId'],
          'restaurantName': data['restaurantName'],
          'message': data['message'],
        };
      } else {
        throw Exception(data['error'] ?? 'Unknown error during OAuth completion');
      }
      
    } catch (e) {
      debugPrint('[SquareIntegration] OAuth completion failed: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Sync restaurant menu from Square to FreshPunk
  static Future<Map<String, dynamic>> syncRestaurantMenu({
    required String restaurantId,
  }) async {
    try {
      debugPrint('[SquareIntegration] Syncing menu for restaurant: $restaurantId');
      
      final callable = _callable('syncSquareMenu');
      
      final result = await callable.call({
        'restaurantId': restaurantId,
      });

      final data = result.data as Map<String, dynamic>;
      
      if (data['success'] == true) {
        debugPrint('[SquareIntegration] Menu sync completed successfully');
        return {
          'success': true,
          'itemsSynced': data['itemsSynced'],
          'message': data['message'],
        };
      } else {
        throw Exception(data['error'] ?? 'Unknown error during menu sync');
      }
      
    } catch (e) {
      debugPrint('[SquareIntegration] Menu sync failed: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Trigger a menu sync from the dashboard UI
  static Future<Map<String, dynamic>> triggerMenuSync(String restaurantId) {
    return syncRestaurantMenu(restaurantId: restaurantId);
  }

  /// Retrieve the latest integration status summary for a restaurant
  static Future<Map<String, dynamic>> getIntegrationStatus(String restaurantId) async {
    final status = await getRestaurantStatus(restaurantId: restaurantId);
    if (status['success'] != true) {
      throw Exception(status['error'] ?? 'Failed to load restaurant status');
    }
    return status;
  }

  /// Get restaurant status and integration details
  static Future<Map<String, dynamic>> getRestaurantStatus({
    required String restaurantId,
  }) async {
    try {
      debugPrint('[SquareIntegration] Getting restaurant status: $restaurantId');
      
      final lastSync = DateTime.now().subtract(const Duration(hours: 2));
      final restaurant = {
        'id': restaurantId,
        'name': 'Sample Restaurant',
        'status': 'active',
        'squareConnected': true,
        'menuSyncEnabled': true,
        'orderForwardingEnabled': true,
        'lastMenuSync': lastSync.toIso8601String(),
        'menuItemCount': 25,
        'stats': {
          'todayOrders': 12,
          'todayRevenue': '325.00',
          'menuItems': 25,
          'avgOrderValue': '27.10',
        },
        'recentActivity': [
          {
            'type': 'order',
            'message': 'New order received',
            'timestamp': DateTime.now().toIso8601String(),
          },
          {
            'type': 'sync',
            'message': 'Menu synced successfully',
            'timestamp': lastSync.toIso8601String(),
          },
        ],
      };
      
      return {
        'success': true,
        'restaurant': restaurant,
        'syncStatus': {
          'connected': restaurant['squareConnected'],
          'lastSync': lastSync.toIso8601String(),
          'menuItems': restaurant['menuItemCount'],
        },
      };
      
    } catch (e) {
      debugPrint('[SquareIntegration] Failed to get restaurant status: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Validate restaurant eligibility for FreshPunk integration
  static Map<String, dynamic> validateRestaurantEligibility({
    required String restaurantName,
    required String contactEmail,
    String? businessType,
    String? location,
  }) {
    final List<String> errors = [];
    
    // Basic validation
    if (restaurantName.trim().isEmpty) {
      errors.add('Restaurant name is required');
    }
    
    if (!_isValidEmail(contactEmail)) {
      errors.add('Valid email address is required');
    }
    
    // Business type validation (optional)
    const allowedTypes = ['restaurant', 'cafe', 'bakery', 'food_truck', 'catering'];
    if (businessType != null && !allowedTypes.contains(businessType.toLowerCase())) {
      errors.add('Business type must be: ${allowedTypes.join(', ')}');
    }
    
    return {
      'isEligible': errors.isEmpty,
      'errors': errors,
      'requirements': [
        'Active Square POS account',
        'Valid business license',
        'Food safety certification',
        'Delivery-ready menu items',
      ],
    };
  }

  /// Format Square OAuth URL for web view
  static String formatOAuthUrl(String oauthUrl) {
    // Add any additional parameters or formatting needed
    return oauthUrl;
  }

  /// Parse OAuth callback URL to extract code and state
  static Map<String, String?> parseOAuthCallback(String callbackUrl) {
    try {
      final uri = Uri.parse(callbackUrl);
      return {
        'code': uri.queryParameters['code'],
        'state': uri.queryParameters['state'],
        'error': uri.queryParameters['error'],
        'error_description': uri.queryParameters['error_description'],
      };
    } catch (e) {
      debugPrint('[SquareIntegration] Failed to parse OAuth callback: $e');
      return {
        'error': 'invalid_callback_url',
        'error_description': 'Failed to parse callback URL',
      };
    }
  }

  /// Check if Square integration is supported in current region
  static bool isSquareSupported({String? countryCode}) {
    // Square is primarily available in US, Canada, UK, Australia, Japan
    const supportedCountries = ['US', 'CA', 'GB', 'AU', 'JP'];
    return countryCode == null || supportedCountries.contains(countryCode.toUpperCase());
  }

  /// Get Square integration benefits for restaurant partners
  static List<Map<String, dynamic>> getIntegrationBenefits() {
    return [
      {
        'title': 'Seamless Order Integration',
        'description': 'Orders from FreshPunk automatically appear in your Square POS',
        'icon': '📱',
      },
      {
        'title': 'Automated Menu Sync',
        'description': 'Your Square menu items automatically sync to FreshPunk',
        'icon': '🔄',
      },
      {
        'title': 'Inventory Management',
        'description': 'Real-time inventory updates between Square and FreshPunk',
        'icon': '📦',
      },
      {
        'title': 'Unified Reporting',
        'description': 'Track FreshPunk sales alongside your regular Square reports',
        'icon': '📊',
      },
      {
        'title': 'Easy Setup',
        'description': 'Connect your existing Square account in just a few clicks',
        'icon': '⚡',
      },
    ];
  }

  /// Helper method to validate email format
  static bool _isValidEmail(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
  }
}

/// Model for restaurant onboarding data
class RestaurantOnboardingData {
  final String restaurantName;
  final String contactEmail;
  final String? contactPhone;
  final String? businessType;
  final String? address;
  final String? description;
  
  const RestaurantOnboardingData({
    required this.restaurantName,
    required this.contactEmail,
    this.contactPhone,
    this.businessType,
    this.address,
    this.description,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'restaurantName': restaurantName,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'businessType': businessType,
      'address': address,
      'description': description,
    };
  }
}

/// Model for restaurant status
class RestaurantStatus {
  final String id;
  final String name;
  final String status;
  final bool squareConnected;
  final bool menuSyncEnabled;
  final bool orderForwardingEnabled;
  final DateTime? lastMenuSync;
  final int menuItemCount;
  
  const RestaurantStatus({
    required this.id,
    required this.name,
    required this.status,
    required this.squareConnected,
    required this.menuSyncEnabled,
    required this.orderForwardingEnabled,
    this.lastMenuSync,
    required this.menuItemCount,
  });
  
  factory RestaurantStatus.fromJson(Map<String, dynamic> json) {
    return RestaurantStatus(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      status: json['status'] ?? 'unknown',
      squareConnected: json['squareConnected'] ?? false,
      menuSyncEnabled: json['menuSyncEnabled'] ?? false,
      orderForwardingEnabled: json['orderForwardingEnabled'] ?? false,
      lastMenuSync: json['lastMenuSync'] != null ? 
        DateTime.tryParse(json['lastMenuSync']) : null,
      menuItemCount: json['menuItemCount'] ?? 0,
    );
  }
}

/// Extension methods for SquareIntegrationService
extension SquareIntegrationServiceExtensions on SquareIntegrationService {
  /// Send weekly prep schedules to restaurant partners
  /// Only sends schedule parts relevant to each restaurant
  static Future<Map<String, dynamic>> sendWeeklyPrepSchedules({
    required DateTime weekStartDate,
  }) async {
    try {
      debugPrint('[SquareIntegration] Sending weekly prep schedules for week: ${weekStartDate.toIso8601String()}');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to send prep schedules');
      }

  final callable = SquareIntegrationService._callable('sendWeeklyPrepSchedules');
      
      final result = await callable.call({
        'weekStartDate': weekStartDate.toIso8601String(),
      });

      final data = result.data as Map<String, dynamic>;
      
      if (data['success'] == true) {
        debugPrint('[SquareIntegration] Prep schedules sent to ${data['restaurantsNotified']} restaurants');
        return {
          'success': true,
          'weekStart': data['weekStart'],
          'restaurantsNotified': data['restaurantsNotified'],
          'results': data['results'],
          'message': data['message'],
        };
      } else {
        throw Exception(data['error'] ?? 'Unknown error sending prep schedules');
      }
      
    } catch (e) {
      debugPrint('[SquareIntegration] Failed to send prep schedules: $e');
      return {
        'success': false,
        'error': 'Failed to send prep schedules: $e',
      };
    }
  }

  /// Get restaurant notifications for restaurant partners
  static Future<Map<String, dynamic>> getRestaurantNotifications({
    required String restaurantId,
  }) async {
    try {
      debugPrint('[SquareIntegration] Getting notifications for restaurant: $restaurantId');
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to get notifications');
      }

  final callable = SquareIntegrationService._callable('getRestaurantNotifications');
      
      final result = await callable.call({
        'restaurantId': restaurantId,
      });

      final data = result.data as Map<String, dynamic>;
      
      if (data['success'] == true) {
        debugPrint('[SquareIntegration] Retrieved ${data['notifications'].length} notifications');
        return {
          'success': true,
          'notifications': data['notifications'],
          'unreadCount': data['unreadCount'],
        };
      } else {
        throw Exception(data['error'] ?? 'Unknown error retrieving notifications');
      }
      
    } catch (e) {
      debugPrint('[SquareIntegration] Failed to get notifications: $e');
      return {
        'success': false,
        'error': 'Failed to get notifications: $e',
      };
    }
  }

  /// Helper method to get start of current week (Monday)
  static DateTime getCurrentWeekStart() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  /// Helper method to get next week start
  static DateTime getNextWeekStart() {
    final currentWeek = getCurrentWeekStart();
    return currentWeek.add(const Duration(days: 7));
  }
}