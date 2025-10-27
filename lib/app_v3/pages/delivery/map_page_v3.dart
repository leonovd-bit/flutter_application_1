import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
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
  
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(40.7589, -73.9851), // Times Square, NYC
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
    _addGhostKitchenMarkers();
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

  void _addGhostKitchenMarkers() {
    final ghostKitchens = [
      {
        'id': 'kitchen_1',
        'name': 'FreshPunk Kitchen - Manhattan',
        'address': '123 Broadway, New York, NY 10001',
        'lat': 40.7505,
        'lng': -73.9934,
        'rating': 4.8,
        'prepTime': '15-20 min',
      },
      {
        'id': 'kitchen_2',
        'name': 'FreshPunk Kitchen - Brooklyn',
        'address': '456 Atlantic Ave, Brooklyn, NY 11217',
        'lat': 40.6892,
        'lng': -73.9442,
        'rating': 4.7,
        'prepTime': '20-25 min',
      },
      {
        'id': 'kitchen_3',
        'name': 'FreshPunk Kitchen - Queens',
        'address': '789 Northern Blvd, Queens, NY 11372',
        'lat': 40.7282,
        'lng': -73.8448,
        'rating': 4.9,
        'prepTime': '18-22 min',
      },
      {
        'id': 'kitchen_4',
        'name': 'FreshPunk Kitchen - Lower East Side',
        'address': '321 Delancey St, New York, NY 10002',
        'lat': 40.7184,
        'lng': -73.9857,
        'rating': 4.6,
        'prepTime': '12-18 min',
      },
    ];

    for (final kitchen in ghostKitchens) {
      _markers.add(
        Marker(
          markerId: MarkerId(kitchen['id'] as String),
          position: LatLng(kitchen['lat'] as double, kitchen['lng'] as double),
          infoWindow: InfoWindow(
            title: kitchen['name'] as String,
            snippet: '${kitchen['rating']} ⭐ • ${kitchen['prepTime']}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          onTap: () => _showKitchenDetails(kitchen),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
