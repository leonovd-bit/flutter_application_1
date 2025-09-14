import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal_model_v3.dart';

/// Service to manage order lifecycle: Scheduled → Upcoming → Completed
class OrderLifecycleService {
  static const String _completedOrdersKey = 'completed_orders';
  
  /// Mark a scheduled meal as delivered/completed
  static Future<void> markMealAsDelivered({
    required String day,
    required String mealType,
    required MealModelV3 meal,
    required String deliveryAddress,
    required DateTime deliveryTime,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final key = '${_completedOrdersKey}_${user.uid}';
    
    // Get existing completed orders
    final existingJson = prefs.getString(key) ?? '[]';
    final List<dynamic> existingOrders = json.decode(existingJson);
    
    // Create new completed order
    final completedOrder = {
      'id': 'completed_${day}_${mealType}_${DateTime.now().millisecondsSinceEpoch}',
      'meal': meal.toJson(),
      'deliveryAddress': deliveryAddress,
      'deliveryTime': deliveryTime.toIso8601String(),
      'completedAt': DateTime.now().toIso8601String(),
      'day': day,
      'mealType': mealType,
      'status': 'delivered',
      'totalAmount': meal.price,
    };
    
    // Add to completed orders (most recent first)
    existingOrders.insert(0, completedOrder);
    
    // Keep only last 50 completed orders
    if (existingOrders.length > 50) {
      existingOrders.removeRange(50, existingOrders.length);
    }
    
    // Save back to SharedPreferences
    await prefs.setString(key, json.encode(existingOrders));
    
    print('[OrderLifecycle] Marked meal as delivered: ${meal.name} on $day at ${deliveryTime.toIso8601String()}');
  }
  
  /// Get all completed orders for the current user
  static Future<List<Map<String, dynamic>>> getCompletedOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    
    final prefs = await SharedPreferences.getInstance();
    final key = '${_completedOrdersKey}_${user.uid}';
    
    final existingJson = prefs.getString(key) ?? '[]';
    final List<dynamic> orders = json.decode(existingJson);
    
    return orders.cast<Map<String, dynamic>>();
  }
  
  /// Simulate meal delivery completion (for testing)
  static Future<void> simulateDeliveryCompletion({
    required String day,
    required String mealType,
    required MealModelV3 meal,
    required String deliveryAddress,
  }) async {
    // Simulate a delivery that happened in the past
    final deliveryTime = DateTime.now().subtract(
      Duration(
        days: _getDaysAgo(day),
        hours: _getMealHour(mealType),
      ),
    );
    
    await markMealAsDelivered(
      day: day,
      mealType: mealType,
      meal: meal,
      deliveryAddress: deliveryAddress,
      deliveryTime: deliveryTime,
    );
  }
  
  /// Convert day name to days ago for simulation
  static int _getDaysAgo(String day) {
    final now = DateTime.now();
    final currentDayIndex = now.weekday - 1; // Monday = 0
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final targetDayIndex = days.indexOf(day.toLowerCase());
    
    if (targetDayIndex == -1) return 1;
    
    // Calculate how many days ago this day was
    int daysAgo = currentDayIndex - targetDayIndex;
    if (daysAgo <= 0) daysAgo += 7; // If it's future/today, make it last week
    
    return daysAgo;
  }
  
  /// Get typical meal hour for simulation
  static int _getMealHour(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return 8;
      case 'lunch':
        return 12;
      case 'dinner':
        return 18;
      default:
        return 12;
    }
  }
  
  /// Create some sample completed orders for demonstration
  static Future<void> createSampleCompletedOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Create sample meals for past deliveries
    final sampleMeals = [
      MealModelV3(
        id: 'meal_bbq_pork',
        name: 'BBQ Pulled Pork',
        description: 'Slow-cooked pulled pork with tangy BBQ sauce',
        imageUrl: 'assets/images/meals/bbq-pulled-pork.jpg',
        calories: 580,
        protein: 35,
        carbs: 45,
        fat: 28,
        mealType: 'lunch',
        price: 14.99,
        ingredients: ['Pork shoulder', 'BBQ sauce', 'Coleslaw', 'Brioche bun'],
        allergens: ['Gluten'],
        icon: Icons.lunch_dining,
      ),
      MealModelV3(
        id: 'meal_beef_burrito',
        name: 'Beef Burrito',
        description: 'Seasoned ground beef with rice, beans, and cheese',
        imageUrl: 'assets/images/meals/beef-burrito.jpg',
        calories: 520,
        protein: 28,
        carbs: 52,
        fat: 22,
        mealType: 'dinner',
        price: 13.99,
        ingredients: ['Ground beef', 'Rice', 'Black beans', 'Cheese', 'Tortilla'],
        allergens: ['Dairy', 'Gluten'],
        icon: Icons.dinner_dining,
      ),
      MealModelV3(
        id: 'meal_chicken_salad',
        name: 'Grilled Chicken Salad',
        description: 'Fresh mixed greens with grilled chicken breast',
        imageUrl: 'assets/images/meals/grilled-chicken-salad.jpg',
        calories: 320,
        protein: 32,
        carbs: 15,
        fat: 12,
        mealType: 'lunch',
        price: 12.99,
        ingredients: ['Chicken breast', 'Mixed greens', 'Cherry tomatoes', 'Vinaigrette'],
        allergens: [],
        icon: Icons.lunch_dining,
      ),
    ];
    
    // Create completed orders for the past week
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];
    
    for (int i = 0; i < days.length; i++) {
      final meal = sampleMeals[i % sampleMeals.length];
      await simulateDeliveryCompletion(
        day: days[i],
        mealType: meal.mealType,
        meal: meal,
        deliveryAddress: '123 Main St, New York, NY 10001',
      );
    }
    
    print('[OrderLifecycle] Created ${days.length} sample completed orders');
  }
}
