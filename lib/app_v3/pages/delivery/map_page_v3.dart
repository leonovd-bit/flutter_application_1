import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_theme_v3.dart';
import '../../services/maps/google_maps_test_service.dart';
import '../../services/maps/location_tracking_service.dart';

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
    debugPrint('[MapPageV3] initState - starting map initialization');
    _initializeMap();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    debugPrint('[MapPageV3] _initializeMap started');
    await _requestLocationPermission();
    debugPrint('[MapPageV3] Location permission: $_hasLocationPermission');
    
    if (_hasLocationPermission) {
      await _getCurrentLocation();
      debugPrint('[MapPageV3] Current position: $_currentPosition');
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
      debugPrint('[MapPageV3] Added default center marker');
    }

    _addPartnerKitchenMarkers();
    debugPrint('[MapPageV3] Total markers: ${_markers.length}');
    
    setState(() {
      _isLoading = false;
    });
    debugPrint('[MapPageV3] Map initialization complete, loading = false');
  }

  Future<void> _requestLocationPermission() async {
    final locationService = LocationTrackingService();
    final status = await locationService.requestLocationPermissions(
      requestBackground: false, // Only need foreground for map view
    );
    
    _hasLocationPermission = status == LocationPermissionStatus.granted ||
        status == LocationPermissionStatus.grantedWithBackground ||
        status == LocationPermissionStatus.grantedForegroundOnly;
    
    if (!_hasLocationPermission) {
      // Defer UI feedback until after first frame to avoid Scaffold context issues in initState
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final messenger = ScaffoldMessenger.maybeOf(context);
          
          String message = 'Location permission denied. You can enable it in Settings to show your position.';
          bool showSettings = false;
          
          if (status == LocationPermissionStatus.deniedForever) {
            message = 'Location permission permanently denied. Please enable it in Settings.';
            showSettings = true;
          } else if (status == LocationPermissionStatus.serviceDisabled) {
            message = 'Location services are disabled. Please enable them in Settings.';
            showSettings = true;
          }
          
          messenger?.showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 5),
              action: showSettings
                  ? SnackBarAction(
                      label: 'Settings',
                      onPressed: () => locationService.openAppSettings(),
                    )
                  : null,
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
    final partners = [
      {
        'id': 'partner_green_blend_1',
        'name': 'Green Blend',
        'address': '387 8th Ave, New York, NY 10001',
        'lat': 40.7489,
        'lng': -73.9952,
        'rating': 4.5,
        'prepTime': '35-55 mins',
        'images': [
          'assets/images/restaurants/WhatsApp Image 2025-12-10 at 20.09.01.jpeg',
          'assets/images/restaurants/WhatsApp Image 2025-12-10 at 20.09.02.jpeg',
          'assets/images/restaurants/WhatsApp Image 2025-12-10 at 20.09.03.jpeg',
          'assets/images/restaurants/WhatsApp Image 2025-12-10 at 20.09.04.jpeg',
          'assets/images/restaurants/WhatsApp Image 2025-12-10 at 20.09.05.jpeg',
        ],
      },
      {
        'id': 'partner_green_blend_2',
        'name': 'Green Blend',
        'address': '70 7th Ave, New York, NY 10011',
        'lat': 40.7370,
        'lng': -73.9990,
        'rating': 4.5,
        'prepTime': '35-55 mins',
        'images': [
          'assets/images/restaurants/WhatsApp Image 2025-12-10 at 20.09.01.jpeg',
          'assets/images/restaurants/WhatsApp Image 2025-12-10 at 20.09.02.jpeg',
          'assets/images/restaurants/WhatsApp Image 2025-12-10 at 20.09.03.jpeg',
          'assets/images/restaurants/WhatsApp Image 2025-12-10 at 20.09.04.jpeg',
          'assets/images/restaurants/WhatsApp Image 2025-12-10 at 20.09.05.jpeg',
        ],
      },
      {
        'id': 'partner_sen_saigon',
        'name': 'Sen Saigon',
        'address': '150 E Broadway, New York, NY 10002',
        'lat': 40.7139,
        'lng': -73.9903,
        'rating': 4.8,
        'prepTime': '35-55 mins',
        'images': [
          'assets/images/restaurants/WhatsApp Image 2025-12-10 at 20.11.52.jpeg',
          'assets/images/restaurants/WhatsApp Image 2025-12-10 at 20.11.53.jpeg',
          'assets/images/restaurants/WhatsApp Image 2025-12-10 at 20.11.54.jpeg',
          'assets/images/restaurants/WhatsApp Image 2025-12-10 at 20.11.55.jpeg',
          'assets/images/restaurants/WhatsApp Image 2025-12-10 at 20.11.56.jpeg',
        ],
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
      height: MediaQuery.of(context).size.height * 0.5,
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
          // Restaurant Image Gallery
          if (kitchen['images'] != null && kitchen['images'].isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              height: 150,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: kitchen['images'].length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 200,
                    margin: EdgeInsets.only(right: index < kitchen['images'].length - 1 ? 12 : 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        kitchen['images'][index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.restaurant, size: 60, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    debugPrint('[MapPageV3] onMapCreated callback triggered');
    _mapController = controller;
    GoogleMapsTestService.logMapSuccess();
    
    // Move camera to user's location if available
    if (_currentPosition != null) {
      debugPrint('[MapPageV3] Moving camera to user location');
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
      debugPrint('[MapPageV3] Fitting to markers');
      _fitToAllMarkers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Victus Locations',
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
            zoomControlsEnabled: true,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            mapToolbarEnabled: false,
            onTap: (position) {
              debugPrint('[MapPageV3] Map tapped at: $position');
            },
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
