import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RatingsPage extends StatefulWidget {
  const RatingsPage({super.key});

  @override
  _RatingsPageState createState() => _RatingsPageState();
}

class _RatingsPageState extends State<RatingsPage> {
  final TextEditingController _commentController = TextEditingController();
  double _rating = 3.0;

  Future<void> _submitRating() async {
    final userId = "exampleUserId"; // Replace with actual user ID
    final orderId = "exampleOrderId"; // Replace with actual order ID

    final ratingData = {
      'mealId': "meal123", // Replace with actual meal ID
      'stars': _rating,
      'comment': _commentController.text,
      'submittedAt': Timestamp.now(),
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('ratings')
        .doc(orderId)
        .set(ratingData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rating submitted successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rate Your Meal'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Rate your meal:', style: TextStyle(fontSize: 18)),
            Slider(
              value: _rating,
              min: 1.0,
              max: 5.0,
              divisions: 4,
              label: _rating.toString(),
              onChanged: (value) {
                setState(() {
                  _rating = value;
                });
              },
            ),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(labelText: 'Leave a comment'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitRating,
              child: Text('Submit Rating'),
            ),
          ],
        ),
      ),
    );
  }
}
