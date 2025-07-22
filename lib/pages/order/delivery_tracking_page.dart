import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveryTrackingPage extends StatefulWidget {
  const DeliveryTrackingPage({super.key});

  @override
  _DeliveryTrackingPageState createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends State<DeliveryTrackingPage> {
  late GoogleMapController _mapController;
  LatLng _currentLocation = LatLng(37.7749, -122.4194); // Default to San Francisco
  String _status = "preparing";

  @override
  void initState() {
    super.initState();
    _listenToDeliveryUpdates();
  }

  void _listenToDeliveryUpdates() {
    final orderId = "exampleOrderId"; // Replace with actual order ID
    FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        setState(() {
          _currentLocation = LatLng(
            data['location']['latitude'],
            data['location']['longitude'],
          );
          _status = data['status'];
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Delivery Tracking'),
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _currentLocation,
                zoom: 14.0,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              markers: {
                Marker(
                  markerId: MarkerId('deliveryLocation'),
                  position: _currentLocation,
                ),
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Status: $_status', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}
