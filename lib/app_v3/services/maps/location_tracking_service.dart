import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

/// Comprehensive location tracking service with support for:
/// - Runtime permission requests
/// - iOS 14+ precise location
/// - iOS 14+ App Tracking Transparency
/// - Android background location
class LocationTrackingService {
  static final LocationTrackingService _instance = LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  bool _isInitialized = false;
  Position? _lastKnownPosition;

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Request all necessary location permissions based on platform
  Future<LocationPermissionStatus> requestLocationPermissions({
    bool requestBackground = false,
  }) async {
    try {
      // Check if location service is enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationTracking] Location services are disabled');
        return LocationPermissionStatus.serviceDisabled;
      }

      // Request basic location permission
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationTracking] Location permission denied');
          return LocationPermissionStatus.denied;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationTracking] Location permission denied forever');
        return LocationPermissionStatus.deniedForever;
      }

      // iOS-specific: Request App Tracking Transparency (iOS 14+)
      if (Platform.isIOS) {
        final trackingStatus = await Permission.appTrackingTransparency.status;
        if (trackingStatus.isDenied) {
          final result = await Permission.appTrackingTransparency.request();
          debugPrint('[LocationTracking] iOS App Tracking Transparency: ${result.name}');
        }
      }

      // Android-specific: Request background location if needed (Android 10+)
      if (Platform.isAndroid && requestBackground) {
        final bgLocationStatus = await Permission.locationAlways.status;
        if (bgLocationStatus.isDenied) {
          final result = await Permission.locationAlways.request();
          debugPrint('[LocationTracking] Android background location: ${result.name}');
          
          if (result.isDenied || result.isPermanentlyDenied) {
            // Still have foreground permission, but no background
            return LocationPermissionStatus.grantedForegroundOnly;
          }
        }
      }

      _isInitialized = true;
      debugPrint('[LocationTracking] Location permissions granted');
      
      return requestBackground && Platform.isAndroid
          ? LocationPermissionStatus.grantedWithBackground
          : LocationPermissionStatus.granted;
          
    } catch (e) {
      debugPrint('[LocationTracking] Error requesting permissions: $e');
      return LocationPermissionStatus.error;
    }
  }

  /// Get current position with high accuracy
  Future<Position?> getCurrentPosition() async {
    try {
      if (!_isInitialized) {
        final permissionStatus = await requestLocationPermissions();
        if (permissionStatus != LocationPermissionStatus.granted &&
            permissionStatus != LocationPermissionStatus.grantedWithBackground &&
            permissionStatus != LocationPermissionStatus.grantedForegroundOnly) {
          return null;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        ),
      );

      _lastKnownPosition = position;
      return position;
    } catch (e) {
      debugPrint('[LocationTracking] Error getting position: $e');
      return _lastKnownPosition;
    }
  }

  /// Get last known position without requesting new location
  Position? get lastKnownPosition => _lastKnownPosition;

  /// Stream of position updates for real-time tracking
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }

  /// Check current permission status without requesting
  Future<LocationPermissionStatus> checkPermissionStatus() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionStatus.serviceDisabled;
      }

      final permission = await Geolocator.checkPermission();
      
      switch (permission) {
        case LocationPermission.denied:
          return LocationPermissionStatus.denied;
        case LocationPermission.deniedForever:
          return LocationPermissionStatus.deniedForever;
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          return LocationPermissionStatus.granted;
        default:
          return LocationPermissionStatus.denied;
      }
    } catch (e) {
      debugPrint('[LocationTracking] Error checking permission: $e');
      return LocationPermissionStatus.error;
    }
  }

  /// Open app settings for user to manually enable permissions
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }
}

/// Status enum for location permissions
enum LocationPermissionStatus {
  granted,
  grantedWithBackground,
  grantedForegroundOnly,
  denied,
  deniedForever,
  serviceDisabled,
  error,
}
