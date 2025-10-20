import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();

  // Configure these for your environment (see STRIPE_BACKEND_API.md)
  // Safe to embed publishable key (test/live). Secret key must stay server-side.
  static const String _publishableKey = 'pk_test_51Rly3MAQ9rq5N6YJ07JcCml88ysYYunZlcUfEacyfjSjY6DZgoM0HOTCkPBOZLVYg40JzUgT9ykwJjjho3hXADuJ00acajs99Q';

  bool _initialized = false;
  // Match Cloud Functions region
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-east4');

  Future<void> init() async {
    if (_initialized) return;
    Stripe.publishableKey = _publishableKey;
    await Stripe.instance.applySettings();
    _initialized = true;
  }

  Future<String?> _ensureCustomer({required String email, String? name}) async {
    final callable = _functions.httpsCallable('createCustomer');
    final result = await callable.call({
      'email': email,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    });
    final data = result.data as Map?;
    final customer = (data?['customer'] as Map?) ?? {};
    return customer['id'] as String?;
  }

  Future<String?> _createSetupIntent(String customerId) async {
    final callable = _functions.httpsCallable('createSetupIntent');
    final result = await callable.call({
      'customer': customerId,
    });
    final data = result.data as Map?;
    return data?['client_secret'] as String?;
  }

  Future<bool> addPaymentMethod(BuildContext context) async {
    try {
      await init();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');
      final customerId = await _ensureCustomer(email: user.email ?? '', name: user.displayName);
      if (customerId == null) throw Exception('Failed to create Stripe customer');

      final clientSecret = await _createSetupIntent(customerId);
      if (clientSecret == null) throw Exception('Failed to create setup intent');

      // Init PaymentSheet for SetupIntent
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'FreshPunk',
          setupIntentClientSecret: clientSecret,
          allowsDelayedPaymentMethods: true,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      return true;
    } on StripeException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.error.message ?? 'Stripe error')),
        );
      }
      return false;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Add payment failed: $e')),
        );
      }
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> listPaymentMethods() async {
    try {
  final callable = _functions.httpsCallable('listPaymentMethods');
  final result = await callable.call();
  final resp = (result.data as Map?) ?? {};
  final list = (resp['data'] as List? ?? []).cast<dynamic>();
      return list.map<Map<String, dynamic>>((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> detachPaymentMethod(String paymentMethodId) async {
    try {
  final callable = _functions.httpsCallable('detachPaymentMethod');
  final result = await callable.call({'payment_method': paymentMethodId});
  final data = result.data as Map?;
  return (data?['success'] == true);
    } catch (_) {
      return false;
    }
  }

  Future<bool> setDefaultPaymentMethod(String paymentMethodId) async {
    try {
      final callable = _functions.httpsCallable('setDefaultPaymentMethod');
      final result = await callable.call({'payment_method': paymentMethodId});
      final data = result.data as Map?;
      return (data?['success'] == true);
    } catch (_) {
      return false;
    }
  }

  Future<String?> createSubscription({
    required String customerId,
    required String paymentMethodId,
    required String priceId,
  }) async {
    try {
      final callable = _functions.httpsCallable('createSubscription');
      final result = await callable.call({
        'customer': customerId,
        'paymentMethod': paymentMethodId,
        'priceId': priceId,
      });
      final data = result.data as Map?;
      final subscription = data?['subscription'] as Map?;
      return subscription?['id'] as String?;
    } catch (e) {
      debugPrint('Failed to create subscription: $e');
      return null;
    }
  }

}
