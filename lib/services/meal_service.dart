import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meal.dart';

class MealService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'meals';

  // Get all meals
  static Future<List<Meal>> getAllMeals() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isAvailable', isEqualTo: true)
          .orderBy('name')
          .get();

      return querySnapshot.docs
          .map((doc) => Meal.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get meals: $e');
    }
  }

  // Get meals by type
  static Future<List<Meal>> getMealsByType(MealType mealType) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('mealType', isEqualTo: mealType.toString())
          .where('isAvailable', isEqualTo: true)
          .orderBy('isPopular', descending: true)
          .orderBy('name')
          .get();

      return querySnapshot.docs
          .map((doc) => Meal.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get meals by type: $e');
    }
  }

  // Get meal by ID
  static Future<Meal?> getMeal(String mealId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(mealId).get();
      if (doc.exists && doc.data() != null) {
        return Meal.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get meal: $e');
    }
  }

  // Get multiple meals by IDs
  static Future<List<Meal>> getMealsByIds(List<String> mealIds) async {
    if (mealIds.isEmpty) return [];
    
    try {
      final meals = <Meal>[];
      
      // Firestore 'in' queries are limited to 10 items, so we need to batch
      for (int i = 0; i < mealIds.length; i += 10) {
        final batch = mealIds.skip(i).take(10).toList();
        final querySnapshot = await _firestore
            .collection(_collection)
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        
        meals.addAll(
          querySnapshot.docs.map((doc) => Meal.fromMap(doc.data())),
        );
      }
      
      return meals;
    } catch (e) {
      throw Exception('Failed to get meals by IDs: $e');
    }
  }

  // Get popular meals
  static Future<List<Meal>> getPopularMeals({int limit = 10}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isAvailable', isEqualTo: true)
          .where('isPopular', isEqualTo: true)
          .orderBy('name')
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => Meal.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get popular meals: $e');
    }
  }

  // Search meals
  static Future<List<Meal>> searchMeals(String query) async {
    try {
      // Note: This is a simple search. For more advanced search, consider using Algolia or similar
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isAvailable', isEqualTo: true)
          .orderBy('name')
          .get();

      final meals = querySnapshot.docs
          .map((doc) => Meal.fromMap(doc.data()))
          .where((meal) =>
              meal.name.toLowerCase().contains(query.toLowerCase()) ||
              meal.description.toLowerCase().contains(query.toLowerCase()) ||
              meal.ingredients.any((ingredient) =>
                  ingredient.toLowerCase().contains(query.toLowerCase())))
          .toList();

      return meals;
    } catch (e) {
      throw Exception('Failed to search meals: $e');
    }
  }

  // Get random meals for auto-selection
  static Future<List<Meal>> getRandomMealsByType(MealType mealType, int count) async {
    try {
      final allMeals = await getMealsByType(mealType);
      allMeals.shuffle();
      return allMeals.take(count).toList();
    } catch (e) {
      throw Exception('Failed to get random meals: $e');
    }
  }

  // Stream meals by type
  static Stream<List<Meal>> streamMealsByType(MealType mealType) {
    return _firestore
        .collection(_collection)
        .where('mealType', isEqualTo: mealType.toString())
        .where('isAvailable', isEqualTo: true)
        .orderBy('isPopular', descending: true)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Meal.fromMap(doc.data()))
            .toList());
  }

  // Admin functions (for meal management)
  static Future<String> createMeal(Meal meal) async {
    try {
      final docRef = await _firestore.collection(_collection).add(meal.toMap());
      await docRef.update({'id': docRef.id});
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create meal: $e');
    }
  }

  static Future<void> updateMeal(Meal meal) async {
    try {
      await _firestore.collection(_collection).doc(meal.id).update(meal.toMap());
    } catch (e) {
      throw Exception('Failed to update meal: $e');
    }
  }

  static Future<void> deleteMeal(String mealId) async {
    try {
      await _firestore.collection(_collection).doc(mealId).delete();
    } catch (e) {
      throw Exception('Failed to delete meal: $e');
    }
  }
}
