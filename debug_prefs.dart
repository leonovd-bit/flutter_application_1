import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  // Initialize Firebase Auth
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print('No user logged in');
    return;
  }
  
  final prefs = await SharedPreferences.getInstance();
  final userId = user.uid;
  
  print('=== DEBUG SHARED PREFERENCES DATA ===');
  print('User ID: $userId');
  print('');
  
  // Check all possible keys
  final keys = [
    'user_meal_selections_$userId',
    'delivery_schedule_$userId',
    'user_delivery_address_$userId',
    'user_meals_per_day_$userId',
    'selected_schedule_$userId',
    'meal_selections_${userId}_weekly',
    'meal_selections_${userId}_monthly',
  ];
  
  for (final key in keys) {
    final value = prefs.getString(key);
    if (value != null) {
      print('KEY: $key');
      print('VALUE: $value');
      print('---');
    } else {
      print('KEY: $key - NOT FOUND');
    }
  }
  
  // Check for any keys containing the user ID
  final allKeys = prefs.getKeys();
  print('');
  print('=== ALL KEYS CONTAINING USER ID ===');
  for (final key in allKeys) {
    if (key.contains(userId)) {
      final value = prefs.get(key);
      print('$key: $value');
    }
  }
  
  print('');
  print('=== ALL KEYS (first 50 chars) ===');
  for (final key in allKeys.take(20)) {
    final value = prefs.get(key);
    final valueStr = value.toString();
    print('$key: ${valueStr.length > 50 ? valueStr.substring(0, 50) + '...' : valueStr}');
  }
}