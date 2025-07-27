import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/subscription.dart';

class StripeService {
  static const String _publishableKey = 'pk_test_51Rly3MAQ9rq5N6YJ07JcCml88ysYYunZlcUfEacyfjSjY6DZgoM0HOTCkPBOZLVYg40JzUgT9ykwJjjho3hXADuJ00acajs99Q';
  
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  static Future<void> init() async {
    // Skip Stripe initialization on web
    if (kIsWeb) return;
    
    Stripe.publishableKey = _publishableKey;
    await Stripe.instance.applySettings();
  }

  // Create Payment Intent for subscription
  static Future<Map<String, dynamic>> createPaymentIntent({
    required SubscriptionPlan plan,
    required String customerId,
  }) async {
    try {
      final callable = _functions.httpsCallable('createPaymentIntent');
      final result = await callable.call({
        'amount': (plan.monthlyPrice * 100).toInt(), // Amount in cents
        'currency': 'usd',
        'customer': customerId,
      });

      return result.data;
    } catch (e) {
      throw Exception('Failed to create payment intent: $e');
    }
  }

  // Create Stripe Customer
  static Future<Map<String, dynamic>> createCustomer({
    required String email,
    required String name,
  }) async {
    try {
      final callable = _functions.httpsCallable('createCustomer');
      final result = await callable.call({
        'email': email,
        'name': name,
      });

      return result.data;
    } catch (e) {
      throw Exception('Failed to create customer: $e');
    }
  }

  // Create Subscription
  static Future<Map<String, dynamic>> createSubscription({
    required String customerId,
    required String paymentMethodId,
    required SubscriptionPlan plan,
  }) async {
    try {
      final callable = _functions.httpsCallable('createSubscription');
      final result = await callable.call({
        'customer': customerId,
        'paymentMethod': paymentMethodId,
        'priceId': plan.priceId,
      });

      return result.data;
    } catch (e) {
      throw Exception('Failed to create subscription: $e');
    }
  }

  // Create Setup Intent for saving payment method
  static Future<Map<String, dynamic>> createSetupIntent({
    required String customerId,
  }) async {
    try {
      final callable = _functions.httpsCallable('createSetupIntent');
      final result = await callable.call({
        'customer': customerId,
      });

      return result.data;
    } catch (e) {
      throw Exception('Failed to create setup intent: $e');
    }
  }

  // Confirm Setup Intent (simplified)
  static Future<PaymentResult> confirmSetupIntent({
    required String clientSecret,
  }) async {
    try {
      final setupIntent = await Stripe.instance.confirmSetupIntent(
        paymentIntentClientSecret: clientSecret,
        params: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );

      return PaymentResult(
        success: setupIntent.status == 'succeeded',
        setupIntent: setupIntent,
        paymentMethodId: setupIntent.paymentMethodId,
        error: null,
      );
    } on StripeException catch (e) {
      return PaymentResult(
        success: false,
        setupIntent: null,
        paymentMethodId: null,
        error: e.error.localizedMessage ?? 'Setup failed',
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        setupIntent: null,
        paymentMethodId: null,
        error: 'An unexpected error occurred: $e',
      );
    }
  }

  // Cancel subscription
  static Future<Map<String, dynamic>> cancelSubscription({
    required String subscriptionId,
  }) async {
    try {
      final callable = _functions.httpsCallable('cancelSubscription');
      final result = await callable.call({
        'subscriptionId': subscriptionId,
      });

      return result.data;
    } catch (e) {
      throw Exception('Failed to cancel subscription: $e');
    }
  }

  // Update subscription
  static Future<Map<String, dynamic>> updateSubscription({
    required String subscriptionId,
    required SubscriptionPlan newPlan,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateSubscription');
      final result = await callable.call({
        'subscriptionId': subscriptionId,
        'newPriceId': newPlan.priceId,
      });

      return result.data;
    } catch (e) {
      throw Exception('Failed to update subscription: $e');
    }
  }
}

class PaymentResult {
  final bool success;
  final PaymentIntent? paymentIntent;
  final SetupIntent? setupIntent;
  final String? paymentMethodId;
  final String? error;

  PaymentResult({
    required this.success,
    this.paymentIntent,
    this.setupIntent,
    this.paymentMethodId,
    this.error,
  });
}
