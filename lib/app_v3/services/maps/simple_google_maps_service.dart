import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Simple Google Maps API service - easier alternative to Places API
/// Uses basic geocoding and reverse geocoding for address validation
class SimpleGoogleMapsService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  
  // Google Maps API key - Geocoding API enabled
  // Get it from: https://console.cloud.google.com/apis/credentials
  // Only need to enable "Geocoding API"
  static const String _apiKey = 'AIzaSyCi_mKaxg-CRH3UJ5LVHGWTd7TUcl1H4qg';
  
  SimpleGoogleMapsService._();
  static final SimpleGoogleMapsService instance = SimpleGoogleMapsService._();

  /// Convert address to coordinates (geocoding)
  Future<AddressResult?> validateAddress(String address) async {
    if (address.trim().isEmpty) return null;
    
    try {
      final url = Uri.parse('$_baseUrl/geocode/json').replace(
        queryParameters: {
          'address': address,
          'key': _apiKey,
          'components': 'country:US', // Restrict to US
        },
      );

      final response = await http.get(url);
      
      debugPrint('[SimpleGoogleMaps] API Call to: $url');
      debugPrint('[SimpleGoogleMaps] Response status: ${response.statusCode}');
      debugPrint('[SimpleGoogleMaps] Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        debugPrint('[SimpleGoogleMaps] API Status: ${data['status']}');
        if (data['error_message'] != null) {
          debugPrint('[SimpleGoogleMaps] API Error: ${data['error_message']}');
        }
        
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          return AddressResult.fromGoogleMaps(result);
        } else if (data['status'] == 'REQUEST_DENIED') {
          debugPrint('[SimpleGoogleMaps] REQUEST DENIED - API key restrictions issue!');
          debugPrint('[SimpleGoogleMaps] Error: ${data['error_message']}');
          throw Exception('API key restricted: ${data['error_message']}');
        } else {
          debugPrint('[SimpleGoogleMaps] No results for: $address');
          return null;
        }
      } else {
        debugPrint('[SimpleGoogleMaps] HTTP Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[SimpleGoogleMaps] Exception: $e');
      return null;
    }
  }

  /// Get address suggestions (basic - just validates what user types)
  Future<List<String>> getAddressSuggestions(String query) async {
    // For simple implementation, just return common address patterns
    if (query.trim().isEmpty) return [];
    
    final suggestions = <String>[];
    final lower = query.toLowerCase();
    
    // Add common NYC addresses as examples
    if (lower.contains('broadway')) {
      suggestions.addAll([
        '123 Broadway, New York, NY 10001',
        '456 Broadway, New York, NY 10013',
        '789 Broadway, New York, NY 10003',
      ]);
    } else if (lower.contains('5th ave') || lower.contains('fifth ave')) {
      suggestions.addAll([
        '123 5th Avenue, New York, NY 10003',
        '456 5th Avenue, New York, NY 10016',
        '789 5th Avenue, New York, NY 10019',
      ]);
    } else if (lower.contains('madison')) {
      suggestions.addAll([
        '123 Madison Avenue, New York, NY 10016',
        '456 Madison Street, Brooklyn, NY 11221',
      ]);
    }
    
    // Filter suggestions that start with the query
    return suggestions
        .where((addr) => addr.toLowerCase().contains(lower))
        .take(5)
        .toList();
  }

  /// Calculate simple distance between two addresses
  Future<SimpleDistance?> calculateDistance({
    required String fromAddress,
    required String toAddress,
  }) async {
    try {
      // Get coordinates for both addresses
      final from = await validateAddress(fromAddress);
      final to = await validateAddress(toAddress);
      
      if (from == null || to == null) return null;
      
      // Use simple distance formula (haversine)
      final distance = _calculateDistanceInMiles(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );
      
      // Estimate delivery time (rough calculation)
      final estimatedMinutes = (distance * 3).round(); // ~3 minutes per mile in city
      
      return SimpleDistance(
        distanceMiles: distance,
        estimatedMinutes: estimatedMinutes,
        fromAddress: fromAddress,
        toAddress: toAddress,
      );
    } catch (e) {
      debugPrint('[SimpleGoogleMaps] Distance calculation error: $e');
      return null;
    }
  }

  /// Simple haversine distance calculation
  double _calculateDistanceInMiles(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusMiles = 3959.0;
    
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadiusMiles * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }
}

/// Simple address result from Google Maps Geocoding
class AddressResult {
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String street;
  final String city;
  final String state;
  final String zipCode;
  final bool isValid;

  AddressResult({
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.isValid,
  });

  factory AddressResult.fromGoogleMaps(Map<String, dynamic> result) {
    final components = <String, String>{};
    
    // Parse address components
    for (final component in result['address_components']) {
      final types = List<String>.from(component['types']);
      final longName = component['long_name'];
      final shortName = component['short_name'];
      
      for (final type in types) {
        switch (type) {
          case 'street_number':
            components['street_number'] = longName;
            break;
          case 'route':
            components['route'] = longName;
            break;
          case 'locality':
            components['city'] = longName;
            break;
          case 'administrative_area_level_1':
            components['state'] = shortName;
            break;
          case 'postal_code':
            components['zipCode'] = longName;
            break;
        }
      }
    }

    final location = result['geometry']['location'];
    final streetNumber = components['street_number'] ?? '';
    final route = components['route'] ?? '';
    final street = '$streetNumber $route'.trim();

    return AddressResult(
      formattedAddress: result['formatted_address'],
      latitude: location['lat'].toDouble(),
      longitude: location['lng'].toDouble(),
      street: street,
      city: components['city'] ?? '',
      state: components['state'] ?? '',
      zipCode: components['zipCode'] ?? '',
      isValid: true,
    );
  }

  /// Check if address is in delivery area (basic NYC check)
  bool get isInDeliveryArea {
    // Simple check for NYC area
    return (latitude >= 40.4774 && latitude <= 40.9176) &&
           (longitude >= -74.2591 && longitude <= -73.7004) &&
           (state.toLowerCase() == 'ny' || state.toLowerCase() == 'new york');
  }
}

/// Simple distance calculation result
class SimpleDistance {
  final double distanceMiles;
  final int estimatedMinutes;
  final String fromAddress;
  final String toAddress;

  SimpleDistance({
    required this.distanceMiles,
    required this.estimatedMinutes,
    required this.fromAddress,
    required this.toAddress,
  });

  String get formattedDistance => '${distanceMiles.toStringAsFixed(1)} miles';
  
  String get formattedTime {
    if (estimatedMinutes < 60) {
      return '$estimatedMinutes minutes';
    } else {
      final hours = estimatedMinutes ~/ 60;
      final minutes = estimatedMinutes % 60;
      return '${hours}h ${minutes}m';
    }
  }

  bool get isWithinDeliveryRange => distanceMiles <= 15.0; // 15 miles max
}
