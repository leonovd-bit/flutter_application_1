import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WeeklyMealPlannerPage extends StatefulWidget {
  const WeeklyMealPlannerPage({super.key});

  @override
  _WeeklyMealPlannerPageState createState() => _WeeklyMealPlannerPageState();
}

class _WeeklyMealPlannerPageState extends State<WeeklyMealPlannerPage> {
  final String userId = "exampleUserId"; // Replace with actual user ID

  Future<Map<String, dynamic>> _fetchWeeklyPlan() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('weeklyPlans')
        .get();

    Map<String, dynamic> weeklyPlan = {};
    for (var doc in snapshot.docs) {
      weeklyPlan[doc.id] = doc.data();
    }
    return weeklyPlan;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Weekly Meal Planner'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchWeeklyPlan(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading weekly plan'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No weekly plan found'));
          }

          final weeklyPlan = snapshot.data!;
          return ListView.builder(
            itemCount: weeklyPlan.keys.length,
            itemBuilder: (context, index) {
              final day = weeklyPlan.keys.elementAt(index);
              final meals = weeklyPlan[day];

              return Card(
                margin: EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(day),
                  subtitle: Text(meals.toString()),
                  trailing: IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () {
                      // Navigate to edit meal plan for the day
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
