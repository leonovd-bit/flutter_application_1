import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DateUtilsV3 {
  /// Returns the next Monday's date from today
  static DateTime getNextMonday() {
    final now = DateTime.now();
    final daysUntilMonday = (DateTime.monday + 7 - now.weekday) % 7;
    // If today is Monday, we still want next Monday
    final days = daysUntilMonday == 0 ? 7 : daysUntilMonday;
    final nextMonday = now.add(Duration(days: days));
    debugPrint('[DateUtils] Next Monday from ${now.toIso8601String()} is ${nextMonday.toIso8601String()} ($days days)');
    return DateTime(nextMonday.year, nextMonday.month, nextMonday.day);
  }

  /// Returns whether the given date is on or after next Monday
  static bool isOnOrAfterNextMonday(DateTime date) {
    final nextMonday = getNextMonday();
    final normalizedDate = DateTime(date.year, date.month, date.day);
    return !normalizedDate.isBefore(nextMonday);
  }

  /// Returns whether user has an active subscription starting before next Monday
  static Future<bool> hasExistingSubscription() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final mealSelectionsKey = 'meal_selections_${user.uid}_weekly';
      final hasSelections = prefs.containsKey(mealSelectionsKey);

      if (!hasSelections) return false;

      // Check if they have any confirmed orders in Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'confirmed')
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('[DateUtils] Error checking subscription: $e');
      return false;
    }
  }
}