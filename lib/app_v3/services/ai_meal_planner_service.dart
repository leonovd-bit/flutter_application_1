import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/meal_model_v3.dart';
import 'meal_service_v3.dart';
import 'firestore_service_v3.dart';

/// AI-powered meal planning service that creates personalized meal recommendations
/// based on user preferences, dietary restrictions, and nutritional goals
class AIMealPlannerService {
  static const String _userPreferencesKey = 'ai_user_preferences';
  static const String _mealHistoryKey = 'ai_meal_history';

  /// User dietary preferences and restrictions
  static Future<Map<String, dynamic>> getUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final prefsJson = prefs.getString(_userPreferencesKey);
    
    if (prefsJson != null) {
      final decoded = json.decode(prefsJson);
      return Map<String, dynamic>.from(decoded);
    }
    
    // Default preferences
    return {
      'allergies': <String>[],
      'dietaryRestrictions': <String>[], // vegetarian, vegan, keto, etc.
      'dislikedIngredients': <String>[],
      'preferredCuisines': <String>[],
      'nutritionGoals': {
        'calories': 2000,
        'protein': 150,
        'carbs': 200,
        'fat': 65,
      },
      'mealFrequency': 3, // meals per day
      'activityLevel': 'moderate', // sedentary, light, moderate, active, very_active
      'healthGoals': <String>[], // weight_loss, muscle_gain, maintenance
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// Save user preferences
  static Future<void> saveUserPreferences(Map<String, dynamic> preferences) async {
    final prefs = await SharedPreferences.getInstance();
    preferences['lastUpdated'] = DateTime.now().toIso8601String();
    await prefs.setString(_userPreferencesKey, json.encode(preferences));
    
    // Also save to Firestore for backup
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirestoreServiceV3.updateUserProfile(user.uid, {
          'aiPreferences': preferences,
        });
      } catch (e) {
        debugPrint('[AIMealPlannerService] Error saving to Firestore: $e');
      }
    }
  }

  /// Get user's meal history for learning preferences
  static Future<List<Map<String, dynamic>>> getMealHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(_mealHistoryKey);
    
    if (historyJson != null) {
      final List<dynamic> historyList = json.decode(historyJson);
      return historyList.map((item) => Map<String, dynamic>.from(item)).toList();
    }
    
    return [];
  }

  /// Track a meal selection for AI learning
  static Future<void> trackMealSelection(MealModelV3 meal, double rating) async {
    final history = await getMealHistory();
    
    final mealEntry = {
      'mealId': meal.id,
      'mealName': meal.name,
      'mealType': meal.mealType,
      'ingredients': meal.ingredients,
      'calories': meal.calories,
      'protein': meal.protein,
      'carbs': meal.carbs,
      'fat': meal.fat,
      'rating': rating,
      'selectedAt': DateTime.now().toIso8601String(),
    };
    
    history.add(mealEntry);
    
    // Keep only last 100 meals to prevent unlimited growth
    if (history.length > 100) {
      history.removeAt(0);
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mealHistoryKey, json.encode(history));
  }

  /// Generate AI-powered meal recommendations
  static Future<List<MealModelV3>> getAIRecommendations({
    required String mealType,
    int count = 10,
    bool excludeRecent = true,
  }) async {
    try {
      debugPrint('[AIMealPlannerService] Generating AI recommendations for $mealType');
      
      // Get all available meals of the requested type
      final allMeals = await MealServiceV3.getMeals(mealType: mealType, limit: 100);
      
      if (allMeals.isEmpty) {
        debugPrint('[AIMealPlannerService] No meals available for type: $mealType');
        return [];
      }

      // Get user preferences and history
      final preferences = await getUserPreferences();
      final history = await getMealHistory();
      
      // Score and rank meals based on AI algorithm
      final scoredMeals = await _scoreMeals(allMeals, preferences, history, excludeRecent);
      
      // Sort by score (highest first) and return top recommendations
      scoredMeals.sort((a, b) => b['score'].compareTo(a['score']));
      
      final recommendations = scoredMeals
          .take(count)
          .map((item) => item['meal'] as MealModelV3)
          .toList();
      
      debugPrint('[AIMealPlannerService] Generated ${recommendations.length} recommendations');
      return recommendations;
      
    } catch (e) {
      debugPrint('[AIMealPlannerService] Error generating recommendations: $e');
      // Fallback to regular meal service
      return await MealServiceV3.getMeals(mealType: mealType, limit: count);
    }
  }

  /// Generate a complete weekly meal plan
  static Future<Map<String, List<MealModelV3>>> generateWeeklyPlan({
    required MealPlanModelV3 plan,
    DateTime? startDate,
  }) async {
    startDate ??= DateTime.now();
    final weeklyPlan = <String, List<MealModelV3>>{};
    
    final mealTypes = ['breakfast', 'lunch', 'dinner'];
    
    for (int day = 0; day < 7; day++) {
      final date = startDate.add(Duration(days: day));
      final dayKey = _formatDateKey(date);
      weeklyPlan[dayKey] = [];
      
      for (int mealIndex = 0; mealIndex < plan.mealsPerDay; mealIndex++) {
        final mealType = mealTypes[mealIndex % mealTypes.length];
        
        // Get AI recommendations for this meal type
        final recommendations = await getAIRecommendations(
          mealType: mealType,
          count: 3,
          excludeRecent: true,
        );
        
        if (recommendations.isNotEmpty) {
          // Add variety by rotating through recommendations
          final selectedMeal = recommendations[day % recommendations.length];
          weeklyPlan[dayKey]!.add(selectedMeal);
        }
      }
    }
    
    return weeklyPlan;
  }

  /// Smart meal substitution based on user preferences
  static Future<List<MealModelV3>> getSmartSubstitutions(MealModelV3 originalMeal) async {
    try {
      final preferences = await getUserPreferences();
      final allMeals = await MealServiceV3.getMeals(mealType: originalMeal.mealType);
      
      final substitutions = <Map<String, dynamic>>[];
      
      for (final meal in allMeals) {
        if (meal.id == originalMeal.id) continue;
        
        final similarity = _calculateMealSimilarity(originalMeal, meal, preferences);
        if (similarity > 0.3) { // 30% similarity threshold
          substitutions.add({
            'meal': meal,
            'similarity': similarity,
          });
        }
      }
      
      // Sort by similarity and return top 5
      substitutions.sort((a, b) => b['similarity'].compareTo(a['similarity']));
      return substitutions
          .take(5)
          .map((item) => item['meal'] as MealModelV3)
          .toList();
      
    } catch (e) {
      debugPrint('[AIMealPlannerService] Error getting substitutions: $e');
      return [];
    }
  }

  /// Learn from user behavior and improve recommendations
  static Future<void> updateMealRating(String mealId, double rating) async {
    final history = await getMealHistory();
    
    // Find and update existing rating or add new entry
    bool found = false;
    for (final entry in history) {
      if (entry['mealId'] == mealId) {
        entry['rating'] = rating;
        entry['lastRated'] = DateTime.now().toIso8601String();
        found = true;
        break;
      }
    }
    
    if (!found) {
      // Find the meal and add it to history with rating
      try {
        final meals = await MealServiceV3.getAllMeals();
        final meal = meals.firstWhere((m) => m.id == mealId);
        await trackMealSelection(meal, rating);
      } catch (e) {
        debugPrint('[AIMealPlannerService] Could not find meal for rating: $e');
      }
      return;
    }
    
    // Save updated history
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mealHistoryKey, json.encode(history));
  }

  /// Get nutrition analysis for a meal plan
  static Map<String, double> analyzeNutrition(List<MealModelV3> meals) {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    
    for (final meal in meals) {
      totalCalories += meal.calories;
      totalProtein += meal.protein;
      totalCarbs += meal.carbs;
      totalFat += meal.fat;
    }
    
    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
    };
  }

  /// Check if meals meet user's nutritional goals
  static Future<Map<String, bool>> checkNutritionalGoals(List<MealModelV3> meals) async {
    final preferences = await getUserPreferences();
    final goals = preferences['nutritionGoals'] ?? {};
    final nutrition = analyzeNutrition(meals);
    
    return {
      'calories': _isWithinRange(nutrition['calories']!, goals['calories']?.toDouble() ?? 2000, 0.1),
      'protein': _isWithinRange(nutrition['protein']!, goals['protein']?.toDouble() ?? 150, 0.15),
      'carbs': _isWithinRange(nutrition['carbs']!, goals['carbs']?.toDouble() ?? 200, 0.2),
      'fat': _isWithinRange(nutrition['fat']!, goals['fat']?.toDouble() ?? 65, 0.2),
    };
  }

  // Private helper methods

  /// Score meals based on user preferences and AI algorithm
  static Future<List<Map<String, dynamic>>> _scoreMeals(
    List<MealModelV3> meals,
    Map<String, dynamic> preferences,
    List<Map<String, dynamic>> history,
    bool excludeRecent,
  ) async {
    final scoredMeals = <Map<String, dynamic>>[];
    final recentMealIds = excludeRecent 
        ? history.take(10).map((h) => h['mealId']).toList()
        : <String>[];
    
    for (final meal in meals) {
      // Skip recently selected meals if excludeRecent is true
      if (excludeRecent && recentMealIds.contains(meal.id)) {
        continue;
      }
      
      double score = 0.0;
      
      // Base preference scoring
      score += _scorePreferences(meal, preferences);
      
      // Historical preference scoring
      score += _scoreHistory(meal, history);
      
      // Nutritional goal alignment
      score += _scoreNutrition(meal, preferences);
      
      // Variety bonus (avoid repetitive ingredients)
      score += _scoreVariety(meal, history);
      
      // Add some randomness for discovery
      score += math.Random().nextDouble() * 0.1;
      
      scoredMeals.add({
        'meal': meal,
        'score': score,
      });
    }
    
    return scoredMeals;
  }

  static double _scorePreferences(MealModelV3 meal, Map<String, dynamic> preferences) {
    double score = 0.5; // Base score
    
    final allergies = List<String>.from(preferences['allergies'] ?? []);
    final restrictions = List<String>.from(preferences['dietaryRestrictions'] ?? []);
    final disliked = List<String>.from(preferences['dislikedIngredients'] ?? []);
    
    // Penalize allergens and restrictions heavily
    for (final allergen in allergies) {
      if (meal.allergens.any((a) => a.toLowerCase().contains(allergen.toLowerCase()))) {
        score -= 1.0; // Heavy penalty
      }
    }
    
    // Check dietary restrictions
    if (restrictions.contains('vegetarian') && meal.ingredients.any((i) => 
        ['beef', 'pork', 'chicken', 'fish', 'meat'].any((m) => i.toLowerCase().contains(m)))) {
      score -= 0.8;
    }
    
    if (restrictions.contains('vegan') && meal.ingredients.any((i) => 
        ['dairy', 'cheese', 'milk', 'egg', 'butter', 'meat', 'fish'].any((m) => i.toLowerCase().contains(m)))) {
      score -= 0.8;
    }
    
    // Penalize disliked ingredients
    for (final ingredient in meal.ingredients) {
      if (disliked.any((d) => ingredient.toLowerCase().contains(d.toLowerCase()))) {
        score -= 0.3;
      }
    }
    
    return score;
  }

  static double _scoreHistory(MealModelV3 meal, List<Map<String, dynamic>> history) {
    double score = 0.0;
    
    // Find historical ratings for this meal
    for (final entry in history) {
      if (entry['mealId'] == meal.id && entry['rating'] != null) {
        final rating = (entry['rating'] as num).toDouble();
        score += (rating - 2.5) / 5.0; // Convert 0-5 rating to -0.5 to +0.5
      }
    }
    
    // Boost score for meals with similar highly-rated ingredients
    final likedIngredients = <String>[];
    for (final entry in history) {
      final rating = entry['rating'];
      if (rating != null && rating >= 4.0) {
        final ingredients = List<String>.from(entry['ingredients'] ?? []);
        likedIngredients.addAll(ingredients);
      }
    }
    
    // Boost meals with liked ingredients
    for (final ingredient in meal.ingredients) {
      if (likedIngredients.any((liked) => 
          ingredient.toLowerCase().contains(liked.toLowerCase()))) {
        score += 0.1;
      }
    }
    
    return score;
  }

  static double _scoreNutrition(MealModelV3 meal, Map<String, dynamic> preferences) {
    final goals = preferences['nutritionGoals'] ?? {};
    final targetCalories = (goals['calories'] ?? 2000).toDouble() / 3; // Per meal
    final targetProtein = (goals['protein'] ?? 150).toDouble() / 3;
    
    double score = 0.0;
    
    // Prefer meals closer to caloric targets
    final calorieRatio = meal.calories / targetCalories;
    if (calorieRatio >= 0.8 && calorieRatio <= 1.2) {
      score += 0.2;
    } else if (calorieRatio >= 0.6 && calorieRatio <= 1.4) {
      score += 0.1;
    }
    
    // Prefer meals with good protein content
    final proteinRatio = meal.protein / targetProtein;
    if (proteinRatio >= 0.8) {
      score += 0.15;
    } else if (proteinRatio >= 0.6) {
      score += 0.1;
    }
    
    // Health goals adjustments
    final healthGoals = List<String>.from(preferences['healthGoals'] ?? []);
    if (healthGoals.contains('weight_loss') && meal.calories < targetCalories * 0.8) {
      score += 0.1;
    }
    if (healthGoals.contains('muscle_gain') && meal.protein > targetProtein * 1.2) {
      score += 0.1;
    }
    
    return score;
  }

  static double _scoreVariety(MealModelV3 meal, List<Map<String, dynamic>> history) {
    if (history.isEmpty) return 0.0;
    
    final recentIngredients = <String>[];
    for (final entry in history.take(7)) { // Last 7 meals
      final ingredients = List<String>.from(entry['ingredients'] ?? []);
      recentIngredients.addAll(ingredients);
    }
    
    // Count unique ingredients in this meal
    int uniqueIngredients = 0;
    for (final ingredient in meal.ingredients) {
      if (!recentIngredients.any((recent) => 
          recent.toLowerCase().contains(ingredient.toLowerCase()))) {
        uniqueIngredients++;
      }
    }
    
    // Boost variety
    return (uniqueIngredients / meal.ingredients.length) * 0.15;
  }

  static double _calculateMealSimilarity(MealModelV3 meal1, MealModelV3 meal2, Map<String, dynamic> preferences) {
    double similarity = 0.0;
    
    // Ingredient similarity
    int commonIngredients = 0;
    for (final ingredient1 in meal1.ingredients) {
      if (meal2.ingredients.any((ingredient2) => 
          ingredient1.toLowerCase().contains(ingredient2.toLowerCase()) ||
          ingredient2.toLowerCase().contains(ingredient1.toLowerCase()))) {
        commonIngredients++;
      }
    }
    
    final maxIngredients = math.max(meal1.ingredients.length, meal2.ingredients.length);
    similarity += (commonIngredients / maxIngredients) * 0.4;
    
    // Nutritional similarity
    final calorieDiff = (meal1.calories - meal2.calories).abs() / math.max(meal1.calories, meal2.calories);
    final proteinDiff = (meal1.protein - meal2.protein).abs() / math.max(meal1.protein, meal2.protein);
    
    similarity += (1.0 - calorieDiff) * 0.2;
    similarity += (1.0 - proteinDiff) * 0.2;
    
    // Allergen compatibility
    bool allergenMatch = true;
    for (final allergen in meal1.allergens) {
      if (!meal2.allergens.contains(allergen)) {
        allergenMatch = false;
        break;
      }
    }
    if (allergenMatch) similarity += 0.2;
    
    return similarity;
  }

  static bool _isWithinRange(double actual, double target, double tolerance) {
    final lowerBound = target * (1 - tolerance);
    final upperBound = target * (1 + tolerance);
    return actual >= lowerBound && actual <= upperBound;
  }

  static String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
