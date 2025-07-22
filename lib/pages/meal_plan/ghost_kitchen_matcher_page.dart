import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GhostKitchenMatcherPage extends StatefulWidget {
  const GhostKitchenMatcherPage({super.key});

  @override
  _GhostKitchenMatcherPageState createState() => _GhostKitchenMatcherPageState();
}

class _GhostKitchenMatcherPageState extends State<GhostKitchenMatcherPage> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _mealTimeController = TextEditingController();
  List<Map<String, dynamic>> _matchedKitchens = [];

  Future<void> _findKitchens() async {
    final address = _addressController.text;
    final mealTime = _mealTimeController.text;

    // Example query to Firestore (replace with actual logic)
    final snapshot = await FirebaseFirestore.instance
        .collection('kitchens')
        .where('deliveryZones', arrayContains: address)
        .where('operatingHours', arrayContains: mealTime)
        .get();

    setState(() {
      _matchedKitchens = snapshot.docs
          .map((doc) => doc.data())
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ghost Kitchen Matcher'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _addressController,
              decoration: InputDecoration(labelText: 'Delivery Address'),
            ),
            TextField(
              controller: _mealTimeController,
              decoration: InputDecoration(labelText: 'Preferred Meal Time'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _findKitchens,
              child: Text('Find Kitchens'),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _matchedKitchens.length,
                itemBuilder: (context, index) {
                  final kitchen = _matchedKitchens[index];
                  return Card(
                    margin: EdgeInsets.all(8.0),
                    child: ListTile(
                      title: Text(kitchen['name'] ?? 'Unknown Kitchen'),
                      subtitle: Text(kitchen['address'] ?? 'No Address'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
