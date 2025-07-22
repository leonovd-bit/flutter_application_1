import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  _SubscriptionPageState createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final String userId = "exampleUserId"; // Replace with actual user ID
  String _selectedPlan = "freshpunk-basic";

  Future<void> _updateSubscription() async {
    final subscriptionData = {
      'planId': _selectedPlan,
      'nextBillingDate': Timestamp.now(), // Replace with actual billing date
      'isActive': true,
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('subscription')
        .doc('details')
        .set(subscriptionData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Subscription updated successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Subscription & Payment'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButton<String>(
              value: _selectedPlan,
              items: [
                DropdownMenuItem(
                  value: "freshpunk-basic",
                  child: Text("FreshPunk Basic - \$10/month"),
                ),
                DropdownMenuItem(
                  value: "freshpunk-plus",
                  child: Text("FreshPunk Plus - \$20/month"),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedPlan = value!;
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateSubscription,
              child: Text('Update Subscription'),
            ),
          ],
        ),
      ),
    );
  }
}
