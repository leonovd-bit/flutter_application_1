import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lib/app_v3/services/meal_service_v3.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  print('=== Live User Authentication Test ===');
  
  // Check if user is signed in
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('❌ No user is currently signed in');
    print('Please sign in to the app first, then run this test');
    return;
  }
  
  print('✅ User is signed in: ${user.email}');
  print('   User ID: ${user.uid}');
  print('   Email verified: ${user.emailVerified}');
  
  // Test direct Firestore access
  print('\n=== Direct Firestore Test ===');
  try {
    final db = FirebaseFirestore.instance;
    final snapshot = await db.collection('meals').limit(10).get();
    print('🔥 Firestore meals collection has ${snapshot.docs.length} documents');
    
    if (snapshot.docs.isEmpty) {
      print('❌ Meals collection is empty - this is the problem!');
      
      print('\n=== Attempting to seed meals ===');
      final seeded = await MealServiceV3.seedFromJsonAsset();
      print('🌱 Seeded $seeded meals');
      
      // Check again
      final newSnapshot = await db.collection('meals').limit(10).get();
      print('🔥 After seeding: ${newSnapshot.docs.length} documents');
      
      if (newSnapshot.docs.isNotEmpty) {
        print('✅ Seeding successful! Sample meals:');
        for (final doc in newSnapshot.docs.take(3)) {
          final data = doc.data();
          print('   - ${data['name']} (${data['mealType']})');
        }
      }
    } else {
      print('✅ Meals found in database:');
      for (final doc in snapshot.docs.take(5)) {
        final data = doc.data();
        print('   - ${data['name']} (${data['mealType']}) - ${data['imageUrl'] ?? 'no image'}');
      }
    }
  } catch (e) {
    print('❌ Firestore access failed: $e');
  }
  
  // Test MealServiceV3.getMeals() for each type
  print('\n=== Testing MealServiceV3.getMeals() ===');
  for (final type in ['breakfast', 'lunch', 'dinner']) {
    try {
      final meals = await MealServiceV3.getMeals(mealType: type, limit: 5);
      print('🍽️ $type: ${meals.length} meals');
      for (final meal in meals.take(2)) {
        print('   - ${meal.name} (${meal.imageUrl.isEmpty ? "no image" : "has image"})');
      }
    } catch (e) {
      print('❌ Error getting $type meals: $e');
    }
  }
  
  print('\n=== Test Complete ===');
}
