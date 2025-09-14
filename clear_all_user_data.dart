// Utility to completely clear all user data for testing signup flow
import 'package:shared_preferences/shared_preferences.dart';

Future<void> clearAllUserData() async {
  final prefs = await SharedPreferences.getInstance();
  
  // Clear setup flags
  await prefs.remove('setup_completed');
  await prefs.remove('saved_schedules');
  await prefs.remove('selected_meal_plan_display_name');
  await prefs.remove('selected_meal_plan_id');
  await prefs.remove('selected_meal_plan_name');
  await prefs.remove('force_sign_out');
  
  // Clear onboarding progress
  await prefs.remove('current_step');
  await prefs.remove('signup_data');
  await prefs.remove('schedule_data');
  await prefs.remove('payment_data');
  await prefs.remove('step_timestamp');
  
  // Clear any uid-based keys (this would need the actual uid, but let's clear common patterns)
  final keys = prefs.getKeys();
  for (final key in keys) {
    if (key.contains('_uid') || key.contains('selected_meal_plan')) {
      await prefs.remove(key);
    }
  }
  
  print('Cleared all user data. Try signing up with a fresh account now.');
}

void main() async {
  await clearAllUserData();
}
