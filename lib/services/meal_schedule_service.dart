import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meal_schedule.dart';
import '../models/meal.dart';

class MealScheduleService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'meal_schedules';

  // Create meal schedule
  static Future<String> createMealSchedule(MealSchedule schedule) async {
    try {
      final docRef = await _firestore.collection(_collection).add(schedule.toMap());
      await docRef.update({'id': docRef.id});
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create meal schedule: $e');
    }
  }

  // Get user meal schedules
  static Future<List<MealSchedule>> getUserMealSchedules(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('isActive', descending: true)
          .orderBy('createdAt', descending: false)
          .get();

      return querySnapshot.docs
          .map((doc) => MealSchedule.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get user meal schedules: $e');
    }
  }

  // Get meal schedule by ID
  static Future<MealSchedule?> getMealSchedule(String scheduleId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(scheduleId).get();
      if (doc.exists && doc.data() != null) {
        return MealSchedule.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get meal schedule: $e');
    }
  }

  // Update meal schedule
  static Future<void> updateMealSchedule(MealSchedule schedule) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(schedule.id)
          .update(schedule.copyWith(updatedAt: DateTime.now()).toMap());
    } catch (e) {
      throw Exception('Failed to update meal schedule: $e');
    }
  }

  // Update daily meals for a specific date
  static Future<void> updateDailyMeals(
    String scheduleId,
    String date,
    DailyMeals dailyMeals,
  ) async {
    try {
      await _firestore.collection(_collection).doc(scheduleId).update({
        'weeklyMeals.$date': dailyMeals.toMap(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update daily meals: $e');
    }
  }

  // Update meals for specific meal type and date
  static Future<void> updateMealsForDate(
    String scheduleId,
    String date,
    MealType mealType,
    List<String> mealIds,
  ) async {
    try {
      final fieldName = 'weeklyMeals.$date.${_getMealTypeFieldName(mealType)}';
      await _firestore.collection(_collection).doc(scheduleId).update({
        fieldName: mealIds,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to update meals for date: $e');
    }
  }

  // Apply meal selection to entire week
  static Future<void> applyMealsToWeek(
    String scheduleId,
    DailyMeals templateMeals,
    List<String> dates,
  ) async {
    try {
      final batch = _firestore.batch();
      final scheduleRef = _firestore.collection(_collection).doc(scheduleId);

      final updates = <String, dynamic>{
        'updatedAt': DateTime.now().toIso8601String(),
      };

      for (final date in dates) {
        updates['weeklyMeals.$date'] = templateMeals.toMap();
      }

      batch.update(scheduleRef, updates);
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to apply meals to week: $e');
    }
  }

  // Get meals for specific date
  static Future<DailyMeals?> getMealsForDate(String scheduleId, String date) async {
    try {
      final doc = await _firestore.collection(_collection).doc(scheduleId).get();
      if (doc.exists && doc.data() != null) {
        final schedule = MealSchedule.fromMap(doc.data()!);
        return schedule.weeklyMeals[date];
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get meals for date: $e');
    }
  }

  // Delete meal schedule
  static Future<void> deleteMealSchedule(String scheduleId) async {
    try {
      await _firestore.collection(_collection).doc(scheduleId).delete();
    } catch (e) {
      throw Exception('Failed to delete meal schedule: $e');
    }
  }

  // Set active schedule
  static Future<void> setActiveSchedule(String userId, String scheduleId) async {
    try {
      final batch = _firestore.batch();

      // Set all user schedules to inactive
      final userSchedules = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in userSchedules.docs) {
        batch.update(doc.reference, {
          'isActive': false,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      // Set the specified schedule as active
      final scheduleRef = _firestore.collection(_collection).doc(scheduleId);
      batch.update(scheduleRef, {
        'isActive': true,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to set active schedule: $e');
    }
  }

  // Get active schedule
  static Future<MealSchedule?> getActiveSchedule(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return MealSchedule.fromMap(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get active schedule: $e');
    }
  }

  // Stream user meal schedules
  static Stream<List<MealSchedule>> streamUserMealSchedules(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('isActive', descending: true)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MealSchedule.fromMap(doc.data()))
            .toList());
  }

  // Stream specific meal schedule
  static Stream<MealSchedule?> streamMealSchedule(String scheduleId) {
    return _firestore
        .collection(_collection)
        .doc(scheduleId)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return MealSchedule.fromMap(doc.data()!);
      }
      return null;
    });
  }

  // Helper method to get field name for meal type
  static String _getMealTypeFieldName(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return 'breakfastMealIds';
      case MealType.lunch:
        return 'lunchMealIds';
      case MealType.dinner:
        return 'dinnerMealIds';
    }
  }

  // Generate date string in YYYY-MM-DD format
  static String formatDateForStorage(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Parse date string from storage
  static DateTime parseDateFromStorage(String dateString) {
    return DateTime.parse(dateString);
  }
}
