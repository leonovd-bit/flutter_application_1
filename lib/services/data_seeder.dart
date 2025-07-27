import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/meal.dart';

class DataSeeder {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> seedMeals() async {
    final meals = [
      // Breakfast meals
      Meal(
        id: 'breakfast_1',
        name: 'Avocado Toast with Eggs',
        description: 'Whole grain bread topped with smashed avocado and scrambled eggs',
        imageUrl: 'https://images.unsplash.com/photo-1541519227354-08fa5d50c44d?w=300',
        mealType: MealType.breakfast,
        price: 12.99,
        ingredients: ['Whole grain bread', 'Avocado', 'Eggs', 'Salt', 'Pepper', 'Olive oil'],
        allergyWarnings: ['Gluten', 'Eggs'],
        nutrition: NutritionInfo(
          calories: 380,
          protein: 18.5,
          carbohydrates: 28.0,
          fat: 22.0,
          fiber: 12.0,
          sugar: 3.0,
          sodium: 450.0,
        ),
        isAvailable: true,
        isPopular: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      
      Meal(
        id: 'breakfast_2',
        name: 'Greek Yogurt Parfait',
        description: 'Creamy Greek yogurt layered with fresh berries and granola',
        imageUrl: 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=300',
        mealType: MealType.breakfast,
        price: 9.99,
        ingredients: ['Greek yogurt', 'Blueberries', 'Strawberries', 'Granola', 'Honey'],
        allergyWarnings: ['Dairy', 'Nuts'],
        nutrition: NutritionInfo(
          calories: 280,
          protein: 15.0,
          carbohydrates: 35.0,
          fat: 8.0,
          fiber: 6.0,
          sugar: 22.0,
          sodium: 120.0,
        ),
        isAvailable: true,
        isPopular: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),

      Meal(
        id: 'breakfast_3',
        name: 'Protein Smoothie Bowl',
        description: 'Thick smoothie bowl topped with fresh fruits and seeds',
        imageUrl: 'https://images.unsplash.com/photo-1511690743698-d9d85f2fbf38?w=300',
        mealType: MealType.breakfast,
        price: 11.99,
        ingredients: ['Banana', 'Protein powder', 'Almond milk', 'Chia seeds', 'Coconut flakes'],
        allergyWarnings: ['Nuts'],
        nutrition: NutritionInfo(
          calories: 320,
          protein: 25.0,
          carbohydrates: 30.0,
          fat: 12.0,
          fiber: 8.0,
          sugar: 18.0,
          sodium: 200.0,
        ),
        isAvailable: true,
        isPopular: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),

      // Lunch meals
      Meal(
        id: 'lunch_1',
        name: 'Mediterranean Quinoa Bowl',
        description: 'Fresh quinoa bowl with grilled chicken, vegetables, and tahini dressing',
        imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=300',
        mealType: MealType.lunch,
        price: 16.99,
        ingredients: ['Quinoa', 'Grilled chicken', 'Cucumber', 'Tomatoes', 'Olives', 'Feta cheese', 'Tahini'],
        allergyWarnings: ['Dairy', 'Sesame'],
        nutrition: NutritionInfo(
          calories: 520,
          protein: 35.0,
          carbohydrates: 45.0,
          fat: 22.0,
          fiber: 8.0,
          sugar: 8.0,
          sodium: 680.0,
        ),
        isAvailable: true,
        isPopular: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),

      Meal(
        id: 'lunch_2',
        name: 'Asian Sesame Salad',
        description: 'Mixed greens with crispy tofu, edamame, and sesame ginger dressing',
        imageUrl: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=300',
        mealType: MealType.lunch,
        price: 14.99,
        ingredients: ['Mixed greens', 'Crispy tofu', 'Edamame', 'Carrots', 'Red cabbage', 'Sesame dressing'],
        allergyWarnings: ['Soy', 'Sesame'],
        nutrition: NutritionInfo(
          calories: 420,
          protein: 18.0,
          carbohydrates: 32.0,
          fat: 26.0,
          fiber: 12.0,
          sugar: 12.0,
          sodium: 580.0,
        ),
        isAvailable: true,
        isPopular: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),

      Meal(
        id: 'lunch_3',
        name: 'Turkey & Avocado Wrap',
        description: 'Whole wheat wrap filled with lean turkey, avocado, and fresh vegetables',
        imageUrl: 'https://images.unsplash.com/photo-1565299507177-b0ac66763828?w=300',
        mealType: MealType.lunch,
        price: 13.99,
        ingredients: ['Whole wheat tortilla', 'Turkey breast', 'Avocado', 'Lettuce', 'Tomatoes', 'Hummus'],
        allergyWarnings: ['Gluten', 'Sesame'],
        nutrition: NutritionInfo(
          calories: 460,
          protein: 28.0,
          carbohydrates: 38.0,
          fat: 22.0,
          fiber: 10.0,
          sugar: 6.0,
          sodium: 720.0,
        ),
        isAvailable: true,
        isPopular: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),

      // Dinner meals
      Meal(
        id: 'dinner_1',
        name: 'Grilled Salmon with Vegetables',
        description: 'Fresh Atlantic salmon with roasted seasonal vegetables and quinoa',
        imageUrl: 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=300',
        mealType: MealType.dinner,
        price: 22.99,
        ingredients: ['Atlantic salmon', 'Broccoli', 'Sweet potato', 'Quinoa', 'Lemon', 'Herbs'],
        allergyWarnings: ['Fish'],
        nutrition: NutritionInfo(
          calories: 580,
          protein: 42.0,
          carbohydrates: 35.0,
          fat: 28.0,
          fiber: 8.0,
          sugar: 8.0,
          sodium: 420.0,
        ),
        isAvailable: true,
        isPopular: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),

      Meal(
        id: 'dinner_2',
        name: 'Vegetarian Buddha Bowl',
        description: 'Colorful bowl with roasted vegetables, chickpeas, and tahini sauce',
        imageUrl: 'https://images.unsplash.com/photo-1490645935967-10de6ba17061?w=300',
        mealType: MealType.dinner,
        price: 18.99,
        ingredients: ['Brown rice', 'Roasted chickpeas', 'Roasted vegetables', 'Kale', 'Tahini sauce'],
        allergyWarnings: ['Sesame'],
        nutrition: NutritionInfo(
          calories: 520,
          protein: 20.0,
          carbohydrates: 65.0,
          fat: 18.0,
          fiber: 15.0,
          sugar: 12.0,
          sodium: 380.0,
        ),
        isAvailable: true,
        isPopular: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),

      Meal(
        id: 'dinner_3',
        name: 'Lean Beef Stir Fry',
        description: 'Tender beef strips with mixed vegetables in a savory sauce over brown rice',
        imageUrl: 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=300',
        mealType: MealType.dinner,
        price: 20.99,
        ingredients: ['Lean beef', 'Bell peppers', 'Snap peas', 'Carrots', 'Brown rice', 'Stir fry sauce'],
        allergyWarnings: ['Soy'],
        nutrition: NutritionInfo(
          calories: 610,
          protein: 38.0,
          carbohydrates: 48.0,
          fat: 25.0,
          fiber: 6.0,
          sugar: 12.0,
          sodium: 780.0,
        ),
        isAvailable: true,
        isPopular: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    try {
      for (final meal in meals) {
        await _firestore.collection('meals').doc(meal.id).set(meal.toMap());
      }
      print('Successfully seeded ${meals.length} meals to Firestore');
    } catch (e) {
      print('Error seeding meals: $e');
    }
  }

  static Future<void> deleteAllMeals() async {
    try {
      final querySnapshot = await _firestore.collection('meals').get();
      for (final doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
      print('Successfully deleted all meals from Firestore');
    } catch (e) {
      print('Error deleting meals: $e');
    }
  }
}
