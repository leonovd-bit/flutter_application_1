import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum MealPlanType {
  standard,
  pro,
  premium,
}

class MealModelV3 {
  final String id;
  final String name;
  final String description;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final List<String> ingredients;
  final List<String> allergens;
  final IconData icon;
  final String imageUrl;
  final String mealType; // breakfast, lunch, dinner
  final double price;
  // Optional metadata
  final String? restaurant; // e.g., Greenblend, Sen Saigon
  final String? menuCategory; // 'premade' or 'custom'

  // Getter for compatibility with interactive menu
  String get type => mealType;

  // Get image path - returns asset path if imageUrl is empty
  String get imagePath {
    if (imageUrl.isNotEmpty) {
      return imageUrl;
    }
    
    // Generate asset path from meal name using slug logic
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), '-')
        .replaceAll(RegExp(r"(^-|-$)"), '');
    
    return 'assets/images/meals/$slug.jpg';
  }

  MealModelV3({
    required this.id,
    required this.name,
    required this.description,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.ingredients,
    required this.allergens,
    required this.icon,
    this.imageUrl = '',
    this.mealType = 'breakfast',
    this.price = 0.0,
    this.restaurant,
    this.menuCategory,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'ingredients': ingredients,
      'allergens': allergens,
      'imageUrl': imageUrl,
      'mealType': mealType,
      'price': price,
      if (restaurant != null) 'restaurant': restaurant,
      if (menuCategory != null) 'menuCategory': menuCategory,
    };
  }

  Map<String, dynamic> toFirestore() {
    return toJson();
  }

  factory MealModelV3.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MealModelV3.fromJson(data);
  }

  factory MealModelV3.fromJson(Map<String, dynamic> json) {
    final name = json['name'] ?? '';
    final imageUrl = json['imageUrl'] ?? '';
    
    // Debug what we're getting from Firestore
    print('🔄 Loading meal from JSON: $name');
    print('   📦 Raw imageUrl from Firestore: "$imageUrl"');
    
    final meal = MealModelV3(
      id: json['id'] ?? '',
      name: name,
      description: json['description'] ?? '',
      calories: json['calories'] ?? 0,
      protein: json['protein'] ?? 0,
      carbs: json['carbs'] ?? 0,
      fat: json['fat'] ?? 0,
      ingredients: List<String>.from(json['ingredients'] ?? []),
      allergens: List<String>.from(json['allergens'] ?? []),
      imageUrl: imageUrl,
      mealType: json['mealType'] ?? 'breakfast',
      price: json['price']?.toDouble() ?? 0.0,
      icon: Icons.fastfood, // Default icon since IconData can't be serialized
      restaurant: json['restaurant'],
      menuCategory: json['menuCategory'],
    );
    
    print('   📁 Final imagePath: "${meal.imagePath}"');
    return meal;
  }

  static List<MealModelV3> getSampleMeals() {
    return [
      // Breakfast meals
      MealModelV3(
        id: 'b1',
        name: 'Avocado Toast & Eggs',
        description: 'Whole grain toast topped with fresh avocado and scrambled eggs',
        calories: 420,
        protein: 18,
        carbs: 35,
        fat: 24,
        ingredients: ['Whole grain bread', 'Avocado', 'Eggs', 'Cherry tomatoes', 'Feta cheese'],
        allergens: ['Gluten', 'Eggs', 'Dairy'],
        icon: Icons.breakfast_dining,
        imageUrl: '',
        mealType: 'breakfast',
        price: 12.99,
      ),
      MealModelV3(
        id: 'b2',
        name: 'Greek Yogurt Bowl',
        description: 'Creamy Greek yogurt with mixed berries and granola',
        calories: 320,
        protein: 20,
        carbs: 42,
        fat: 8,
        ingredients: ['Greek yogurt', 'Mixed berries', 'Granola', 'Honey', 'Almonds'],
        allergens: ['Dairy', 'Nuts'],
        icon: Icons.breakfast_dining,
        imageUrl: '',
        mealType: 'breakfast',
        price: 9.99,
      ),
      MealModelV3(
        id: 'b3',
        name: 'Protein Pancakes',
        description: 'Fluffy protein-packed pancakes with fresh fruit',
        calories: 380,
        protein: 25,
        carbs: 48,
        fat: 8,
        ingredients: ['Protein powder', 'Oat flour', 'Eggs', 'Bananas', 'Blueberries'],
        allergens: ['Gluten', 'Eggs', 'Dairy'],
        icon: Icons.breakfast_dining,
        imageUrl: '',
        mealType: 'breakfast',
        price: 11.99,
      ),

      // Lunch meals
      MealModelV3(
        id: 'l1',
        name: 'Quinoa Power Bowl',
        description: 'Nutrient-rich quinoa with roasted vegetables and tahini dressing',
        calories: 480,
        protein: 16,
        carbs: 62,
        fat: 18,
        ingredients: ['Quinoa', 'Roasted vegetables', 'Chickpeas', 'Tahini', 'Mixed greens'],
        allergens: ['Sesame'],
        icon: Icons.lunch_dining,
        imageUrl: '',
        mealType: 'lunch',
        price: 14.99,
      ),
      MealModelV3(
        id: 'l2',
        name: 'Grilled Chicken Salad',
        description: 'Fresh mixed greens with grilled chicken and balsamic vinaigrette',
        calories: 380,
        protein: 35,
        carbs: 18,
        fat: 20,
        ingredients: ['Grilled chicken', 'Mixed greens', 'Cherry tomatoes', 'Cucumber', 'Feta cheese'],
        allergens: ['Dairy'],
        icon: Icons.lunch_dining,
        imageUrl: '',
        mealType: 'lunch',
        price: 13.99,
      ),
      MealModelV3(
        id: 'l3',
        name: 'Mediterranean Wrap',
        description: 'Whole wheat wrap filled with hummus, vegetables, and lean protein',
        calories: 420,
        protein: 22,
        carbs: 45,
        fat: 18,
        ingredients: ['Whole wheat tortilla', 'Hummus', 'Grilled chicken', 'Vegetables', 'Olives'],
        allergens: ['Gluten', 'Sesame'],
        icon: Icons.lunch_dining,
        imageUrl: '',
        mealType: 'lunch',
        price: 12.99,
      ),

      // Dinner meals
      MealModelV3(
        id: 'd1',
        name: 'Salmon with Sweet Potato',
        description: 'Grilled Atlantic salmon with roasted sweet potato and asparagus',
        calories: 520,
        protein: 42,
        carbs: 35,
        fat: 22,
        ingredients: ['Atlantic salmon', 'Sweet potato', 'Asparagus', 'Lemon', 'Herbs'],
        allergens: ['Fish'],
        icon: Icons.dinner_dining,
        imageUrl: '',
        mealType: 'dinner',
        price: 18.99,
      ),
      MealModelV3(
        id: 'd2',
        name: 'Lean Beef Stir Fry',
        description: 'Tender beef strips with colorful vegetables over brown rice',
        calories: 480,
        protein: 35,
        carbs: 45,
        fat: 16,
        ingredients: ['Lean beef', 'Brown rice', 'Bell peppers', 'Broccoli', 'Soy sauce'],
        allergens: ['Soy'],
        icon: Icons.dinner_dining,
        imageUrl: '',
        mealType: 'dinner',
        price: 16.99,
      ),
      MealModelV3(
        id: 'd3',
        name: 'Vegetarian Lentil Curry',
        description: 'Protein-rich lentil curry with basmati rice and naan',
        calories: 450,
        protein: 18,
        carbs: 68,
        fat: 12,
        ingredients: ['Red lentils', 'Basmati rice', 'Coconut milk', 'Indian spices', 'Naan bread'],
        allergens: ['Gluten'],
        icon: Icons.dinner_dining,
        imageUrl: '',
        mealType: 'dinner',
        price: 15.99,
      ),
    ];
  }
}

class MealPlanModelV3 {
  final String id;
  final String userId;
  final String name;
  final String displayName;
  final int mealsPerDay;
  final double pricePerWeek;
  final double pricePerMeal;
  final String description;
  final bool isActive;
  final DateTime? createdAt;

  MealPlanModelV3({
    required this.id,
    this.userId = '',
    required this.name,
    required this.displayName,
    required this.mealsPerDay,
    required this.pricePerWeek,
  this.pricePerMeal = 13.0,
    required this.description,
    this.isActive = true,
    this.createdAt,
  });

  // Computed pricing based on $/meal business rule
  double get weeklyPrice => pricePerMeal * mealsPerDay * 7;
  double get monthlyPrice => pricePerMeal * mealsPerDay * 30;

  static List<MealPlanModelV3> getAvailablePlans() {
    return [
      MealPlanModelV3(
        id: '1',
        name: 'standard',
        displayName: 'Standard',
        mealsPerDay: 1,
  // $13 per meal; weekly = 13 * 1 * 7 = 91; monthly (30 meals) = $390
  pricePerWeek: 91.0,
  pricePerMeal: 13.0,
        description: '1 nutritious meal per day',
      ),
      MealPlanModelV3(
        id: '2',
        name: 'pro',
        displayName: 'Pro',
        mealsPerDay: 2,
  // $13 per meal; weekly = 13 * 2 * 7 = 182; monthly (60 meals) = $780
  pricePerWeek: 182.0,
  pricePerMeal: 13.0,
        description: '2 balanced meals per day',
      ),
      MealPlanModelV3(
        id: '3',
        name: 'premium',
        displayName: 'Premium',
        mealsPerDay: 3,
  // $13 per meal; weekly = 13 * 3 * 7 = 273; monthly (90 meals) = $1170
  pricePerWeek: 273.0,
  pricePerMeal: 13.0,
        description: '3 complete meals per day',
      ),
    ];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'displayName': displayName,
      'mealsPerDay': mealsPerDay,
      'pricePerWeek': pricePerWeek,
  'pricePerMeal': pricePerMeal,
      'description': description,
      'isActive': isActive,
      'createdAt': createdAt?.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'displayName': displayName,
      'mealsPerDay': mealsPerDay,
      'pricePerWeek': pricePerWeek,
  'pricePerMeal': pricePerMeal,
      'description': description,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory MealPlanModelV3.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MealPlanModelV3(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      displayName: data['displayName'] ?? '',
      mealsPerDay: data['mealsPerDay'] ?? 1,
      pricePerWeek: data['pricePerWeek']?.toDouble() ?? 0.0,
  pricePerMeal: data['pricePerMeal']?.toDouble() ?? 13.0,
      description: data['description'] ?? '',
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt'] is Timestamp 
          ? (data['createdAt'] as Timestamp).toDate()
          : data['createdAt'] != null 
              ? DateTime.fromMillisecondsSinceEpoch(data['createdAt'])
              : null,
    );
  }

  factory MealPlanModelV3.fromJson(Map<String, dynamic> json) {
    return MealPlanModelV3(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      displayName: json['displayName'] ?? '',
      mealsPerDay: json['mealsPerDay'] ?? 1,
      pricePerWeek: json['pricePerWeek']?.toDouble() ?? 0.0,
  pricePerMeal: json['pricePerMeal']?.toDouble() ?? 13.0,
      description: json['description'] ?? '',
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
          : null,
    );
  }
}

class DeliveryScheduleModelV3 {
  final String id;
  final String userId;
  final String dayOfWeek;
  final String mealType; // breakfast, lunch, dinner
  final TimeOfDay deliveryTime;
  final String addressId;
  final bool isActive;
  final DateTime? weekStartDate;

  DeliveryScheduleModelV3({
    required this.id,
    required this.userId,
    required this.dayOfWeek,
    required this.mealType,
    required this.deliveryTime,
    required this.addressId,
    this.isActive = true,
    this.weekStartDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'dayOfWeek': dayOfWeek,
      'mealType': mealType,
      'deliveryTime': '${deliveryTime.hour}:${deliveryTime.minute}',
      'addressId': addressId,
      'isActive': isActive,
      'weekStartDate': weekStartDate?.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'dayOfWeek': dayOfWeek,
      'mealType': mealType,
      'deliveryTime': '${deliveryTime.hour}:${deliveryTime.minute}',
      'addressId': addressId,
      'isActive': isActive,
      'weekStartDate': weekStartDate != null ? Timestamp.fromDate(weekStartDate!) : null,
    };
  }

  factory DeliveryScheduleModelV3.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DeliveryScheduleModelV3.fromJson(data);
  }

  factory DeliveryScheduleModelV3.fromJson(Map<String, dynamic> json) {
    final timeParts = json['deliveryTime'].split(':');
    // Normalize weekStartDate across possible representations
    final ws = json['weekStartDate'];
    DateTime? weekStart;
    if (ws is Timestamp) {
      weekStart = ws.toDate();
    } else if (ws is int) {
      weekStart = DateTime.fromMillisecondsSinceEpoch(ws);
    } else if (ws is String) {
      // Best-effort parse if string (ISO8601 or millis)
      final asInt = int.tryParse(ws);
      weekStart = asInt != null ? DateTime.fromMillisecondsSinceEpoch(asInt) : DateTime.tryParse(ws);
    }
    return DeliveryScheduleModelV3(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      dayOfWeek: json['dayOfWeek'] ?? '',
      mealType: json['mealType'] ?? '',
      deliveryTime: TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      ),
      addressId: json['addressId'] ?? '',
      isActive: json['isActive'] ?? true,
      weekStartDate: weekStart,
    );
  }
}

class AddressModelV3 {
  final String id;
  final String userId;
  final String label; // Home, Work, etc.
  final String streetAddress;
  final String apartment;
  final String city;
  final String state;
  final String zipCode;
  final bool isDefault;
  final DateTime? createdAt;

  AddressModelV3({
    required this.id,
    required this.userId,
    required this.label,
    required this.streetAddress,
    this.apartment = '',
    this.city = 'New York City',
    this.state = 'New York',
    required this.zipCode,
    this.isDefault = false,
    this.createdAt,
  });

  String get fullAddress {
    String address = streetAddress;
    if (apartment.isNotEmpty) {
      address += ', $apartment';
    }
    address += ', $city, $state $zipCode';
    return address;
  }

  // For AI compatibility - provide these getters
  String get type => label.toLowerCase();
  String get street => streetAddress;
  String get displayAddress => fullAddress;
  String get specialInstructions => '';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'label': label,
      'streetAddress': streetAddress,
      'apartment': apartment,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'isDefault': isDefault,
      'createdAt': createdAt?.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toFirestore() {
    return toJson();
  }

  factory AddressModelV3.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AddressModelV3.fromJson(data);
  }

  factory AddressModelV3.fromJson(Map<String, dynamic> json) {
    // Normalize createdAt across possible representations
    final ca = json['createdAt'];
    DateTime? createdAt;
    if (ca is Timestamp) {
      createdAt = ca.toDate();
    } else if (ca is int) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(ca);
    } else if (ca is String) {
      final asInt = int.tryParse(ca);
      createdAt = asInt != null ? DateTime.fromMillisecondsSinceEpoch(asInt) : DateTime.tryParse(ca);
    }
    return AddressModelV3(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      label: json['label'] ?? '',
      streetAddress: json['streetAddress'] ?? '',
      apartment: json['apartment'] ?? '',
      city: json['city'] ?? 'New York City',
      state: json['state'] ?? 'New York',
      zipCode: json['zipCode'] ?? '',
      isDefault: json['isDefault'] ?? false,
      createdAt: createdAt,
    );
  }
}

// Order Status Enum
enum OrderStatus {
  pending,
  confirmed,
  preparing,
  outForDelivery,
  delivered,
  cancelled,
}

// Order Model for tracking meal deliveries
class OrderModelV3 {
  final String id;
  final String userId;
  final MealPlanType mealPlanType;
  final List<MealModelV3> meals;
  final String deliveryAddress;
  final DateTime orderDate;
  final DateTime deliveryDate;
  final OrderStatus status;
  final double totalAmount;
  final DateTime? estimatedDeliveryTime;
  final String? notes;
  final String? trackingNumber;

  OrderModelV3({
    required this.id,
    required this.userId,
    required this.mealPlanType,
    required this.meals,
    required this.deliveryAddress,
    required this.orderDate,
    required this.deliveryDate,
    required this.status,
    required this.totalAmount,
    this.estimatedDeliveryTime,
    this.notes,
    this.trackingNumber,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'userId': userId,
      'mealPlanType': mealPlanType.toString().split('.').last,
      'meals': meals.map((meal) => meal.toFirestore()).toList(),
      'deliveryAddress': deliveryAddress,
      'orderDate': orderDate.millisecondsSinceEpoch,
      'deliveryDate': deliveryDate.millisecondsSinceEpoch,
      'status': status.toString().split('.').last,
      'totalAmount': totalAmount,
      'estimatedDeliveryTime': estimatedDeliveryTime?.millisecondsSinceEpoch,
      'notes': notes,
      'trackingNumber': trackingNumber,
    };
  }

  factory OrderModelV3.fromJson(Map<String, dynamic> data) {
    // Build meals list with fallbacks for legacy payloads that store only mealName/mealNames
    List<MealModelV3> mealsList = (data['meals'] as List<dynamic>? ?? [])
        .map((mealData) => MealModelV3.fromJson(mealData))
        .toList();

    if (mealsList.isEmpty) {
      final dynamic singleName = data['mealName'];
      final dynamic nameList = data['mealNames'];
      final String mealType = (data['mealType'] ?? 'breakfast').toString();

      if (singleName is String && singleName.trim().isNotEmpty) {
        mealsList = [
          MealModelV3(
            id: 'legacy-0',
            name: singleName.trim(),
            description: '',
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            ingredients: const [],
            allergens: const [],
            icon: Icons.fastfood,
            imageUrl: '',
            mealType: mealType,
            price: (data['price'] is num) ? (data['price'] as num).toDouble() : 0.0,
          ),
        ];
      } else if (nameList is List) {
        mealsList = nameList
            .whereType<String>()
            .where((n) => n.trim().isNotEmpty)
            .toList()
            .asMap()
            .entries
            .map((e) => MealModelV3(
                  id: 'legacy-${e.key}',
                  name: e.value.trim(),
                  description: '',
                  calories: 0,
                  protein: 0,
                  carbs: 0,
                  fat: 0,
                  ingredients: const [],
                  allergens: const [],
                  icon: Icons.fastfood,
                  imageUrl: '',
                  mealType: mealType,
                  price: 0.0,
                ))
            .toList();
      }
    }

    return OrderModelV3(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      mealPlanType: _parseMealPlanType(data['mealPlanType']),
      meals: mealsList,
      deliveryAddress: data['deliveryAddress'] ?? '',
      orderDate: DateTime.fromMillisecondsSinceEpoch(data['orderDate'] ?? 0),
      deliveryDate: DateTime.fromMillisecondsSinceEpoch(data['deliveryDate'] ?? 0),
      status: _parseOrderStatus(data['status']),
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      estimatedDeliveryTime: data['estimatedDeliveryTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['estimatedDeliveryTime'])
          : null,
      notes: data['notes'],
      trackingNumber: data['trackingNumber'],
    );
  }

  factory OrderModelV3.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Build meals list with fallbacks for legacy payloads that store only mealName/mealNames
    List<MealModelV3> mealsList = (data['meals'] as List<dynamic>? ?? [])
        .map((mealData) => MealModelV3.fromJson(mealData))
        .toList();

    if (mealsList.isEmpty) {
      final dynamic singleName = data['mealName'];
      final dynamic nameList = data['mealNames'];
      final String mealType = (data['mealType'] ?? 'breakfast').toString();

      if (singleName is String && singleName.trim().isNotEmpty) {
        mealsList = [
          MealModelV3(
            id: 'legacy-0',
            name: singleName.trim(),
            description: '',
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            ingredients: const [],
            allergens: const [],
            icon: Icons.fastfood,
            imageUrl: '',
            mealType: mealType,
            price: (data['price'] is num) ? (data['price'] as num).toDouble() : 0.0,
          ),
        ];
      } else if (nameList is List) {
        mealsList = nameList
            .whereType<String>()
            .where((n) => n.trim().isNotEmpty)
            .toList()
            .asMap()
            .entries
            .map((e) => MealModelV3(
                  id: 'legacy-${e.key}',
                  name: e.value.trim(),
                  description: '',
                  calories: 0,
                  protein: 0,
                  carbs: 0,
                  fat: 0,
                  ingredients: const [],
                  allergens: const [],
                  icon: Icons.fastfood,
                  imageUrl: '',
                  mealType: mealType,
                  price: 0.0,
                ))
            .toList();
      }
    }

    return OrderModelV3(
      id: doc.id,
      userId: data['userId'] ?? '',
      mealPlanType: _parseMealPlanType(data['mealPlanType']),
      meals: mealsList,
      deliveryAddress: data['deliveryAddress'] ?? '',
      orderDate: DateTime.fromMillisecondsSinceEpoch(data['orderDate'] ?? 0),
      deliveryDate: DateTime.fromMillisecondsSinceEpoch(data['deliveryDate'] ?? 0),
      status: _parseOrderStatus(data['status']),
      totalAmount: (data['totalAmount'] ?? 0.0).toDouble(),
      estimatedDeliveryTime: data['estimatedDeliveryTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['estimatedDeliveryTime'])
          : null,
      notes: data['notes'],
      trackingNumber: data['trackingNumber'],
    );
  }

  static OrderStatus _parseOrderStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'outfordelivery':
        return OrderStatus.outForDelivery;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  static MealPlanType _parseMealPlanType(String? type) {
    switch (type?.toLowerCase()) {
      case 'standard':
      case 'nutritious':
      case 'nutritiousjr':
        return MealPlanType.standard;
      case 'pro':
      case 'dietknight':
        return MealPlanType.pro;
      case 'premium':
      case 'leanfreak':
        return MealPlanType.premium;
      default:
        return MealPlanType.standard;
    }
  }
}
