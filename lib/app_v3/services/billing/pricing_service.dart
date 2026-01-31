import 'dart:math';
import '../../models/meal_model_v3.dart';

/// Service to calculate subscription pricing upfront
/// 
/// PRICING MODEL (Option A - Split Stripe + Square):
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
/// - FreshPunk Fee: 10% of meal subtotal (Stripe invoice)
/// - Stripe Fee: 2.9% + $0.30 of FreshPunk fee
/// - Square Charge: (meal subtotal - FreshPunk fee) + delivery
/// - Total: Stripe charge + Square charge
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
    bool stripeOnly = false,
  }) {
    // 1. Sum meal costs from individual meal prices
    // NOTE: Not using the meal plan's pricePerMeal ($13), using actual meal prices
    final mealSubtotal = selectedMeals.fold<double>(
      0.0,
      (sum, meal) => sum + meal.price,
    );

    // 2. Calculate delivery fees (9.75 per meal)
    final deliveryFees = mealCount * deliveryFeePerMeal;

    // 3. Stripe-only mode (temporary): charge full total via Stripe
    if (stripeOnly) {
      final baseTotal = mealSubtotal + deliveryFees;
      final stripeFee = calculateStripeFee(baseTotal);
      final stripeChargeTotal = baseTotal + stripeFee;

      return SubscriptionPrice(
        mealSubtotal: mealSubtotal,
        deliveryFees: deliveryFees,
        freshpunkFee: 0.0,
        stripeFee: stripeFee,
        stripeChargeTotal: stripeChargeTotal,
        squareChargeTotal: 0.0,
        totalAmount: stripeChargeTotal,
        mealCount: mealCount,
        stripeOnly: true,
      );
    }

    // 3. FreshPunk fee is 10% of MEAL subtotal only (not delivery)
    final freshpunkFee = (mealSubtotal * freshpunkSharePercent) / 100.0;

    // 4. Stripe charges only the FreshPunk fee
    final stripeFee = (freshpunkFee * stripePercentFee / 100.0) + stripeFixedFee;
    final stripeChargeTotal = freshpunkFee + stripeFee;

    // 5. Square charges the remainder + delivery
    final squareChargeTotal = (mealSubtotal - freshpunkFee) + deliveryFees;

    // 6. Total customer cost across Stripe + Square
    final totalAmount = stripeChargeTotal + squareChargeTotal;

    return SubscriptionPrice(
      mealSubtotal: mealSubtotal,
      deliveryFees: deliveryFees,
      freshpunkFee: freshpunkFee,
      stripeFee: stripeFee,
      stripeChargeTotal: stripeChargeTotal,
      squareChargeTotal: squareChargeTotal,
      totalAmount: totalAmount,
      mealCount: mealCount,
      stripeOnly: false,
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
FreshPunk Fee (${freshpunkSharePercent.toStringAsFixed(1)}% of meals): \$${price.freshpunkFee.toStringAsFixed(2)}
Stripe Fee: \$${price.stripeFee.toStringAsFixed(2)}
Stripe Charge: \$${price.stripeChargeTotal.toStringAsFixed(2)}
Square Charge: \$${price.squareChargeTotal.toStringAsFixed(2)}
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

  /// FreshPunk's 10% cut (of meals only)
  final double freshpunkFee;

  /// Stripe transaction fees (2.9% + $0.30) on FreshPunk fee
  final double stripeFee;

  /// Total charged in Stripe (FreshPunk fee + Stripe fee)
  final double stripeChargeTotal;

  /// Total charged in Square (meals minus fee + delivery)
  final double squareChargeTotal;

  /// Final amount customer is charged
  final double totalAmount;

  /// Number of meals in the order
  final int mealCount;

  /// Stripe-only mode (Square disabled)
  final bool stripeOnly;

  const SubscriptionPrice({
    required this.mealSubtotal,
    required this.deliveryFees,
    required this.freshpunkFee,
    required this.stripeFee,
    required this.stripeChargeTotal,
    required this.squareChargeTotal,
    required this.totalAmount,
    required this.mealCount,
    required this.stripeOnly,
  });

  /// Convert to cents for Stripe API (Stripe uses cents)
  int get totalAmountCents => (totalAmount * 100).round();

  /// Convert to Map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'mealSubtotal': mealSubtotal,
      'deliveryFees': deliveryFees,
      'freshpunkFee': freshpunkFee,
      'stripeFee': stripeFee,
      'stripeChargeTotal': stripeChargeTotal,
      'squareChargeTotal': squareChargeTotal,
      'totalAmount': totalAmount,
      'totalAmountCents': totalAmountCents,
      'mealCount': mealCount,
      'stripeOnly': stripeOnly,
      'calculatedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Create from Firestore map
  factory SubscriptionPrice.fromMap(Map<String, dynamic> map) {
    return SubscriptionPrice(
      mealSubtotal: (map['mealSubtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFees: (map['deliveryFees'] as num?)?.toDouble() ?? 0.0,
      freshpunkFee: (map['freshpunkFee'] as num?)?.toDouble() ?? 0.0,
      stripeFee: (map['stripeFee'] as num?)?.toDouble() ?? 0.0,
      stripeChargeTotal: (map['stripeChargeTotal'] as num?)?.toDouble() ?? 0.0,
      squareChargeTotal: (map['squareChargeTotal'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      mealCount: (map['mealCount'] as num?)?.toInt() ?? 0,
      stripeOnly: (map['stripeOnly'] as bool?) ?? false,
    );
  }
}
