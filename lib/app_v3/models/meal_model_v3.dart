import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum MealPlanType {
  nutritious,
  dietKnight,
  leanFreak,
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
    return MealModelV3(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      calories: json['calories'] ?? 0,
      protein: json['protein'] ?? 0,
      carbs: json['carbs'] ?? 0,
      fat: json['fat'] ?? 0,
      ingredients: List<String>.from(json['ingredients'] ?? []),
      allergens: List<String>.from(json['allergens'] ?? []),
      imageUrl: json['imageUrl'] ?? '',
      mealType: json['mealType'] ?? 'breakfast',
      price: json['price']?.toDouble() ?? 0.0,
      icon: Icons.fastfood, // Default icon since IconData can't be serialized
    );
  }
}

class MealPlanModelV3 {
  final String id;
  final String userId;
  final String name;
  final String displayName;
  final int mealsPerDay;
  final double pricePerWeek;
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
    required this.description,
    this.isActive = true,
    this.createdAt,
  });

  static List<MealPlanModelV3> getAvailablePlans() {
    return [
      MealPlanModelV3(
        id: '1',
        name: 'nutritiousjr',
        displayName: 'NutritiousJr',
        mealsPerDay: 1,
        pricePerWeek: 49.99,
        description: '1 nutritious meal per day',
      ),
      MealPlanModelV3(
        id: '2',
        name: 'dietknight',
        displayName: 'DietKnight',
        mealsPerDay: 2,
        pricePerWeek: 89.99,
        description: '2 balanced meals per day',
      ),
      MealPlanModelV3(
        id: '3',
        name: 'leanfreak',
        displayName: 'LeanFreak',
        mealsPerDay: 3,
        pricePerWeek: 129.99,
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
      weekStartDate: json['weekStartDate'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['weekStartDate'])
          : null,
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
      createdAt: json['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['createdAt'])
          : null,
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
    return OrderModelV3(
      id: data['id'] ?? '',
      userId: data['userId'] ?? '',
      mealPlanType: _parseMealPlanType(data['mealPlanType']),
      meals: (data['meals'] as List<dynamic>? ?? [])
          .map((mealData) => MealModelV3.fromJson(mealData))
          .toList(),
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
    return OrderModelV3(
      id: doc.id,
      userId: data['userId'] ?? '',
      mealPlanType: _parseMealPlanType(data['mealPlanType']),
      meals: (data['meals'] as List<dynamic>? ?? [])
          .map((mealData) => MealModelV3.fromJson(mealData))
          .toList(),
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
      case 'nutritious':
        return MealPlanType.nutritious;
      case 'dietknight':
        return MealPlanType.dietKnight;
      case 'leanfreak':
        return MealPlanType.leanFreak;
      default:
        return MealPlanType.nutritious;
    }
  }
}
