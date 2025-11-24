import 'dart:math';
import '../../models/meal_model_v3.dart';

/// Service to calculate subscription pricing upfront
/// 
/// PRICING MODEL (Option B - Menu Pricing with Meal Plan Constraint):
/// 
/// User Flow:
/// 1. Selects a meal plan (Standard=1 meal/day, Pro=2 meals/day, Premium=3 meals/day)
///    This ENFORCES a hard constraint on how many meals they must select per day
/// 
/// 2. Selects specific meals for each day × meal type
///    Example for Pro (2 meals/day):
///    - Monday: Breakfast (Pancakes $12) + Lunch (Salad $11)
///    - Tuesday: Breakfast (Oatmeal $10) + Lunch (Pasta $13)
///    - ... × 7 days = 14 total meals
/// 
/// 3. Final charge is based on the INDIVIDUAL MEAL PRICES selected
///    NOT the meal plan's default price anchor ($13/meal)
/// 
/// Example Pro Pricing (2 meals/day × 7 days = 14 meals):
/// - Meals: $12 + $11 + $10 + $13 + ... (sum of 14 individual meal prices)
/// - Delivery: $9.75 × 14 meals = $136.50
/// - Subtotal: meals + delivery
/// - FreshPunk Fee: 10% of subtotal
/// - Stripe Fee: 2.9% + $0.30 of (subtotal + FreshPunk)
/// - Total: What customer is charged upfront
/// 
/// Key Points:
/// - Meal plan mealsPerDay is a hard constraint (user MUST select exactly that many per day)
/// - Expected mealCount = mealsPerDay × 7 (for weekly commitment)
/// - Pricing reflects actual meal selections, not fixed plan pricing
/// - User is charged upfront before any meals are delivered
class PricingService {
  static const double deliveryFeePerMeal = 9.75;
  static const double freshpunkSharePercent = 10.0; // 10%
  static const double stripePercentFee = 2.9; // 2.9%
  static const double stripeFixedFee = 0.30; // $0.30 per transaction

  /// Calculate the total cost for a subscription based on meal selections
  /// 
  /// [selectedMeals]: List of MealModelV3 objects the user selected
  /// [mealCount]: Total number of meals selected (should match selectedMeals.length)
  /// 
  /// Returns a [SubscriptionPrice] with breakdown of all costs
  /// 
  /// Example:
  /// - 7 meals selected at $12, $13, $14, $12, $13, $14, $13 = $91 meal cost
  /// - Delivery: $9.75 × 7 = $68.25
  /// - Subtotal: $159.25
  /// - FreshPunk fee (10%): $15.93
  /// - Subtotal for Stripe: $175.18
  /// - Stripe fee (2.9% + $0.30): $5.40
  /// - TOTAL: $180.58
  static SubscriptionPrice calculateSubscriptionPrice({
    required List<MealModelV3> selectedMeals,
    required int mealCount,
  }) {
    // 1. Sum meal costs from individual meal prices
    // NOTE: Not using the meal plan's pricePerMeal ($13), using actual meal prices
    final mealSubtotal = selectedMeals.fold<double>(
      0.0,
      (sum, meal) => sum + meal.price,
    );

    // 2. Calculate delivery fees (9.75 per meal)
    final deliveryFees = mealCount * deliveryFeePerMeal;

    // 3. Calculate subtotal before FreshPunk fee
    final subtotalBeforeFreshpunk = mealSubtotal + deliveryFees;

    // 4. Calculate FreshPunk's 10% share
    final freshpunkFee = (subtotalBeforeFreshpunk * freshpunkSharePercent) / 100.0;

    // 5. Subtotal before Stripe fees
    final subtotalBeforeStripeFee = subtotalBeforeFreshpunk + freshpunkFee;

    // 6. Calculate Stripe transaction fees
    // Stripe charges: 2.9% + $0.30 per transaction
    final stripeFee = (subtotalBeforeStripeFee * stripePercentFee / 100.0) + stripeFixedFee;

    // 7. Final total (what customer is charged)
    final totalAmount = subtotalBeforeStripeFee + stripeFee;

    return SubscriptionPrice(
      mealSubtotal: mealSubtotal,
      deliveryFees: deliveryFees,
      subtotalBeforeFreshpunk: subtotalBeforeFreshpunk,
      freshpunkFee: freshpunkFee,
      subtotalBeforeStripeFee: subtotalBeforeStripeFee,
      stripeFee: stripeFee,
      totalAmount: totalAmount,
      mealCount: mealCount,
    );
  }

  /// Calculate Stripe transaction fees for a given amount
  static double calculateStripeFee(double amount) {
    return (amount * stripePercentFee / 100.0) + stripeFixedFee;
  }

  /// Get a human-readable breakdown of pricing
  static String getPricingBreakdown(SubscriptionPrice price) {
    return '''
Meals: \$${price.mealSubtotal.toStringAsFixed(2)}
Delivery ($deliveryFeePerMeal × ${price.mealCount}): \$${price.deliveryFees.toStringAsFixed(2)}
Subtotal: \$${price.subtotalBeforeFreshpunk.toStringAsFixed(2)}
FreshPunk Fee (${freshpunkSharePercent.toStringAsFixed(1)}%): \$${price.freshpunkFee.toStringAsFixed(2)}
Stripe Fee: \$${price.stripeFee.toStringAsFixed(2)}
─────────────────
Total: \$${price.totalAmount.toStringAsFixed(2)}
''';
  }
}

/// Data class holding subscription pricing information
class SubscriptionPrice {
  /// Sum of all selected meal prices
  final double mealSubtotal;

  /// Delivery fees (9.75 per meal)
  final double deliveryFees;

  /// Meals + Delivery
  final double subtotalBeforeFreshpunk;

  /// FreshPunk's 10% cut
  final double freshpunkFee;

  /// Meals + Delivery + FreshPunk fee
  final double subtotalBeforeStripeFee;

  /// Stripe transaction fees (2.9% + $0.30)
  final double stripeFee;

  /// Final amount customer is charged
  final double totalAmount;

  /// Number of meals in the order
  final int mealCount;

  const SubscriptionPrice({
    required this.mealSubtotal,
    required this.deliveryFees,
    required this.subtotalBeforeFreshpunk,
    required this.freshpunkFee,
    required this.subtotalBeforeStripeFee,
    required this.stripeFee,
    required this.totalAmount,
    required this.mealCount,
  });

  /// Convert to cents for Stripe API (Stripe uses cents)
  int get totalAmountCents => (totalAmount * 100).round();

  /// Convert to Map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'mealSubtotal': mealSubtotal,
      'deliveryFees': deliveryFees,
      'subtotalBeforeFreshpunk': subtotalBeforeFreshpunk,
      'freshpunkFee': freshpunkFee,
      'subtotalBeforeStripeFee': subtotalBeforeStripeFee,
      'stripeFee': stripeFee,
      'totalAmount': totalAmount,
      'totalAmountCents': totalAmountCents,
      'mealCount': mealCount,
      'calculatedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Create from Firestore map
  factory SubscriptionPrice.fromMap(Map<String, dynamic> map) {
    return SubscriptionPrice(
      mealSubtotal: (map['mealSubtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFees: (map['deliveryFees'] as num?)?.toDouble() ?? 0.0,
      subtotalBeforeFreshpunk: (map['subtotalBeforeFreshpunk'] as num?)?.toDouble() ?? 0.0,
      freshpunkFee: (map['freshpunkFee'] as num?)?.toDouble() ?? 0.0,
      subtotalBeforeStripeFee: (map['subtotalBeforeStripeFee'] as num?)?.toDouble() ?? 0.0,
      stripeFee: (map['stripeFee'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      mealCount: (map['mealCount'] as num?)?.toInt() ?? 0,
    );
  }
}
