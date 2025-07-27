class DeliveryAddress {
  final String id;
  final String userId;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String state;
  final String zipCode;
  final double latitude;
  final double longitude;
  final String? deliveryInstructions;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  DeliveryAddress({
    required this.id,
    required this.userId,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.latitude,
    required this.longitude,
    this.deliveryInstructions,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  String get fullAddress {
    final line2 = addressLine2?.isNotEmpty == true ? ', $addressLine2' : '';
    return '$addressLine1$line2, $city, $state $zipCode';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'latitude': latitude,
      'longitude': longitude,
      'deliveryInstructions': deliveryInstructions,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DeliveryAddress.fromMap(Map<String, dynamic> map) {
    return DeliveryAddress(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      addressLine1: map['addressLine1'] ?? '',
      addressLine2: map['addressLine2'],
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      zipCode: map['zipCode'] ?? '',
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      deliveryInstructions: map['deliveryInstructions'],
      isDefault: map['isDefault'] ?? false,
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  DeliveryAddress copyWith({
    String? id,
    String? userId,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? zipCode,
    double? latitude,
    double? longitude,
    String? deliveryInstructions,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryAddress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
