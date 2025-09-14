import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/meal_model_v3.dart';
import '../services/firestore_service_v3.dart';
import '../services/meal_service_v3.dart';

/// AI-powered meal recommendation service that processes AI chat data
/// and creates optimized meal plans from existing meal database
class AIMealRecommendationService {
  static const String _aiServiceUrl = 'https://flutterapplication1-production.up.railway.app';
  
  /// Process AI chat completion and generate meal recommendations
  static Future<AIMealPlan> processAIChatCompletion({
    required String userId,
    required Map<String, dynamic> aiProfile,
    required String goal,
    required List<String> preferences,
    required List<String> allergies,
    required int mealsPerDay,
  }) async {
    try {
      // Load available meals from database
      final availableMeals = await MealServiceV3.getAllMeals();
      
      // Get AI recommendations based on user profile
      final aiRecommendations = await _getAIMealRecommendations(
        userId: userId,
        profile: aiProfile,
        availableMeals: availableMeals,
        mealsPerDay: mealsPerDay,
      );
      
      // Map AI recommendations to actual meals
      final recommendedMeals = await _mapAIRecommendationsToMeals(
        aiRecommendations,
        availableMeals,
      );
      
      // Create optimized schedule
      final schedule = _createOptimizedSchedule(
        meals: recommendedMeals,
        mealsPerDay: mealsPerDay,
        goal: goal,
      );
      
      // Save user profile to Firebase
      await _saveUserProfileToFirebase(userId, {
        'aiProfile': aiProfile,
        'goal': goal,
        'preferences': preferences,
        'allergies': allergies,
        'mealsPerDay': mealsPerDay,
        'lastUpdated': DateTime.now().toIso8601String(),
      });
      
      return AIMealPlan(
        userId: userId,
        meals: recommendedMeals,
        schedule: schedule,
        goal: goal,
        mealsPerDay: mealsPerDay,
        preferences: preferences,
        allergies: allergies,
        nutritionSummary: _calculateNutritionSummary(recommendedMeals),
        createdAt: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('Error processing AI chat completion: $e');
      rethrow;
    }
  }
  
  /// Get AI recommendations from the chat service
  static Future<List<Map<String, dynamic>>> _getAIMealRecommendations({
    required String userId,
    required Map<String, dynamic> profile,
    required List<MealModelV3> availableMeals,
    required int mealsPerDay,
  }) async {
    try {
      // Create meal context for AI
      final mealContext = availableMeals.map((meal) => {
        'id': meal.id,
        'name': meal.name,
        'calories': meal.calories,
        'protein': meal.protein,
        'carbs': meal.carbs,
        'fat': meal.fat,
      }).toList();
      
      final response = await http.post(
        Uri.parse('$_aiServiceUrl/api/generate-meal-plan'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': userId,
          'profile': profile,
          'availableMeals': mealContext,
          'mealsPerDay': mealsPerDay,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['recommendations'] ?? []);
      } else {
        throw Exception('Failed to get AI recommendations');
      }
    } catch (e) {
      debugPrint('Error getting AI recommendations: $e');
      // Fallback to basic recommendations
      return _getFallbackRecommendations(availableMeals, mealsPerDay);
    }
  }
  
  /// Map AI recommendations to actual meal objects
  static Future<List<MealModelV3>> _mapAIRecommendationsToMeals(
    List<Map<String, dynamic>> recommendations,
    List<MealModelV3> availableMeals,
  ) async {
    final selectedMeals = <MealModelV3>[];
    
    for (final rec in recommendations) {
      final mealId = rec['mealId'];
      final meal = availableMeals.firstWhere(
        (m) => m.id == mealId,
        orElse: () => availableMeals[Random().nextInt(availableMeals.length)],
      );
      selectedMeals.add(meal);
    }
    
    return selectedMeals;
  }
  
  /// Create optimized delivery and meal schedule
  static AIMealSchedule _createOptimizedSchedule({
    required List<MealModelV3> meals,
    required int mealsPerDay,
    required String goal,
  }) {
    final mealTimes = _getOptimalMealTimes(mealsPerDay, goal);
    final deliveryDays = _getOptimalDeliveryDays();
    
    return AIMealSchedule(
      mealsPerDay: mealsPerDay,
      mealTimes: mealTimes,
      deliveryDays: deliveryDays,
      weeklyMeals: _distributeWeeklyMeals(meals, mealsPerDay),
    );
  }
  
  /// Get optimal meal times based on goals
  static List<String> _getOptimalMealTimes(int mealsPerDay, String goal) {
    switch (mealsPerDay) {
      case 2:
        return ['12:00 PM', '7:00 PM']; // Intermittent fasting friendly
      case 3:
        return ['8:00 AM', '1:00 PM', '7:00 PM']; // Standard 3 meals
      case 4:
        return ['8:00 AM', '12:00 PM', '4:00 PM', '8:00 PM']; // Frequent meals
      case 5:
        return ['7:00 AM', '10:00 AM', '1:00 PM', '4:00 PM', '7:00 PM']; // Bodybuilding
      case 6:
        return ['7:00 AM', '9:30 AM', '12:00 PM', '3:00 PM', '6:00 PM', '8:30 PM']; // High frequency
      default:
        return ['8:00 AM', '1:00 PM', '7:00 PM'];
    }
  }
  
  /// Get optimal delivery schedule
  static List<String> _getOptimalDeliveryDays() {
    return ['Monday', 'Wednesday', 'Friday']; // Default 3x/week delivery
  }
  
  /// Distribute meals across the week
  static Map<String, List<MealModelV3>> _distributeWeeklyMeals(
    List<MealModelV3> meals,
    int mealsPerDay,
  ) {
    final weekDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final weeklyMeals = <String, List<MealModelV3>>{};
    
    for (int day = 0; day < weekDays.length; day++) {
      final dayMeals = <MealModelV3>[];
      for (int meal = 0; meal < mealsPerDay; meal++) {
        final mealIndex = (day * mealsPerDay + meal) % meals.length;
        dayMeals.add(meals[mealIndex]);
      }
      weeklyMeals[weekDays[day]] = dayMeals;
    }
    
    return weeklyMeals;
  }
  
  /// Calculate nutrition summary
  static Map<String, double> _calculateNutritionSummary(List<MealModelV3> meals) {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;
    
    for (final meal in meals) {
      totalCalories += meal.calories.toDouble();
      totalProtein += meal.protein.toDouble();
      totalCarbs += meal.carbs.toDouble();
      totalFat += meal.fat.toDouble();
    }
    
    return {
      'calories': totalCalories,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFat,
    };
  }
  
  /// Save user profile to Firebase
  static Future<void> _saveUserProfileToFirebase(String userId, Map<String, dynamic> profile) async {
    try {
      await FirestoreServiceV3.updateUserProfile(userId, {
        'aiProfile': profile,
        'lastAIUpdate': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving user profile: $e');
    }
  }
  
  /// Fallback recommendations if AI service fails
  static List<Map<String, dynamic>> _getFallbackRecommendations(
    List<MealModelV3> availableMeals,
    int mealsPerDay,
  ) {
    final random = Random();
    final recommendations = <Map<String, dynamic>>[];
    
    for (int i = 0; i < mealsPerDay * 7; i++) {
      final meal = availableMeals[random.nextInt(availableMeals.length)];
      recommendations.add({
        'mealId': meal.id,
        'reason': 'Variety selection',
        'score': 0.8,
      });
    }
    
    return recommendations;
  }
}

/// AI Meal Plan data structure
class AIMealPlan {
  final String userId;
  final List<MealModelV3> meals;
  final AIMealSchedule schedule;
  final String goal;
  final int mealsPerDay;
  final List<String> preferences;
  final List<String> allergies;
  final Map<String, double> nutritionSummary;
  final DateTime createdAt;
  
  AIMealPlan({
    required this.userId,
    required this.meals,
    required this.schedule,
    required this.goal,
    required this.mealsPerDay,
    required this.preferences,
    required this.allergies,
    required this.nutritionSummary,
    required this.createdAt,
  });
  
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'meals': meals.map((m) => m.toJson()).toList(),
    'schedule': schedule.toJson(),
    'goal': goal,
    'mealsPerDay': mealsPerDay,
    'preferences': preferences,
    'allergies': allergies,
    'nutritionSummary': nutritionSummary,
    'createdAt': createdAt.toIso8601String(),
  };
}

/// AI Meal Schedule data structure
class AIMealSchedule {
  final int mealsPerDay;
  final List<String> mealTimes;
  final List<String> deliveryDays;
  final Map<String, List<MealModelV3>> weeklyMeals;
  
  AIMealSchedule({
    required this.mealsPerDay,
    required this.mealTimes,
    required this.deliveryDays,
    required this.weeklyMeals,
  });
  
  Map<String, dynamic> toJson() => {
    'mealsPerDay': mealsPerDay,
    'mealTimes': mealTimes,
    'deliveryDays': deliveryDays,
    'weeklyMeals': weeklyMeals.map(
      (day, meals) => MapEntry(day, meals.map((m) => m.toJson()).toList()),
    ),
  };
}
