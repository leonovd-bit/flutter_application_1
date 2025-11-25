import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/swipeable_page.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_theme_v3.dart';
import '../../services/maps/google_maps_test_service.dart';

class MapPageV3 extends StatefulWidget {
  const MapPageV3({super.key});

  @override
  State<MapPageV3> createState() => _MapPageV3State();
}

class _MapPageV3State extends State<MapPageV3> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _hasLocationPermission = false;
  
  // Use dynamic marker loading instead of storing all markers
  final Set<Marker> _markers = <Marker>{};

  // Default map center: Manhattan (Times Square)
  static const double _manhattanLat = 40.7589;
  static const double _manhattanLng = -73.9851;
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(_manhattanLat, _manhattanLng),
    zoom: 12.0,
  );

  @override
  void initState() {
    super.initState();
    GoogleMapsTestService.testMapsIntegration();
    _initializeMap();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    await _requestLocationPermission();
    if (_hasLocationPermission) {
      await _getCurrentLocation();
    }
    // If we still don't have a current location, pin the default center (Manhattan)
    if (!_hasLocationPermission || _currentPosition == null) {
      _markers.add(
        const Marker(
          markerId: MarkerId('default_center'),
          position: LatLng(_manhattanLat, _manhattanLng),
          infoWindow: InfoWindow(title: 'Manhattan'),
          icon: BitmapDescriptor.defaultMarker,
        ),
      );
    }

    _addPartnerKitchenMarkers();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _requestLocationPermission() async {
    final permission = await Permission.location.request();
    _hasLocationPermission = permission.isGranted || permission.isLimited;
    if (!_hasLocationPermission) {
      // Defer UI feedback until after first frame to avoid Scaffold context issues in initState
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final messenger = ScaffoldMessenger.maybeOf(context);
          messenger?.showSnackBar(
            const SnackBar(
              content: Text('Location permission denied. You can enable it in Settings to show your position.'),
            ),
          );
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (_currentPosition != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            infoWindow: const InfoWindow(title: 'Your Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  void _addPartnerKitchenMarkers() {
    // TODO: Replace lat/lng with the exact coordinates for the real partners.
    // If you can share the street addresses, I can geocode and lock these in.
    final partners = [
      {
        'id': 'partner_green_blend',
        'name': 'Green Blend',
        'address': '387 8th Ave, New York, NY 10001',
        'lat': 40.7489, // approx near Penn Station / 8th Ave
        'lng': -73.9952,
        'rating': 4.8,
        'prepTime': '15-20 min',
      },
      {
        'id': 'partner_sen_saigon',
        'name': 'Sen Saigon',
        'address': '150 E Broadway, New York, NY 10002',
        'lat': 40.7139, // approx Lower East Side (E Broadway)
        'lng': -73.9903,
        'rating': 4.7,
        'prepTime': '20-25 min',
      },
    ];

    for (final p in partners) {
      _markers.add(
        Marker(
          markerId: MarkerId(p['id'] as String),
          position: LatLng(p['lat'] as double, p['lng'] as double),
          infoWindow: InfoWindow(
            title: p['name'] as String,
            snippet: '${p['rating']} ⭐ • ${p['prepTime']}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          onTap: () => _showKitchenDetails(p),
        ),
      );
    }
  }

  void _showKitchenDetails(Map<String, dynamic> kitchen) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildKitchenDetailsSheet(kitchen),
    );
  }

  Widget _buildKitchenDetailsSheet(Map<String, dynamic> kitchen) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kitchen['name'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '${kitchen['rating']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.access_time, color: AppThemeV3.primaryGreen, size: 20),
                      const SizedBox(width: 4),
                      Text(kitchen['prepTime']),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.grey[600], size: 20),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          kitchen['address'],
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _getDirections(kitchen),
                          icon: const Icon(Icons.directions),
                          label: const Text('Get Directions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppThemeV3.primaryGreen,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _callKitchen(kitchen),
                          icon: const Icon(Icons.phone),
                          label: const Text('Call'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppThemeV3.primaryGreen,
                            side: const BorderSide(color: AppThemeV3.primaryGreen),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _getDirections(Map<String, dynamic> kitchen) {
    // Implementation for opening maps app with directions
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening directions to ${kitchen['name']}...'),
        backgroundColor: AppThemeV3.primaryGreen,
      ),
    );
  }

  void _callKitchen(Map<String, dynamic> kitchen) {
    // Implementation for calling the kitchen
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calling kitchen...'),
        backgroundColor: AppThemeV3.primaryGreen,
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    GoogleMapsTestService.logMapSuccess();
    
    // Move camera to user's location if available
    if (_currentPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        ),
      );
    }

    // After the map is ready, fit to all available markers (partners and/or default center)
    // Delay slightly to ensure the map has a size on web before fitting bounds
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 150));
      _fitToAllMarkers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SwipeablePage(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'FreshPunk Locations',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.my_location, color: AppThemeV3.primaryGreen),
            onPressed: _goToCurrentLocation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppThemeV3.primaryGreen),
              ),
            )
          : GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: _initialPosition,
              markers: _markers,
              myLocationEnabled: _hasLocationPermission,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              style: _mapStyle,
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNearestKitchen,
        backgroundColor: AppThemeV3.primaryGreen,
        icon: const Icon(Icons.restaurant, color: Colors.white),
        label: const Text(
          'Nearest Kitchen',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      ),
    );
  }

  void _goToCurrentLocation() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 15.0,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location not available'),
        ),
      );
    }
  }

  void _showNearestKitchen() {
    // Find and show the nearest kitchen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('FreshPunk Kitchen - Lower East Side is closest to you (0.8 miles)'),
        backgroundColor: AppThemeV3.primaryGreen,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _fitToAllMarkers() {
    final controller = _mapController;
    if (controller == null || _markers.isEmpty) return;

    double? minLat, maxLat, minLng, maxLng;
    for (final m in _markers) {
      final lat = m.position.latitude;
      final lng = m.position.longitude;
      minLat = (minLat == null) ? lat : (lat < minLat ? lat : minLat);
      maxLat = (maxLat == null) ? lat : (lat > maxLat ? lat : maxLat);
      minLng = (minLng == null) ? lng : (lng < minLng ? lng : minLng);
      maxLng = (maxLng == null) ? lng : (lng > maxLng ? lng : maxLng);
    }

    if (minLat == null || maxLat == null || minLng == null || maxLng == null) return;

    // If only one marker, zoom in to it
    if (minLat == maxLat && minLng == maxLng) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(minLat, minLng), zoom: 14),
        ),
      );
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  static const String _mapStyle = '''
  [
    {
      "featureType": "poi",
      "elementType": "labels",
      "stylers": [
        {
          "visibility": "off"
        }
      ]
    }
  ]
  ''';
}
