import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('Starting upcoming meals debug...');
  
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Simulate a user being signed in
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No user signed in');
      return;
    }
    
    final userId = user.uid;
    print('✅ User ID: $userId');
    
    // Check for meal plan selection
    final selectedPlanName = prefs.getString('selected_meal_plan_display_name');
    print('📋 Selected meal plan: ${selectedPlanName ?? 'None'}');
    
    // Check for schedule selection
    final selectedSchedule = prefs.getString('selected_schedule_${userId}') ?? 'weekly';
    print('📅 Selected schedule: $selectedSchedule');
    
    // Check for meal selections
    final mealSelectionsKey = 'meal_selections_${userId}_$selectedSchedule';
    final mealSelectionsJson = prefs.getString(mealSelectionsKey);
    print('🍽️ Meal selections key: $mealSelectionsKey');
    print('🍽️ Meal selections exist: ${mealSelectionsJson != null}');
    
    if (mealSelectionsJson != null) {
      try {
        final mealSelections = json.decode(mealSelectionsJson) as Map<String, dynamic>;
        print('🍽️ Meal selections days: ${mealSelections.keys.toList()}');
        
        // Check what meals exist for each day
        for (final day in mealSelections.keys) {
          final dayMeals = mealSelections[day] as Map<String, dynamic>?;
          if (dayMeals != null) {
            print('  📅 $day: ${dayMeals.keys.toList()}');
          }
        }
      } catch (e) {
        print('❌ Error parsing meal selections: $e');
      }
    }
    
    // Check for delivery schedule
    final deliveryScheduleKey = 'delivery_schedule_${userId}';
    final deliveryScheduleJson = prefs.getString(deliveryScheduleKey);
    print('🚚 Delivery schedule key: $deliveryScheduleKey');
    print('🚚 Delivery schedule exists: ${deliveryScheduleJson != null}');
    
    if (deliveryScheduleJson != null) {
      try {
        final deliverySchedule = json.decode(deliveryScheduleJson) as Map<String, dynamic>;
        print('🚚 Delivery schedule days: ${deliverySchedule.keys.toList()}');
      } catch (e) {
        print('❌ Error parsing delivery schedule: $e');
      }
    }
    
    // List all SharedPreferences keys to see what's actually stored
    print('\\n📋 All SharedPreferences keys:');
    final allKeys = prefs.getKeys();
    for (final key in allKeys) {
      print('  • $key');
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
  
  print('Debug complete!');
}