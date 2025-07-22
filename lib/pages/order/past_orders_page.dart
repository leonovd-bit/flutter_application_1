import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PastOrdersPage extends StatelessWidget {
  final String userId = "exampleUserId";

  const PastOrdersPage({super.key}); // Replace with actual user ID

  Future<List<Map<String, dynamic>>> _fetchPastOrders() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('orders')
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Past Orders'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchPastOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading past orders'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No past orders found'));
          }

          final pastOrders = snapshot.data!;
          return ListView.builder(
            itemCount: pastOrders.length,
            itemBuilder: (context, index) {
              final order = pastOrders[index];
              return Card(
                margin: EdgeInsets.all(8.0),
                child: ListTile(
                  leading: order['mealImage'] != null
                      ? Image.network(order['mealImage'], width: 50, height: 50)
                      : Icon(Icons.fastfood),
                  title: Text(order['mealName'] ?? 'Unknown Meal'),
                  subtitle: Text('Delivered on: ${order['deliveryDate'] ?? 'Unknown Date'}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
