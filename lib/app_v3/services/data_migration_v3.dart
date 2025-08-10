import 'package:flutter/foundation.dart';
import '../models/meal_model_v3.dart';
import 'firestore_service_v3.dart';

class DataMigrationV3 {
  // Seeds canonical meal plans into the user's space if missing
  static Future<void> seedMealPlansIfMissing(String userId) async {
    try {
      final plans = MealPlanModelV3.getAvailablePlans();
      for (final p in plans) {
        final plan = MealPlanModelV3(
          id: p.id,
          userId: userId,
          name: p.name,
          displayName: p.displayName,
          mealsPerDay: p.mealsPerDay,
          pricePerWeek: p.pricePerWeek,
          pricePerMeal: p.pricePerMeal,
          description: p.description,
          isActive: false,
          createdAt: DateTime.now(),
        );
        await FirestoreServiceV3.saveMealPlan(plan);
      }
    } catch (e) {
      debugPrint('Seed meal plans failed: $e');
    }
  }
}
