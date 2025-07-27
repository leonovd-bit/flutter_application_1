import 'meal.dart';

class MealSchedule {
  final String id;
  final String userId;
  final String scheduleName;
  final List<String> deliveryDays;
  final String deliveryTime;
  final String deliveryAddressId;
  final bool isActive;
  final Map<String, DailyMeals> weeklyMeals; // date -> meals
  final DateTime createdAt;
  final DateTime updatedAt;

  MealSchedule({
    required this.id,
    required this.userId,
    required this.scheduleName,
    required this.deliveryDays,
    required this.deliveryTime,
    required this.deliveryAddressId,
    this.isActive = true,
    required this.weeklyMeals,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'scheduleName': scheduleName,
      'deliveryDays': deliveryDays,
      'deliveryTime': deliveryTime,
      'deliveryAddressId': deliveryAddressId,
      'isActive': isActive,
      'weeklyMeals': weeklyMeals.map((key, value) => MapEntry(key, value.toMap())),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MealSchedule.fromMap(Map<String, dynamic> map) {
    final weeklyMealsMap = map['weeklyMeals'] as Map<String, dynamic>? ?? {};
    final weeklyMeals = weeklyMealsMap.map(
      (key, value) => MapEntry(key, DailyMeals.fromMap(value as Map<String, dynamic>)),
    );

    return MealSchedule(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      scheduleName: map['scheduleName'] ?? '',
      deliveryDays: List<String>.from(map['deliveryDays'] ?? []),
      deliveryTime: map['deliveryTime'] ?? '',
      deliveryAddressId: map['deliveryAddressId'] ?? '',
      isActive: map['isActive'] ?? true,
      weeklyMeals: weeklyMeals,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  MealSchedule copyWith({
    String? id,
    String? userId,
    String? scheduleName,
    List<String>? deliveryDays,
    String? deliveryTime,
    String? deliveryAddressId,
    bool? isActive,
    Map<String, DailyMeals>? weeklyMeals,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MealSchedule(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      scheduleName: scheduleName ?? this.scheduleName,
      deliveryDays: deliveryDays ?? this.deliveryDays,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      deliveryAddressId: deliveryAddressId ?? this.deliveryAddressId,
      isActive: isActive ?? this.isActive,
      weeklyMeals: weeklyMeals ?? this.weeklyMeals,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DailyMeals {
  final List<String> breakfastMealIds;
  final List<String> lunchMealIds;
  final List<String> dinnerMealIds;

  DailyMeals({
    this.breakfastMealIds = const [],
    this.lunchMealIds = const [],
    this.dinnerMealIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'breakfastMealIds': breakfastMealIds,
      'lunchMealIds': lunchMealIds,
      'dinnerMealIds': dinnerMealIds,
    };
  }

  factory DailyMeals.fromMap(Map<String, dynamic> map) {
    return DailyMeals(
      breakfastMealIds: List<String>.from(map['breakfastMealIds'] ?? []),
      lunchMealIds: List<String>.from(map['lunchMealIds'] ?? []),
      dinnerMealIds: List<String>.from(map['dinnerMealIds'] ?? []),
    );
  }

  List<String> getMealsByType(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return breakfastMealIds;
      case MealType.lunch:
        return lunchMealIds;
      case MealType.dinner:
        return dinnerMealIds;
    }
  }

  DailyMeals copyWith({
    List<String>? breakfastMealIds,
    List<String>? lunchMealIds,
    List<String>? dinnerMealIds,
  }) {
    return DailyMeals(
      breakfastMealIds: breakfastMealIds ?? this.breakfastMealIds,
      lunchMealIds: lunchMealIds ?? this.lunchMealIds,
      dinnerMealIds: dinnerMealIds ?? this.dinnerMealIds,
    );
  }

  int get totalMeals => breakfastMealIds.length + lunchMealIds.length + dinnerMealIds.length;
}
