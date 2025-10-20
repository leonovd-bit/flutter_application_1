import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'lib/app_v3/services/meal_service_v3.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
    return;
  }

  print('\n=== Testing Meal Database ===');
  
  // 1. Check existing meals in database
  try {
    final allMeals = await MealServiceV3.getAllMeals();
    print('📊 Total meals in database: ${allMeals.length}');
    
    if (allMeals.isNotEmpty) {
      print('🍽️ Sample meals in database:');
      for (int i = 0; i < allMeals.length && i < 5; i++) {
        final meal = allMeals[i];
        print('   ${i+1}. ${meal.name} (${meal.mealType}) - ID: ${meal.id}');
      }
    }
  } catch (e) {
    print('❌ Error getting all meals: $e');
  }
  
  // 2. Test meals by type
  for (final type in ['breakfast', 'lunch', 'dinner']) {
    try {
      final meals = await MealServiceV3.getMeals(mealType: type, limit: 5);
      print('🥗 $type meals: ${meals.length}');
      for (final meal in meals) {
        print('   - ${meal.name}');
      }
    } catch (e) {
      print('❌ Error getting $type meals: $e');
    }
  }
  
  // 3. Try manual seeding
  print('\n=== Attempting Manual Seed ===');
  try {
    final seeded = await MealServiceV3.seedFromJsonAsset();
    print('🌱 Seeded $seeded meals');
  } catch (e) {
    print('❌ Seeding failed: $e');
  }
  
  // 4. Check again after seeding
  print('\n=== After Seeding Check ===');
  try {
    final newTotal = await MealServiceV3.getAllMeals();
    print('📊 Total meals after seeding: ${newTotal.length}');
    
    for (final type in ['breakfast', 'lunch', 'dinner']) {
      final meals = await MealServiceV3.getMeals(mealType: type, limit: 3);
      print('🥗 $type meals: ${meals.length}');
      for (final meal in meals) {
        print('   - ${meal.name} (ID: ${meal.id})');
      }
    }
  } catch (e) {
    print('❌ Error in final check: $e');
  }
  
  // 5. Direct Firestore query test
  print('\n=== Direct Firestore Query ===');
  try {
    final db = FirebaseFirestore.instance;
    final snapshot = await db.collection('meals').limit(5).get();
    print('🔥 Direct Firestore query found ${snapshot.docs.length} meals');
    for (final doc in snapshot.docs) {
      final data = doc.data();
      print('   - ${data['name']} (${data['mealType']}) - Doc ID: ${doc.id}');
    }
  } catch (e) {
    print('❌ Direct Firestore query failed: $e');
  }
  
  print('\n=== Test Complete ===');
  exit(0);
}
