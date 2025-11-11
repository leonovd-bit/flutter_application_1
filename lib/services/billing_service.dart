import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

/// Service for managing Stripe billing operations
/// Handles customer creation, payment intents, subscriptions, and payment methods
class BillingService {
  static final BillingService _instance = BillingService._internal();
  factory BillingService() => _instance;
  BillingService._internal();

  void _log(String message) => dev.log(message, name: 'BillingService');
  final _firestore = FirebaseFirestore.instance;
  final _functions = FirebaseFunctions.instance;
  final _auth = FirebaseAuth.instance;

  /// Stripe test mode publishable key
  static const String publishableKey =
      'pk_test_51Rly3MAQ9rq5N6YJ07JcCml88ysYYunZlcUfEacyfjSjY6DZgoM0HOTCkPBOZLVYg40JzUgT9ykwJjjho3hXADuJ00acajs99Q';

  /// Initialize Stripe with the publishable key
  /// Call this once during app startup (e.g., in main())
  static Future<void> initialize() async {
    Stripe.publishableKey = publishableKey;
    await Stripe.instance.applySettings();
  }

  /// Get the current user's UID (throws if not authenticated)
  String get _currentUserId {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('User must be authenticated to perform billing operations');
    }
    return uid;
  }

  /// Get or create a Stripe customer for the current user
  /// Stores the customer ID in Firestore under users/{uid}.stripeCustomerId
  Future<String> ensureCustomer() async {
    final uid = _currentUserId;
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final data = userDoc.data();

    // Return existing customer ID if present
    if (data != null && data['stripeCustomerId'] != null) {
      return data['stripeCustomerId'] as String;
    }

    // Create new customer via backend
    final user = _auth.currentUser!;
    final result = await _functions.httpsCallable('createCustomer').call({
      'email': user.email ?? '',
      'name': user.displayName ?? 'Customer',
    });

    final customerId = result.data['customer']['id'] as String;

    // Store customer ID in Firestore
    await _firestore.collection('users').doc(uid).set({
      'stripeCustomerId': customerId,
      'email': user.email,
      'displayName': user.displayName,
    }, SetOptions(merge: true));

    _log('Created Stripe customer: $customerId');
    return customerId;
  }

  /// Create a one-time payment intent for the given amount
  /// Returns the client secret and payment intent ID
  /// 
  /// Example usage:
  /// ```dart
  /// final result = await billingService.createOneTimePayment(
  ///   amountCents: 1999, // $19.99
  ///   metadata: {'orderId': 'order_123'},
  /// );
  /// ```
  Future<({String clientSecret, String paymentIntentId})> createOneTimePayment({
    required int amountCents,
    String currency = 'usd',
    Map<String, dynamic>? metadata,
  }) async {
    final customerId = await ensureCustomer();

    final result = await _functions.httpsCallable('createPaymentIntent').call({
      'amount': amountCents,
      'currency': currency,
      'customer': customerId,
      'metadata': metadata ?? {},
    });

    return (
      clientSecret: result.data['clientSecret'] as String,
      paymentIntentId: result.data['paymentIntentId'] as String,
    );
  }

  /// Confirm a payment intent using the flutter_stripe package
  /// Handles SCA (3D Secure) flows automatically
  /// 
  /// Returns true on success, false on cancellation, throws on error
  Future<bool> confirmPayment(String clientSecret) async {
    try {
      final result = await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
      );

      if (result.status == PaymentIntentsStatus.Succeeded) {
        _log('Payment confirmed successfully');
        return true;
      } else if (result.status == PaymentIntentsStatus.Canceled) {
        _log('Payment was canceled by user');
        return false;
      } else {
        throw Exception('Payment incomplete: ${result.status}');
      }
    } catch (e) {
      _log('Payment confirmation failed: $e');
      rethrow;
    }
  }

  /// Complete flow: create payment intent and confirm it
  /// Links the payment to an order via paymentIntentId
  /// 
  /// Example:
  /// ```dart
  /// final success = await billingService.processOrderPayment(
  ///   orderId: order.id,
  ///   amountCents: 1999, // $19.99
  /// );
  /// ```
  Future<bool> processOrderPayment({
    required String orderId,
    required int amountCents,
  }) async {
    try {
      // Create payment intent
      final payment = await createOneTimePayment(
        amountCents: amountCents,
        metadata: {'orderId': orderId},
      );

      // Link payment intent to order (webhook will confirm order on success)
      await _firestore.collection('orders').doc(orderId).update({
        'paymentIntentId': payment.paymentIntentId,
      });

      // Confirm payment with user interaction
      return await confirmPayment(payment.clientSecret);
    } catch (e) {
      _log('Order payment processing failed: $e');
      rethrow;
    }
  }

  /// Save a payment method for future use without charging
  /// Returns the setup intent client secret
  Future<String> createSetupIntent() async {
    final customerId = await ensureCustomer();

    final result = await _functions.httpsCallable('createSetupIntent').call({
      'customer': customerId,
    });

    return result.data['client_secret'] as String;
  }

  /// Confirm a setup intent to save a card
  /// Returns true on success, false on cancellation
  Future<bool> confirmSetupIntent(String clientSecret) async {
    try {
      final result = await Stripe.instance.confirmSetupIntent(
        paymentIntentClientSecret: clientSecret,
        params: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );

      if (result.status == PaymentIntentsStatus.Succeeded) {
        _log('Payment method saved successfully');
        return true;
      } else if (result.status == PaymentIntentsStatus.Canceled) {
        _log('Setup was canceled by user');
        return false;
      } else {
        throw Exception('Setup incomplete: ${result.status}');
      }
    } catch (e) {
      _log('Setup intent confirmation failed: $e');
      rethrow;
    }
  }

  /// Save a card for future use (complete flow)
  Future<bool> saveCardForFutureUse() async {
    try {
      final clientSecret = await createSetupIntent();
      return await confirmSetupIntent(clientSecret);
    } catch (e) {
      _log('Failed to save card: $e');
      rethrow;
    }
  }

  /// Create a subscription to a Stripe price
  /// The customer must have a default payment method set
  /// 
  /// Example:
  /// ```dart
  /// await billingService.createSubscription(
  ///   priceId: 'price_1234567890',
  /// );
  /// ```
  Future<Map<String, dynamic>> createSubscription({
    required String priceId,
    String? paymentMethodId,
  }) async {
    final customerId = await ensureCustomer();

    final result = await _functions.httpsCallable('createSubscription').call({
      'customer': customerId,
      'priceId': priceId,
      if (paymentMethodId != null) 'paymentMethod': paymentMethodId,
    });

    final subscription = result.data['subscription'];

    // Check if SCA is required for first invoice
    final latestInvoice = subscription['latest_invoice'];
    if (latestInvoice != null && latestInvoice is Map) {
      final paymentIntent = latestInvoice['payment_intent'];
      if (paymentIntent != null &&
          paymentIntent is Map &&
          paymentIntent['status'] == 'requires_action') {
        // Confirm the payment intent for SCA
        final clientSecret = paymentIntent['client_secret'] as String;
        final confirmed = await confirmPayment(clientSecret);
        if (!confirmed) {
          throw Exception('Subscription payment confirmation failed');
        }
      }
    }

    _log('Subscription created: ${subscription['id']}');
    return subscription;
  }

  /// List all saved payment methods for the current user
  Future<List<Map<String, dynamic>>> listPaymentMethods() async {
    final customerId = await ensureCustomer();

    final result = await _functions.httpsCallable('listPaymentMethods').call({
      'customer': customerId,
    });

    return List<Map<String, dynamic>>.from(result.data['data']);
  }

  /// Set a payment method as the default for invoices
  Future<void> setDefaultPaymentMethod(String paymentMethodId) async {
    final customerId = await ensureCustomer();

    await _functions.httpsCallable('setDefaultPaymentMethod').call({
      'customer': customerId,
      'payment_method': paymentMethodId,
    });

    _log('Default payment method updated: $paymentMethodId');
  }

  /// Remove a saved payment method
  Future<void> detachPaymentMethod(String paymentMethodId) async {
    await _functions.httpsCallable('detachPaymentMethod').call({
      'payment_method': paymentMethodId,
    });

    _log('Payment method detached: $paymentMethodId');
  }

  /// Cancel a subscription (at period end)
  Future<void> cancelSubscription(String subscriptionId) async {
    await _functions.httpsCallable('cancelSubscription').call({
      'subscriptionId': subscriptionId,
    });

    _log('Subscription canceled: $subscriptionId');
  }

  /// Update a subscription to a different price
  Future<void> updateSubscription({
    required String subscriptionId,
    required String newPriceId,
  }) async {
    await _functions.httpsCallable('updateSubscription').call({
      'subscriptionId': subscriptionId,
      'newPriceId': newPriceId,
    });

    _log('Subscription updated: $subscriptionId -> $newPriceId');
  }

  /// Pause a subscription
  Future<void> pauseSubscription(String subscriptionId) async {
    await _functions.httpsCallable('pauseSubscription').call({
      'subscriptionId': subscriptionId,
    });

    _log('Subscription paused: $subscriptionId');
  }

  /// Resume a paused subscription
  Future<void> resumeSubscription(String subscriptionId) async {
    await _functions.httpsCallable('resumeSubscription').call({
      'subscriptionId': subscriptionId,
    });

    _log('Subscription resumed: $subscriptionId');
  }

  /// Get available billing options (installments, payment method types)
  Future<Map<String, dynamic>> getBillingOptions(int amountCents) async {
    final customerId = await ensureCustomer();

    final result = await _functions.httpsCallable('getBillingOptions').call({
      'amount': amountCents,
      'currency': 'usd',
      'customer': customerId,
    });

    return result.data as Map<String, dynamic>;
  }
}
