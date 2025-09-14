import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/app_v3/services/meal_service_v3.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  print('=== DEBUG: Checking meals in database ===');
  
  // Check all meals
  final allMeals = await MealServiceV3.getAllMeals();
  print('Total meals in database: ${allMeals.length}');
  
  // Check meals by type
  for (final type in ['breakfast', 'lunch', 'dinner']) {
    final meals = await MealServiceV3.getMeals(mealType: type, limit: 10);
    print('$type meals: ${meals.length}');
    for (final meal in meals.take(3)) {
      print('  - ${meal.name} (${meal.mealType})');
    }
  }
  
  // If no meals, try seeding
  if (allMeals.isEmpty) {
    print('No meals found, attempting to seed...');
    final seeded = await MealServiceV3.seedFromJsonAsset();
    print('Seeded $seeded meals');
    
    // Check again after seeding
    final newMeals = await MealServiceV3.getAllMeals();
    print('After seeding - Total meals: ${newMeals.length}');
    for (final meal in newMeals.take(5)) {
      print('  - ${meal.name} (${meal.mealType})');
    }
  }
}
