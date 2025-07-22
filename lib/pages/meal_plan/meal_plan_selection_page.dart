import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MealPlanSelectionPage extends StatefulWidget {
  const MealPlanSelectionPage({super.key});

  @override
  _MealPlanSelectionPageState createState() => _MealPlanSelectionPageState();
}

class _MealPlanSelectionPageState extends State<MealPlanSelectionPage> {
  int _mealsPerDay = 1;
  TimeOfDay _breakfastTime = TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _lunchTime = TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _dinnerTime = TimeOfDay(hour: 18, minute: 0);
  bool _autoSelectMeals = false;
  bool _reminderEnabled = false;

  Future<void> _savePreferences() async {
    final userId = "exampleUserId"; // Replace with actual user ID
    final preferences = {
      'mealsPerDay': _mealsPerDay,
      'preferredMealTimes': {
        'breakfast': _breakfastTime.format(context),
        'lunch': _lunchTime.format(context),
        'dinner': _dinnerTime.format(context),
      },
      'autoSelectMeals': _autoSelectMeals,
      'reminderEnabled': _reminderEnabled,
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('preferences')
        .doc('mealPlan')
        .set(preferences);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Preferences saved successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Meal Plan Selection'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButton<int>(
              value: _mealsPerDay,
              items: [1, 2, 3]
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text('$e meals per day'),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _mealsPerDay = value!;
                });
              },
            ),
            ListTile(
              title: Text('Breakfast Time: ${_breakfastTime.format(context)}'),
              trailing: Icon(Icons.edit),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _breakfastTime,
                );
                if (time != null) {
                  setState(() {
                    _breakfastTime = time;
                  });
                }
              },
            ),
            ListTile(
              title: Text('Lunch Time: ${_lunchTime.format(context)}'),
              trailing: Icon(Icons.edit),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _lunchTime,
                );
                if (time != null) {
                  setState(() {
                    _lunchTime = time;
                  });
                }
              },
            ),
            ListTile(
              title: Text('Dinner Time: ${_dinnerTime.format(context)}'),
              trailing: Icon(Icons.edit),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _dinnerTime,
                );
                if (time != null) {
                  setState(() {
                    _dinnerTime = time;
                  });
                }
              },
            ),
            SwitchListTile(
              title: Text('Auto Select Meals'),
              value: _autoSelectMeals,
              onChanged: (value) {
                setState(() {
                  _autoSelectMeals = value;
                });
              },
            ),
            SwitchListTile(
              title: Text('Enable Reminders'),
              value: _reminderEnabled,
              onChanged: (value) {
                setState(() {
                  _reminderEnabled = value;
                });
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _savePreferences,
              child: Text('Save Preferences'),
            ),
          ],
        ),
      ),
    );
  }
}
