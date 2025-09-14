import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal_model_v3.dart';

class SimpleMealPlanService {
  static final _firestore = FirebaseFirestore.instance;

  // Simplified version that just stores the plan preference locally and in user doc
  static Future<void> setActiveMealPlanSimple(String userId, MealPlanModelV3 plan) async {
    try {
      debugPrint('[SimpleMealPlanService] Setting meal plan ${plan.id} for user $userId');
      
      // Just update the user document with current plan info
      await _firestore.collection('users').doc(userId).set({
        'currentMealPlanId': plan.id,
        'currentPlanName': plan.displayName.isNotEmpty ? plan.displayName : plan.name,
        'currentMealsPerDay': plan.mealsPerDay,
        'currentPricePerMeal': plan.pricePerMeal,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('[SimpleMealPlanService] Successfully updated user document');
    } catch (e) {
      debugPrint('[SimpleMealPlanService] Error: $e');
      throw Exception('Failed to set meal plan: $e');
    }
  }

  // Test authentication
  static Future<void> testAuth() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[SimpleMealPlanService] No user logged in');
        return;
      }
      
      debugPrint('[SimpleMealPlanService] User: ${user.uid}');
      debugPrint('[SimpleMealPlanService] Email: ${user.email}');
      debugPrint('[SimpleMealPlanService] Email verified: ${user.emailVerified}');
      
      final token = await user.getIdTokenResult();
      debugPrint('[SimpleMealPlanService] Claims: ${token.claims}');
      
      // Test basic write to user document
      await _firestore.collection('users').doc(user.uid).set({
        'test': 'value',
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      debugPrint('[SimpleMealPlanService] Basic write test successful');
    } catch (e) {
      debugPrint('[SimpleMealPlanService] Auth test error: $e');
    }
  }
}
