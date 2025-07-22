import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderConfirmationPage extends StatefulWidget {
  const OrderConfirmationPage({super.key});

  @override
  _OrderConfirmationPageState createState() => _OrderConfirmationPageState();
}

class _OrderConfirmationPageState extends State<OrderConfirmationPage> {
  final TextEditingController _deliveryInstructionsController = TextEditingController();
  final TextEditingController _deliveryAddressController = TextEditingController();
  bool _reminderConfirmed = false;

  Future<void> _confirmOrder() async {
    final userId = "exampleUserId"; // Replace with actual user ID
    final orderData = {
      'deliveryInstructions': _deliveryInstructionsController.text,
      'deliveryAddress': _deliveryAddressController.text,
      'reminderConfirmed': _reminderConfirmed,
      'scheduledDelivery': Timestamp.now(), // Replace with actual timestamp
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('upcomingOrder')
        .doc('orderDetails')
        .set(orderData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order confirmed successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order Confirmation'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _deliveryAddressController,
              decoration: InputDecoration(labelText: 'Delivery Address'),
            ),
            TextField(
              controller: _deliveryInstructionsController,
              decoration: InputDecoration(labelText: 'Delivery Instructions'),
            ),
            SwitchListTile(
              title: Text('Enable Reminder'),
              value: _reminderConfirmed,
              onChanged: (value) {
                setState(() {
                  _reminderConfirmed = value;
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _confirmOrder,
              child: Text('Confirm Order'),
            ),
          ],
        ),
      ),
    );
  }
}
