import 'package:flutter/material.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // Sample kitchen data for NYC
  final List<Map<String, dynamic>> _kitchens = [
    {
      'name': 'FreshPunk Kitchen - Manhattan',
      'address': '123 Broadway, New York, NY 10001',
      'lat': 40.7506,
      'lng': -73.9891,
    },
    {
      'name': 'FreshPunk Kitchen - Brooklyn',
      'address': '456 Atlantic Ave, Brooklyn, NY 11217',
      'lat': 40.6892,
      'lng': -73.9441,
    },
    {
      'name': 'FreshPunk Kitchen - Queens',
      'address': '789 Northern Blvd, Queens, NY 11372',
      'lat': 40.7589,
      'lng': -73.8743,
    },
    {
      'name': 'FreshPunk Kitchen - Upper East Side',
      'address': '321 Lexington Ave, New York, NY 10016',
      'lat': 40.7413,
      'lng': -73.9749,
    },
    {
      'name': 'FreshPunk Kitchen - Williamsburg',
      'address': '654 Bedford Ave, Brooklyn, NY 11249',
      'lat': 40.7193,
      'lng': -73.9573,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Kitchen Locations',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Map placeholder with kitchen markers
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Stack(
                  children: [
                    // Map background
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.map,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Interactive Map View',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kitchen locations in NYC',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Kitchen markers positioned around the map
                    Positioned(
                      top: 60,
                      left: 80,
                      child: _buildKitchenMarker(_kitchens[0]),
                    ),
                    Positioned(
                      top: 120,
                      right: 60,
                      child: _buildKitchenMarker(_kitchens[1]),
                    ),
                    Positioned(
                      bottom: 80,
                      left: 120,
                      child: _buildKitchenMarker(_kitchens[2]),
                    ),
                    Positioned(
                      top: 90,
                      right: 120,
                      child: _buildKitchenMarker(_kitchens[3]),
                    ),
                    Positioned(
                      bottom: 120,
                      right: 80,
                      child: _buildKitchenMarker(_kitchens[4]),
                    ),
                    
                    // User location marker (center)
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue,
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.my_location,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Kitchen list
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nearby Kitchens',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _kitchens.length,
                        itemBuilder: (context, index) {
                          final kitchen = _kitchens[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                // Kitchen icon
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2D5A2D),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.restaurant,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                                
                                const SizedBox(width: 16),
                                
                                // Kitchen info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        kitchen['name'],
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        kitchen['address'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Distance indicator
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${(index + 1) * 0.3 + 0.5} mi',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKitchenMarker(Map<String, dynamic> kitchen) {
    return GestureDetector(
      onTap: () {
        // Show kitchen name on tap
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kitchen['name']),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF2D5A2D),
          ),
        );
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: const BoxDecoration(
          color: Color(0xFF2D5A2D),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.restaurant,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}
