class Meal {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final MealType mealType;
  final double price;
  final List<String> ingredients;
  final List<String> allergyWarnings;
  final NutritionInfo nutrition;
  final bool isAvailable;
  final bool isPopular;
  final DateTime createdAt;
  final DateTime updatedAt;

  Meal({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.mealType,
    required this.price,
    required this.ingredients,
    required this.allergyWarnings,
    required this.nutrition,
    this.isAvailable = true,
    this.isPopular = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'mealType': mealType.toString(),
      'price': price,
      'ingredients': ingredients,
      'allergyWarnings': allergyWarnings,
      'nutrition': nutrition.toMap(),
      'isAvailable': isAvailable,
      'isPopular': isPopular,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Meal.fromMap(Map<String, dynamic> map) {
    return Meal(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      mealType: MealType.values.firstWhere(
        (e) => e.toString() == map['mealType'],
        orElse: () => MealType.lunch,
      ),
      price: (map['price'] ?? 0.0).toDouble(),
      ingredients: List<String>.from(map['ingredients'] ?? []),
      allergyWarnings: List<String>.from(map['allergyWarnings'] ?? []),
      nutrition: NutritionInfo.fromMap(map['nutrition'] ?? {}),
      isAvailable: map['isAvailable'] ?? true,
      isPopular: map['isPopular'] ?? false,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }
}

enum MealType {
  breakfast,
  lunch,
  dinner,
}

extension MealTypeExtension on MealType {
  String get displayName {
    switch (this) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
    }
  }
}

class NutritionInfo {
  final int calories;
  final double protein; // grams
  final double carbohydrates; // grams
  final double fat; // grams
  final double fiber; // grams
  final double sugar; // grams
  final double sodium; // mg

  NutritionInfo({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
    required this.sugar,
    required this.sodium,
  });

  Map<String, dynamic> toMap() {
    return {
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fat': fat,
      'fiber': fiber,
      'sugar': sugar,
      'sodium': sodium,
    };
  }

  factory NutritionInfo.fromMap(Map<String, dynamic> map) {
    return NutritionInfo(
      calories: map['calories'] ?? 0,
      protein: (map['protein'] ?? 0.0).toDouble(),
      carbohydrates: (map['carbohydrates'] ?? 0.0).toDouble(),
      fat: (map['fat'] ?? 0.0).toDouble(),
      fiber: (map['fiber'] ?? 0.0).toDouble(),
      sugar: (map['sugar'] ?? 0.0).toDouble(),
      sodium: (map['sodium'] ?? 0.0).toDouble(),
    );
  }
}
