import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/meal.dart';

class MealDataImporter {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Import meals from JSON file
  /// 
  /// Usage: Copy your gofresh_meals_final.json to assets/data/meals.json
  /// Then call this method from admin panel
  static Future<void> importMealsFromJson(String jsonFilePath) async {
    try {
      // Read the JSON file
      final file = File(jsonFilePath);
      if (!await file.exists()) {
        throw Exception('JSON file not found at path: $jsonFilePath');
      }

      final jsonString = await file.readAsString();
      final jsonData = json.decode(jsonString);
      
      // Parse meals from JSON
      List<Meal> meals = [];
      
      if (jsonData is List) {
        // If JSON is an array of meals
        meals = jsonData.map((mealJson) => _parseMealFromJson(mealJson)).toList();
      } else if (jsonData is Map<String, dynamic> && jsonData.containsKey('meals')) {
        // If JSON has a 'meals' key containing the array
        final mealsArray = jsonData['meals'] as List;
        meals = mealsArray.map((mealJson) => _parseMealFromJson(mealJson)).toList();
      } else {
        throw Exception('Unexpected JSON format. Expected array or object with "meals" key.');
      }

      debugPrint('Parsed ${meals.length} meals from JSON');

      // Import to Firestore
      await _importMealsToFirestore(meals);
      
      debugPrint('Successfully imported ${meals.length} meals to Firestore');
      
    } catch (e) {
      debugPrint('Error importing meals: $e');
      rethrow;
    }
  }

  /// Parse a single meal from JSON object
  static Meal _parseMealFromJson(Map<String, dynamic> json) {
    // Default values for required fields
    final id = json['id']?.toString() ?? 'meal_${DateTime.now().millisecondsSinceEpoch}';
    final name = json['name']?.toString() ?? 'Unnamed Meal';
    final description = json['description']?.toString() ?? 'No description available';
    
    // Try to determine meal type from various possible fields
    MealType mealType = MealType.lunch; // default
    final typeString = (json['type'] ?? json['meal_type'] ?? json['category'] ?? 'lunch').toString().toLowerCase();
    
    if (typeString.contains('breakfast')) {
      mealType = MealType.breakfast;
    } else if (typeString.contains('lunch')) {
      mealType = MealType.lunch;
    } else if (typeString.contains('dinner') || typeString.contains('supper')) {
      mealType = MealType.dinner;
    } else if (typeString.contains('snack')) {
      // Map snacks to lunch category since we only have 3 meal types
      mealType = MealType.lunch;
    }

    // Parse price (try different possible field names)
    double price = 0.0;
    final priceValue = json['price'] ?? json['cost'] ?? json['amount'] ?? 15.99;
    if (priceValue is String) {
      price = double.tryParse(priceValue.replaceAll(RegExp(r'[^\d.]'), '')) ?? 15.99;
    } else if (priceValue is num) {
      price = priceValue.toDouble();
    }

    // Parse ingredients
    List<String> ingredients = [];
    final ingredientsData = json['ingredients'] ?? json['components'] ?? [];
    if (ingredientsData is List) {
      ingredients = ingredientsData.map((e) => e.toString()).toList();
    } else if (ingredientsData is String) {
      ingredients = ingredientsData.split(',').map((e) => e.trim()).toList();
    }

    // Parse allergens/allergies
    List<String> allergyWarnings = [];
    final allergensData = json['allergens'] ?? json['allergies'] ?? json['allergy_warnings'] ?? [];
    if (allergensData is List) {
      allergyWarnings = allergensData.map((e) => e.toString()).toList();
    } else if (allergensData is String) {
      allergyWarnings = allergensData.split(',').map((e) => e.trim()).toList();
    }

    // Parse nutrition info
    final nutritionData = json['nutrition'] ?? json['nutritional_info'] ?? {};
    final nutrition = NutritionInfo(
      calories: (_parseDouble(nutritionData['calories']) ?? 400.0).round(),
      protein: _parseDouble(nutritionData['protein']) ?? 20.0,
      carbohydrates: _parseDouble(nutritionData['carbohydrates'] ?? nutritionData['carbs']) ?? 40.0,
      fat: _parseDouble(nutritionData['fat'] ?? nutritionData['fats']) ?? 15.0,
      fiber: _parseDouble(nutritionData['fiber'] ?? nutritionData['fibre']) ?? 5.0,
      sugar: _parseDouble(nutritionData['sugar'] ?? nutritionData['sugars']) ?? 10.0,
      sodium: _parseDouble(nutritionData['sodium']) ?? 800.0,
    );

    // Image URL - try different field names
    String imageUrl = '';
    final imageData = json['image'] ?? json['image_url'] ?? json['photo'] ?? json['picture'];
    if (imageData != null) {
      imageUrl = imageData.toString();
    }
    
    // If no image, use a default food image from Unsplash
    if (imageUrl.isEmpty) {
      imageUrl = 'https://images.unsplash.com/photo-1546548970-71785318a17b?w=300'; // default food image
    }

    return Meal(
      id: id,
      name: name,
      description: description,
      imageUrl: imageUrl,
      mealType: mealType,
      price: price,
      ingredients: ingredients,
      allergyWarnings: allergyWarnings,
      nutrition: nutrition,
      isAvailable: json['available'] == false ? false : true, // default to available
      isPopular: json['popular'] == true || json['featured'] == true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Helper to parse double values safely
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), ''));
    }
    return null;
  }

  /// Import meals to Firestore
  static Future<void> _importMealsToFirestore(List<Meal> meals) async {
    final batch = _firestore.batch();
    
    for (final meal in meals) {
      final docRef = _firestore.collection('meals').doc(meal.id);
      batch.set(docRef, meal.toMap());
    }
    
    await batch.commit();
  }

  /// Quick test method with sample data
  static Future<void> importSampleMeals() async {
    final sampleMeals = [
      {
        "id": "nyc_breakfast_1",
        "name": "NYC Style Bagel with Lox",
        "description": "Everything bagel with cream cheese, smoked salmon, capers, and red onion",
        "type": "breakfast",
        "price": 18.99,
        "ingredients": ["Everything bagel", "Cream cheese", "Smoked salmon", "Capers", "Red onion", "Dill"],
        "allergens": ["Gluten", "Dairy", "Fish"],
        "nutrition": {
          "calories": 420,
          "protein": 25,
          "carbohydrates": 35,
          "fat": 22,
          "fiber": 3,
          "sugar": 4,
          "sodium": 980
        },
        "available": true,
        "popular": true
      },
      {
        "id": "nyc_lunch_1", 
        "name": "Manhattan Power Bowl",
        "description": "Quinoa bowl with grilled chicken, kale, avocado, and tahini dressing",
        "type": "lunch",
        "price": 16.99,
        "ingredients": ["Quinoa", "Grilled chicken", "Kale", "Avocado", "Cherry tomatoes", "Tahini", "Lemon"],
        "allergens": ["Sesame"],
        "nutrition": {
          "calories": 485,
          "protein": 32,
          "carbohydrates": 38,
          "fat": 24,
          "fiber": 8,
          "sugar": 6,
          "sodium": 720
        },
        "available": true,
        "popular": false
      }
    ];

    final meals = sampleMeals.map((json) => _parseMealFromJson(json)).toList();
    await _importMealsToFirestore(meals);
    debugPrint('Sample NYC meals imported successfully!');
  }
}
