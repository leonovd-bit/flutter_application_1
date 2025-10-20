import 'package:cloud_firestore/cloud_firestore.dart';

/// Protein option for Protein+ feature
class ProteinOptionV3 {
  final String id;
  final String name;
  final String emoji;
  final String serving;
  final int calories;
  final int proteinGrams;
  final int fatGrams;
  final double price;

  const ProteinOptionV3({
    required this.id,
    required this.name,
    required this.emoji,
    required this.serving,
    required this.calories,
    required this.proteinGrams,
    required this.fatGrams,
    this.price = 9.99,
  });

  /// Get all available protein options
  static List<ProteinOptionV3> getAvailableProteins() {
    return [
      const ProteinOptionV3(
        id: 'cubed-chicken',
        name: 'Cubed Chicken',
        emoji: '🍗',
        serving: '100g',
        calories: 150,
        proteinGrams: 33,
        fatGrams: 2,
      ),
      const ProteinOptionV3(
        id: 'shredded-chicken',
        name: 'Shredded Chicken',
        emoji: '🍗',
        serving: '114g',
        calories: 150,
        proteinGrams: 33,
        fatGrams: 3,
      ),
      const ProteinOptionV3(
        id: 'grilled-chicken',
        name: 'Grilled Chicken Breast',
        emoji: '🍗',
        serving: '114g',
        calories: 120,
        proteinGrams: 33,
        fatGrams: 1,
      ),
      const ProteinOptionV3(
        id: 'philly-steak',
        name: 'Philly Steak',
        emoji: '🥩',
        serving: '114g',
        calories: 120,
        proteinGrams: 20,
        fatGrams: 4,
      ),
      const ProteinOptionV3(
        id: 'boiled-eggs',
        name: 'Boiled Eggs',
        emoji: '🥚',
        serving: '1pc',
        calories: 77,
        proteinGrams: 6,
        fatGrams: 5,
      ),
      const ProteinOptionV3(
        id: 'fried-eggs',
        name: 'Fried Eggs',
        emoji: '🍳',
        serving: '1pc',
        calories: 70,
        proteinGrams: 6,
        fatGrams: 5,
      ),
      const ProteinOptionV3(
        id: 'smoked-turkey',
        name: 'Smoked Turkey',
        emoji: '🦃',
        serving: '114g',
        calories: 150,
        proteinGrams: 30,
        fatGrams: 3,
      ),
      const ProteinOptionV3(
        id: 'grilled-salmon',
        name: 'Grilled Salmon',
        emoji: '🐟',
        serving: '114g',
        calories: 234,
        proteinGrams: 23,
        fatGrams: 14,
      ),
      const ProteinOptionV3(
        id: 'beyond-burger',
        name: 'Beyond Burger Patties',
        emoji: '🍔',
        serving: '170g',
        calories: 250,
        proteinGrams: 20,
        fatGrams: 18,
      ),
    ];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'serving': serving,
      'calories': calories,
      'proteinGrams': proteinGrams,
      'fatGrams': fatGrams,
      'price': price,
    };
  }

  factory ProteinOptionV3.fromJson(Map<String, dynamic> json) {
    return ProteinOptionV3(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      serving: json['serving'] as String,
      calories: json['calories'] as int,
      proteinGrams: json['proteinGrams'] as int,
      fatGrams: json['fatGrams'] as int,
      price: (json['price'] as num?)?.toDouble() ?? 9.99,
    );
  }
}

/// User's protein configuration (selected proteins with delivery details)
class ProteinConfigV3 {
  final String proteinId;
  final int servingsPerWeek; // Max 21 (3 per day * 7 days)
  final String deliveryDay; // monday, tuesday, etc.
  final String deliveryTime; // HH:mm format
  final String deliveryAddress;

  const ProteinConfigV3({
    required this.proteinId,
    required this.servingsPerWeek,
    required this.deliveryDay,
    required this.deliveryTime,
    required this.deliveryAddress,
  });

  Map<String, dynamic> toJson() {
    return {
      'proteinId': proteinId,
      'servingsPerWeek': servingsPerWeek,
      'deliveryDay': deliveryDay,
      'deliveryTime': deliveryTime,
      'deliveryAddress': deliveryAddress,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'proteinId': proteinId,
      'servingsPerWeek': servingsPerWeek,
      'deliveryDay': deliveryDay,
      'deliveryTime': deliveryTime,
      'deliveryAddress': deliveryAddress,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ProteinConfigV3.fromJson(Map<String, dynamic> json) {
    return ProteinConfigV3(
      proteinId: json['proteinId'] as String,
      servingsPerWeek: json['servingsPerWeek'] as int,
      deliveryDay: json['deliveryDay'] as String,
      deliveryTime: json['deliveryTime'] as String,
      deliveryAddress: json['deliveryAddress'] as String,
    );
  }

  factory ProteinConfigV3.fromFirestore(Map<String, dynamic> data) {
    return ProteinConfigV3(
      proteinId: data['proteinId'] as String,
      servingsPerWeek: data['servingsPerWeek'] as int,
      deliveryDay: data['deliveryDay'] as String,
      deliveryTime: data['deliveryTime'] as String,
      deliveryAddress: data['deliveryAddress'] as String,
    );
  }
}

/// User's protein consumption log
class ProteinLogV3 {
  final String userId;
  final String proteinId;
  final int servingNumber; // Which serving (1-21)
  final DateTime consumedAt;
  final bool isConsumed;

  const ProteinLogV3({
    required this.userId,
    required this.proteinId,
    required this.servingNumber,
    required this.consumedAt,
    this.isConsumed = false,
  });

  String get logKey => '$proteinId-serving-$servingNumber';

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'proteinId': proteinId,
      'servingNumber': servingNumber,
      'consumedAt': Timestamp.fromDate(consumedAt),
      'isConsumed': isConsumed,
    };
  }

  factory ProteinLogV3.fromFirestore(Map<String, dynamic> data) {
    return ProteinLogV3(
      userId: data['userId'] as String,
      proteinId: data['proteinId'] as String,
      servingNumber: data['servingNumber'] as int,
      consumedAt: (data['consumedAt'] as Timestamp).toDate(),
      isConsumed: data['isConsumed'] as bool? ?? false,
    );
  }
}
