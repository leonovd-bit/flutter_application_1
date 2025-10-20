import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../theme/app_theme_v3.dart';
import '../services/firestore_service_v3.dart';
import 'meal_schedule_screen.dart';

class MealSelectionScreen extends StatefulWidget {
  const MealSelectionScreen({super.key});

  @override
  State<MealSelectionScreen> createState() => _MealSelectionScreenState();
}

class _MealSelectionScreenState extends State<MealSelectionScreen> {
  int selectedMealsPerDay = 1;
  List<Map<String, dynamic>> selectedMeals = [];
  final TextEditingController _addressController = TextEditingController();
  String? savedAddress;

  // Sample meals data - using your provided structure
  final List<Map<String, dynamic>> meals = [
    {
      'name': 'Grilled Chicken',
      'description': 'Healthy grilled chicken breast',
      'image': 'assets/images/meals/grilled-chicken-salad.jpg',
      'price': 12.99,
      'calories': 320,
      'protein': 35,
    },
    {
      'name': 'Salmon Bowl',
      'description': 'Fresh salmon with quinoa',
      'image': 'assets/images/meals/salmon-with-quinoa.jpg',
      'price': 15.99,
      'calories': 450,
      'protein': 28,
    },
    {
      'name': 'Vegetarian Wrap',
      'description': 'Mixed vegetables wrap',
      'image': 'assets/images/meals/veggie-wrap.jpg',
      'price': 10.99,
      'calories': 280,
      'protein': 15,
    },
    {
      'name': 'Turkey Sandwich',
      'description': 'Whole wheat turkey sandwich',
      'image': 'assets/images/meals/turkey-sandwich.jpg',
      'price': 9.99,
      'calories': 350,
      'protein': 25,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        backgroundColor: AppThemeV3.surface,
        title: const Text('Select Your Meals'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Meals per day selection
          const Text('How many meals per day?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [1, 2, 3].map((num) {
              return ChoiceChip(
                label: Text('$num meal${num > 1 ? 's' : ''}'),
                selected: selectedMealsPerDay == num,
                onSelected: (selected) {
                  setState(() {
                    selectedMealsPerDay = num;
                    // Clear selected meals when changing meals per day
                    selectedMeals.clear();
                  });
                },
              );
            }).toList(),
          ),
          
          // Address input
          const SizedBox(height: 20),
          const Text('Delivery Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            controller: _addressController,
            decoration: InputDecoration(
              hintText: 'Enter your delivery address',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.save),
                onPressed: () {
                  setState(() {
                    savedAddress = _addressController.text;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Address saved!')),
                  );
                },
              ),
            ),
            onSubmitted: (value) {
              setState(() {
                savedAddress = value;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Address saved!')),
              );
            },
          ),
          if (savedAddress != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Saved: $savedAddress', style: const TextStyle(color: Colors.green)),
            ),
          
          // Meal selection grid
          const SizedBox(height: 20),
          const Text('Select your meals', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.8,
            ),
            itemCount: meals.length,
            itemBuilder: (context, index) {
              final meal = meals[index];
              final isSelected = selectedMeals.any((m) => m['name'] == meal['name']);
              final canSelect = selectedMeals.length < selectedMealsPerDay;
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      selectedMeals.removeWhere((m) => m['name'] == meal['name']);
                    } else if (canSelect) {
                      selectedMeals.add(meal);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('You can only select $selectedMealsPerDay meal${selectedMealsPerDay > 1 ? 's' : ''}')),
                      );
                    }
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? Colors.green : Colors.grey.shade300,
                      width: isSelected ? 3 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                          child: Image.asset(
                            meal['image'],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.fastfood, size: 48),
                              );
                            },
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Text(
                              meal['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            Text('\$${meal['price'].toStringAsFixed(2)}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          // Continue button
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: selectedMeals.length == selectedMealsPerDay && savedAddress != null
                ? () async {
                    // Save user selections for upcoming orders
                    await _saveUserSelections();
                    
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MealScheduleScreen(
                            mealsPerDay: selectedMealsPerDay,
                            selectedMeals: selectedMeals,
                            deliveryAddress: savedAddress!,
                          ),
                        ),
                      );
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Continue to Schedule'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveUserSelections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = FirestoreServiceV3.getCurrentUserId() ?? 'local_user';
      
      debugPrint('[MealSelection] Saving selections for userId: $userId');
      debugPrint('[MealSelection] Selected meals count: ${selectedMeals.length}');
      debugPrint('[MealSelection] Meals per day: $selectedMealsPerDay');
      debugPrint('[MealSelection] Delivery address: $savedAddress');
      
      // Save selected meals
      await prefs.setString('user_meal_selections_$userId', json.encode(selectedMeals));
      
      // Save delivery address
      await prefs.setString('user_delivery_address_$userId', savedAddress!);
      
      // Save meals per day setting
      await prefs.setInt('user_meals_per_day_$userId', selectedMealsPerDay);
      
      debugPrint('[MealSelection] Saved user selections successfully');
      debugPrint('[MealSelection] Saved user selections: ${selectedMeals.length} meals, $selectedMealsPerDay per day');
    } catch (e) {
      debugPrint('[MealSelection] Error saving user selections: $e');
    }
  }
}