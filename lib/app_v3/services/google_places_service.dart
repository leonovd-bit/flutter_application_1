import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

/// Service for Google Places API integration
/// Handles address validation, autocomplete, and geocoding
class GooglePlacesService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  
  // TODO: Add your Google Places API key here
  // Get it from: https://console.cloud.google.com/apis/credentials
  static const String _apiKey = 'YOUR_GOOGLE_PLACES_API_KEY_HERE';
  
  GooglePlacesService._();
  static final GooglePlacesService instance = GooglePlacesService._();

  /// Get address suggestions for autocomplete
  Future<List<PlacesSuggestion>> getAddressSuggestions(
    String query, {
    String? sessionToken,
    LatLng? location,
    int radius = 50000, // 50km default
  }) async {
    if (query.trim().isEmpty) return [];
    
    try {
      final url = Uri.parse('$_baseUrl/place/autocomplete/json').replace(
        queryParameters: {
          'input': query,
          'key': _apiKey,
          'types': 'address',
          'components': 'country:us', // Restrict to US addresses
          if (sessionToken != null) 'sessiontoken': sessionToken,
          if (location != null) 'location': '${location.latitude},${location.longitude}',
          if (location != null) 'radius': radius.toString(),
        },
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          return predictions
              .map((p) => PlacesSuggestion.fromJson(p))
              .toList();
        } else {
          debugPrint('[GooglePlaces] API Error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}');
          return [];
        }
      } else {
        debugPrint('[GooglePlaces] HTTP Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('[GooglePlaces] Exception in getAddressSuggestions: $e');
      return [];
    }
  }

  /// Get detailed place information by place ID
  Future<PlaceDetails?> getPlaceDetails(
    String placeId, {
    String? sessionToken,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/place/details/json').replace(
        queryParameters: {
          'place_id': placeId,
          'key': _apiKey,
          'fields': 'formatted_address,address_components,geometry,name',
          if (sessionToken != null) 'sessiontoken': sessionToken,
        },
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data['result']);
        } else {
          debugPrint('[GooglePlaces] Place Details Error: ${data['status']}');
          return null;
        }
      } else {
        debugPrint('[GooglePlaces] HTTP Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('[GooglePlaces] Exception in getPlaceDetails: $e');
      return null;
    }
  }

  /// Validate and standardize an address
  Future<AddressValidationResult> validateAddress(String address) async {
    try {
      // First, try to get suggestions
      final suggestions = await getAddressSuggestions(address);
      
      if (suggestions.isEmpty) {
        return AddressValidationResult(
          isValid: false,
          originalAddress: address,
          error: 'No matching addresses found',
        );
      }

      // Get details for the best match
      final bestMatch = suggestions.first;
      final details = await getPlaceDetails(bestMatch.placeId);
      
      if (details == null) {
        return AddressValidationResult(
          isValid: false,
          originalAddress: address,
          error: 'Could not validate address details',
        );
      }

      return AddressValidationResult(
        isValid: true,
        originalAddress: address,
        standardizedAddress: details.formattedAddress,
        placeDetails: details,
        confidence: _calculateConfidence(address, details.formattedAddress),
      );
    } catch (e) {
      return AddressValidationResult(
        isValid: false,
        originalAddress: address,
        error: 'Validation failed: $e',
      );
    }
  }

  /// Calculate delivery distance and time estimate
  Future<DeliveryEstimate?> getDeliveryEstimate({
    required LatLng from,
    required LatLng to,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/distancematrix/json').replace(
        queryParameters: {
          'origins': '${from.latitude},${from.longitude}',
          'destinations': '${to.latitude},${to.longitude}',
          'key': _apiKey,
          'units': 'imperial',
          'mode': 'driving',
          'traffic_model': 'best_guess',
          'departure_time': 'now',
        },
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final element = data['rows'][0]['elements'][0];
          
          if (element['status'] == 'OK') {
            return DeliveryEstimate(
              distance: element['distance']['text'],
              distanceValue: element['distance']['value'],
              duration: element['duration']['text'],
              durationValue: element['duration']['value'],
              durationInTraffic: element['duration_in_traffic']?['text'],
              durationInTrafficValue: element['duration_in_traffic']?['value'],
            );
          }
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('[GooglePlaces] Exception in getDeliveryEstimate: $e');
      return null;
    }
  }

  /// Get current user location with permission handling
  Future<LatLng?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[GooglePlaces] Location services are disabled');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[GooglePlaces] Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[GooglePlaces] Location permission permanently denied');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('[GooglePlaces] Exception in getCurrentLocation: $e');
      return null;
    }
  }

  /// Calculate confidence score for address matching
  double _calculateConfidence(String original, String standardized) {
    if (original.toLowerCase() == standardized.toLowerCase()) return 1.0;
    
    final originalWords = original.toLowerCase().split(' ');
    final standardizedWords = standardized.toLowerCase().split(' ');
    
    int matches = 0;
    for (final word in originalWords) {
      if (standardizedWords.any((w) => w.contains(word) || word.contains(w))) {
        matches++;
      }
    }
    
    return matches / originalWords.length;
  }
}

/// Represents a place suggestion from autocomplete
class PlacesSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;
  final List<String> types;

  PlacesSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    required this.types,
  });

  factory PlacesSuggestion.fromJson(Map<String, dynamic> json) {
    return PlacesSuggestion(
      placeId: json['place_id'],
      description: json['description'],
      mainText: json['structured_formatting']['main_text'],
      secondaryText: json['structured_formatting']['secondary_text'] ?? '',
      types: List<String>.from(json['types']),
    );
  }
}

/// Detailed place information
class PlaceDetails {
  final String placeId;
  final String formattedAddress;
  final String name;
  final LatLng location;
  final Map<String, String> addressComponents;

  PlaceDetails({
    required this.placeId,
    required this.formattedAddress,
    required this.name,
    required this.location,
    required this.addressComponents,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry']['location'];
    final components = <String, String>{};
    
    for (final component in json['address_components']) {
      final types = List<String>.from(component['types']);
      final longName = component['long_name'];
      final shortName = component['short_name'];
      
      for (final type in types) {
        switch (type) {
          case 'street_number':
            components['street_number'] = longName;
            break;
          case 'route':
            components['street'] = longName;
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
          case 'country':
            components['country'] = shortName;
            break;
        }
      }
    }

    return PlaceDetails(
      placeId: json['place_id'] ?? '',
      formattedAddress: json['formatted_address'],
      name: json['name'] ?? '',
      location: LatLng(geometry['lat'], geometry['lng']),
      addressComponents: components,
    );
  }

  /// Get street address (number + street)
  String get streetAddress {
    final number = addressComponents['street_number'] ?? '';
    final street = addressComponents['street'] ?? '';
    return '$number $street'.trim();
  }

  /// Get city
  String get city => addressComponents['city'] ?? '';

  /// Get state
  String get state => addressComponents['state'] ?? '';

  /// Get zip code
  String get zipCode => addressComponents['zipCode'] ?? '';
}

/// Result of address validation
class AddressValidationResult {
  final bool isValid;
  final String originalAddress;
  final String? standardizedAddress;
  final PlaceDetails? placeDetails;
  final double? confidence;
  final String? error;

  AddressValidationResult({
    required this.isValid,
    required this.originalAddress,
    this.standardizedAddress,
    this.placeDetails,
    this.confidence,
    this.error,
  });
}

/// Delivery distance and time estimate
class DeliveryEstimate {
  final String distance;
  final int distanceValue; // in meters
  final String duration;
  final int durationValue; // in seconds
  final String? durationInTraffic;
  final int? durationInTrafficValue;

  DeliveryEstimate({
    required this.distance,
    required this.distanceValue,
    required this.duration,
    required this.durationValue,
    this.durationInTraffic,
    this.durationInTrafficValue,
  });

  /// Get estimated delivery time in minutes
  int get estimatedMinutes => (durationInTrafficValue ?? durationValue) ~/ 60;

  /// Check if delivery is within reasonable distance (e.g., 20 miles)
  bool get isWithinDeliveryRange => distanceValue <= 32186; // 20 miles in meters
}

/// Simple LatLng class if you don't want to import google_maps_flutter everywhere
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LatLng &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}
