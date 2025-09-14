import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'google_places_service.dart';

/// Real-time location tracking service for delivery tracking
/// Handles driver location updates and customer tracking
class LocationTrackingService {
  LocationTrackingService._();
  static final LocationTrackingService instance = LocationTrackingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _updateTimer;
  
  /// Start tracking driver location (for driver app)
  Future<void> startDriverTracking({
    required String orderId,
    required String driverId,
    int updateIntervalSeconds = 10,
  }) async {
    try {
      // Check permissions
      final hasPermission = await _checkLocationPermissions();
      if (!hasPermission) {
        debugPrint('[LocationTracking] Location permission denied');
        return;
      }

      // Stop any existing tracking
      await stopDriverTracking();

      debugPrint('[LocationTracking] Starting driver tracking for order: $orderId');

      // Start location stream with high accuracy
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      ).listen(
        (position) => _updateDriverLocation(orderId, driverId, position),
        onError: (error) {
          debugPrint('[LocationTracking] Location stream error: $error');
        },
      );

      // Also update on a timer as backup
      _updateTimer = Timer.periodic(
        Duration(seconds: updateIntervalSeconds),
        (_) => _forceLocationUpdate(orderId, driverId),
      );

    } catch (e) {
      debugPrint('[LocationTracking] Error starting driver tracking: $e');
    }
  }

  /// Stop tracking driver location
  Future<void> stopDriverTracking() async {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    
    _updateTimer?.cancel();
    _updateTimer = null;
    
    debugPrint('[LocationTracking] Stopped driver tracking');
  }

  /// Update driver location in Firestore
  Future<void> _updateDriverLocation(
    String orderId, 
    String driverId, 
    Position position,
  ) async {
    try {
      final locationData = {
        'driverId': driverId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': FieldValue.serverTimestamp(),
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      };

      // Update driver location in real-time collection
      await _firestore
          .collection('delivery_tracking')
          .doc(orderId)
          .set({
        'currentLocation': locationData,
        'orderId': orderId,
        'status': 'tracking',
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Also update in location history for analytics
      await _firestore
          .collection('delivery_tracking')
          .doc(orderId)
          .collection('location_history')
          .add(locationData);

      debugPrint('[LocationTracking] Updated location for order: $orderId');
    } catch (e) {
      debugPrint('[LocationTracking] Error updating driver location: $e');
    }
  }

  /// Force location update (backup timer)
  Future<void> _forceLocationUpdate(String orderId, String driverId) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      
      await _updateDriverLocation(orderId, driverId, position);
    } catch (e) {
      debugPrint('[LocationTracking] Error in force location update: $e');
    }
  }

  /// Get real-time driver location stream (for customer tracking)
  Stream<DriverLocationUpdate?> watchDriverLocation(String orderId) {
    return _firestore
        .collection('delivery_tracking')
        .doc(orderId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      
      final data = snapshot.data();
      if (data == null || data['currentLocation'] == null) return null;
      
      final locationData = data['currentLocation'] as Map<String, dynamic>;
      
      return DriverLocationUpdate(
        orderId: orderId,
        driverId: locationData['driverId'],
        location: LatLng(
          locationData['latitude'],
          locationData['longitude'],
        ),
        accuracy: locationData['accuracy']?.toDouble() ?? 0.0,
        speed: locationData['speed']?.toDouble() ?? 0.0,
        heading: locationData['heading']?.toDouble() ?? 0.0,
        timestamp: locationData['timestamp'] as Timestamp?,
        lastUpdated: locationData['lastUpdated'] ?? 0,
      );
    });
  }

  /// Calculate ETA based on current driver location and destination
  Future<DeliveryETA?> calculateETA({
    required String orderId,
    required LatLng destination,
  }) async {
    try {
      // Get current driver location
      final trackingDoc = await _firestore
          .collection('delivery_tracking')
          .doc(orderId)
          .get();

      if (!trackingDoc.exists) return null;

      final data = trackingDoc.data();
      if (data == null || data['currentLocation'] == null) return null;

      final locationData = data['currentLocation'] as Map<String, dynamic>;
      final driverLocation = LatLng(
        locationData['latitude'],
        locationData['longitude'],
      );

      // Get delivery estimate using Google Maps API
      final estimate = await GooglePlacesService.instance.getDeliveryEstimate(
        from: driverLocation,
        to: destination,
      );

      if (estimate == null) return null;

      // Calculate ETA with buffer time
      final bufferMinutes = 5; // Add 5 minutes buffer
      final etaMinutes = estimate.estimatedMinutes + bufferMinutes;
      final etaTime = DateTime.now().add(Duration(minutes: etaMinutes));

      return DeliveryETA(
        orderId: orderId,
        estimatedArrival: etaTime,
        estimatedMinutes: etaMinutes,
        distance: estimate.distance,
        driverLocation: driverLocation,
        destination: destination,
        lastCalculated: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[LocationTracking] Error calculating ETA: $e');
      return null;
    }
  }

  /// Mark delivery as completed and stop tracking
  Future<void> markDeliveryCompleted(String orderId) async {
    try {
      await _firestore
          .collection('delivery_tracking')
          .doc(orderId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'lastUpdate': FieldValue.serverTimestamp(),
      });

      debugPrint('[LocationTracking] Marked delivery completed: $orderId');
    } catch (e) {
      debugPrint('[LocationTracking] Error marking delivery completed: $e');
    }
  }

  /// Get delivery route history for analytics
  Future<List<LatLng>> getDeliveryRoute(String orderId) async {
    try {
      final historyQuery = await _firestore
          .collection('delivery_tracking')
          .doc(orderId)
          .collection('location_history')
          .orderBy('timestamp')
          .get();

      return historyQuery.docs.map((doc) {
        final data = doc.data();
        return LatLng(data['latitude'], data['longitude']);
      }).toList();
    } catch (e) {
      debugPrint('[LocationTracking] Error getting delivery route: $e');
      return [];
    }
  }

  /// Check and request location permissions
  Future<bool> _checkLocationPermissions() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationTracking] Location services are disabled');
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationTracking] Location permission denied');
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationTracking] Location permission permanently denied');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[LocationTracking] Error checking permissions: $e');
      return false;
    }
  }

  /// Create geofence for delivery notifications
  Future<void> createDeliveryGeofence({
    required String orderId,
    required LatLng center,
    double radiusMeters = 100, // 100 meters default
  }) async {
    try {
      await _firestore
          .collection('delivery_geofences')
          .doc(orderId)
          .set({
        'orderId': orderId,
        'center': {
          'latitude': center.latitude,
          'longitude': center.longitude,
        },
        'radiusMeters': radiusMeters,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[LocationTracking] Created geofence for order: $orderId');
    } catch (e) {
      debugPrint('[LocationTracking] Error creating geofence: $e');
    }
  }

  /// Check if driver is within delivery geofence
  bool isWithinGeofence({
    required LatLng driverLocation,
    required LatLng geofenceCenter,
    required double radiusMeters,
  }) {
    final distance = Geolocator.distanceBetween(
      driverLocation.latitude,
      driverLocation.longitude,
      geofenceCenter.latitude,
      geofenceCenter.longitude,
    );
    
    return distance <= radiusMeters;
  }
}

/// Driver location update data
class DriverLocationUpdate {
  final String orderId;
  final String driverId;
  final LatLng location;
  final double accuracy;
  final double speed;
  final double heading;
  final Timestamp? timestamp;
  final int lastUpdated;

  DriverLocationUpdate({
    required this.orderId,
    required this.driverId,
    required this.location,
    required this.accuracy,
    required this.speed,
    required this.heading,
    this.timestamp,
    required this.lastUpdated,
  });

  /// Check if location data is recent (within 2 minutes)
  bool get isRecent {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastUpdated) < 120000; // 2 minutes in milliseconds
  }

  /// Get speed in mph
  double get speedMph => speed * 2.237; // Convert m/s to mph

  /// Get formatted speed
  String get formattedSpeed => '${speedMph.toStringAsFixed(1)} mph';
}

/// Delivery ETA calculation result
class DeliveryETA {
  final String orderId;
  final DateTime estimatedArrival;
  final int estimatedMinutes;
  final String distance;
  final LatLng driverLocation;
  final LatLng destination;
  final DateTime lastCalculated;

  DeliveryETA({
    required this.orderId,
    required this.estimatedArrival,
    required this.estimatedMinutes,
    required this.distance,
    required this.driverLocation,
    required this.destination,
    required this.lastCalculated,
  });

  /// Get formatted ETA time
  String get formattedETA {
    final hour = estimatedArrival.hour;
    final minute = estimatedArrival.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour}:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Get ETA relative to now
  String get relativeETA {
    if (estimatedMinutes < 1) return 'Arriving now';
    if (estimatedMinutes == 1) return 'Arriving in 1 minute';
    return 'Arriving in $estimatedMinutes minutes';
  }

  /// Check if ETA needs recalculation (older than 1 minute)
  bool get needsRecalculation {
    final now = DateTime.now();
    return now.difference(lastCalculated).inMinutes >= 1;
  }
}
