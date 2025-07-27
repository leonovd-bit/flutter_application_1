class Subscription {
  final String id;
  final String userId;
  final SubscriptionPlan plan;
  final SubscriptionStatus status;
  final double monthlyPrice;
  final DateTime startDate;
  final DateTime? endDate;
  final String? stripeSubscriptionId;
  final String? stripeCustomerId;
  final PaymentMethod paymentMethod;
  final DateTime createdAt;
  final DateTime updatedAt;

  Subscription({
    required this.id,
    required this.userId,
    required this.plan,
    required this.status,
    required this.monthlyPrice,
    required this.startDate,
    this.endDate,
    this.stripeSubscriptionId,
    this.stripeCustomerId,
    required this.paymentMethod,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'plan': plan.toString(),
      'status': status.toString(),
      'monthlyPrice': monthlyPrice,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'stripeSubscriptionId': stripeSubscriptionId,
      'stripeCustomerId': stripeCustomerId,
      'paymentMethod': paymentMethod.toMap(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      plan: SubscriptionPlan.values.firstWhere(
        (e) => e.toString() == map['plan'],
        orElse: () => SubscriptionPlan.oneMeal,
      ),
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.toString() == map['status'],
        orElse: () => SubscriptionStatus.pending,
      ),
      monthlyPrice: (map['monthlyPrice'] ?? 0.0).toDouble(),
      startDate: DateTime.parse(map['startDate']),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      stripeSubscriptionId: map['stripeSubscriptionId'],
      stripeCustomerId: map['stripeCustomerId'],
      paymentMethod: PaymentMethod.fromMap(map['paymentMethod'] ?? {}),
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  Subscription copyWith({
    String? id,
    String? userId,
    SubscriptionPlan? plan,
    SubscriptionStatus? status,
    double? monthlyPrice,
    DateTime? startDate,
    DateTime? endDate,
    String? stripeSubscriptionId,
    String? stripeCustomerId,
    PaymentMethod? paymentMethod,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      plan: plan ?? this.plan,
      status: status ?? this.status,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      stripeSubscriptionId: stripeSubscriptionId ?? this.stripeSubscriptionId,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum SubscriptionPlan {
  oneMeal,
  twoMeal,
  threeMeal,
}

extension SubscriptionPlanExtension on SubscriptionPlan {
  String get displayName {
    switch (this) {
      case SubscriptionPlan.oneMeal:
        return 'NutrientJr Plan';
      case SubscriptionPlan.twoMeal:
        return 'DietKnight Plan';
      case SubscriptionPlan.threeMeal:
        return 'LeanFreak Plan';
    }
  }

  String get description {
    switch (this) {
      case SubscriptionPlan.oneMeal:
        return 'One nutrient-packed meal delivered daily';
      case SubscriptionPlan.twoMeal:
        return 'Two balanced meals delivered daily';
      case SubscriptionPlan.threeMeal:
        return 'Three complete meals delivered daily';
    }
  }

  double get monthlyPrice {
    switch (this) {
      case SubscriptionPlan.oneMeal:
        return 300.00; // NutrientJr
      case SubscriptionPlan.twoMeal:
        return 600.00; // DietKnight
      case SubscriptionPlan.threeMeal:
        return 800.00; // LeanFreak
    }
  }

  int get mealsPerDay {
    switch (this) {
      case SubscriptionPlan.oneMeal:
        return 1;
      case SubscriptionPlan.twoMeal:
        return 2;
      case SubscriptionPlan.threeMeal:
        return 3;
    }
  }

  String get priceId {
    // These would be your actual Stripe Price IDs
    switch (this) {
      case SubscriptionPlan.oneMeal:
        return 'price_1MpSYpHB8mNBBYgB7QqDlFEn'; // Replace with actual Stripe Price ID
      case SubscriptionPlan.twoMeal:
        return 'price_1MpSYpHB8mNBBYgB7QqDlFEo'; // Replace with actual Stripe Price ID
      case SubscriptionPlan.threeMeal:
        return 'price_1MpSYpHB8mNBBYgB7QqDlFEp'; // Replace with actual Stripe Price ID
    }
  }
}

enum SubscriptionStatus {
  pending,
  active,
  canceled,
  pastDue,
  unpaid,
}

extension SubscriptionStatusExtension on SubscriptionStatus {
  String get displayName {
    switch (this) {
      case SubscriptionStatus.pending:
        return 'Pending';
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.canceled:
        return 'Canceled';
      case SubscriptionStatus.pastDue:
        return 'Past Due';
      case SubscriptionStatus.unpaid:
        return 'Unpaid';
    }
  }

  bool get isActive => this == SubscriptionStatus.active;
}

class PaymentMethod {
  final String? stripePaymentMethodId;
  final String cardLast4;
  final String cardBrand;
  final int expMonth;
  final int expYear;
  final bool isDefault;

  PaymentMethod({
    this.stripePaymentMethodId,
    required this.cardLast4,
    required this.cardBrand,
    required this.expMonth,
    required this.expYear,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'stripePaymentMethodId': stripePaymentMethodId,
      'cardLast4': cardLast4,
      'cardBrand': cardBrand,
      'expMonth': expMonth,
      'expYear': expYear,
      'isDefault': isDefault,
    };
  }

  factory PaymentMethod.fromMap(Map<String, dynamic> map) {
    return PaymentMethod(
      stripePaymentMethodId: map['stripePaymentMethodId'],
      cardLast4: map['cardLast4'] ?? '',
      cardBrand: map['cardBrand'] ?? '',
      expMonth: map['expMonth'] ?? 0,
      expYear: map['expYear'] ?? 0,
      isDefault: map['isDefault'] ?? false,
    );
  }

  String get displayText => '•••• •••• •••• $cardLast4';
  String get expiryText => '${expMonth.toString().padLeft(2, '0')}/${expYear.toString().substring(2)}';
}
