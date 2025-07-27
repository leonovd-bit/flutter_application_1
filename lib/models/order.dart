enum OrderStatus {
  scheduled,
  confirmed,
  ready,
  pickedUp,
  outForDelivery,
  delivered,
  cancelled,
}

class Order {
  final String id;
  final String userId;
  final String mealId;
  final String mealName;
  final String mealDescription;
  final String mealImageUrl;
  final DateTime scheduledDeliveryTime;
  final String deliveryAddressId;
  final String deliveryAddressText;
  final OrderStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? confirmedAt;
  final DateTime? readyAt;
  final DateTime? pickedUpAt;
  final DateTime? outForDeliveryAt;
  final DateTime? deliveredAt;
  final bool notificationSent;
  final bool autoConfirmed;

  Order({
    required this.id,
    required this.userId,
    required this.mealId,
    required this.mealName,
    required this.mealDescription,
    required this.mealImageUrl,
    required this.scheduledDeliveryTime,
    required this.deliveryAddressId,
    required this.deliveryAddressText,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.confirmedAt,
    this.readyAt,
    this.pickedUpAt,
    this.outForDeliveryAt,
    this.deliveredAt,
    this.notificationSent = false,
    this.autoConfirmed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'mealId': mealId,
      'mealName': mealName,
      'mealDescription': mealDescription,
      'mealImageUrl': mealImageUrl,
      'scheduledDeliveryTime': scheduledDeliveryTime.toIso8601String(),
      'deliveryAddressId': deliveryAddressId,
      'deliveryAddressText': deliveryAddressText,
      'status': status.toString(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'confirmedAt': confirmedAt?.toIso8601String(),
      'readyAt': readyAt?.toIso8601String(),
      'pickedUpAt': pickedUpAt?.toIso8601String(),
      'outForDeliveryAt': outForDeliveryAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'notificationSent': notificationSent,
      'autoConfirmed': autoConfirmed,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      mealId: map['mealId'] ?? '',
      mealName: map['mealName'] ?? '',
      mealDescription: map['mealDescription'] ?? '',
      mealImageUrl: map['mealImageUrl'] ?? '',
      scheduledDeliveryTime: DateTime.parse(map['scheduledDeliveryTime']),
      deliveryAddressId: map['deliveryAddressId'] ?? '',
      deliveryAddressText: map['deliveryAddressText'] ?? '',
      status: OrderStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => OrderStatus.scheduled,
      ),
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      confirmedAt: map['confirmedAt'] != null ? DateTime.parse(map['confirmedAt']) : null,
      readyAt: map['readyAt'] != null ? DateTime.parse(map['readyAt']) : null,
      pickedUpAt: map['pickedUpAt'] != null ? DateTime.parse(map['pickedUpAt']) : null,
      outForDeliveryAt: map['outForDeliveryAt'] != null ? DateTime.parse(map['outForDeliveryAt']) : null,
      deliveredAt: map['deliveredAt'] != null ? DateTime.parse(map['deliveredAt']) : null,
      notificationSent: map['notificationSent'] ?? false,
      autoConfirmed: map['autoConfirmed'] ?? false,
    );
  }

  Order copyWith({
    OrderStatus? status,
    DateTime? confirmedAt,
    DateTime? readyAt,
    DateTime? pickedUpAt,
    DateTime? outForDeliveryAt,
    DateTime? deliveredAt,
    bool? notificationSent,
    bool? autoConfirmed,
  }) {
    return Order(
      id: id,
      userId: userId,
      mealId: mealId,
      mealName: mealName,
      mealDescription: mealDescription,
      mealImageUrl: mealImageUrl,
      scheduledDeliveryTime: scheduledDeliveryTime,
      deliveryAddressId: deliveryAddressId,
      deliveryAddressText: deliveryAddressText,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      confirmedAt: confirmedAt ?? this.confirmedAt,
      readyAt: readyAt ?? this.readyAt,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      outForDeliveryAt: outForDeliveryAt ?? this.outForDeliveryAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      notificationSent: notificationSent ?? this.notificationSent,
      autoConfirmed: autoConfirmed ?? this.autoConfirmed,
    );
  }

  bool get canBeModified => status == OrderStatus.scheduled && 
      scheduledDeliveryTime.subtract(const Duration(hours: 1)).isAfter(DateTime.now());

  Duration get timeUntilDelivery => scheduledDeliveryTime.difference(DateTime.now());
  
  bool get shouldShowNotification => 
      !notificationSent && 
      timeUntilDelivery.inMinutes <= 60 && 
      timeUntilDelivery.inMinutes > 0;

  bool get shouldAutoConfirm => 
      status == OrderStatus.scheduled && 
      timeUntilDelivery.inMinutes <= 15 &&
      timeUntilDelivery.inMinutes > 0;
}
