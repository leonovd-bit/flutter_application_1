import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../utils/cloud_functions_helper.dart';

// Conditional import for web-only widget
import '../../widgets/payment/stripe_card_input_web.dart'
    if (dart.library.io) '../../widgets/payment/stripe_card_input_stub.dart';



class StripeService {
  StripeService._();
  static final StripeService instance = StripeService._();

  // Configure these for your environment (see STRIPE_BACKEND_API.md)
  // Safe to embed publishable key (test/live). Secret key must stay server-side.
  static const String _publishableKey = 'pk_test_51Rly3MAQ9rq5N6YJ07JcCml88ysYYunZlcUfEacyfjSjY6DZgoM0HOTCkPBOZLVYg40JzUgT9ykwJjjho3hXADuJ00acajs99Q';

  bool _initialized = false;
  static const _region = 'us-central1';
  // Match Cloud Functions region (us-central1 is where functions are deployed)
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: _region);

  HttpsCallable _callable(String name) {
    return callableForPlatform(
      functions: _functions,
      functionName: name,
      region: _region,
    );
  }

  Future<void> init() async {
    if (_initialized) return;
    Stripe.publishableKey = _publishableKey;
    await Stripe.instance.applySettings();
    _initialized = true;
  }

  Future<String?> _ensureCustomer({required String email, String? name}) async {
  final callable = _callable('createCustomer');
    final result = await callable.call({
      'email': email,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    });
    final data = result.data as Map?;
    final customer = (data?['customer'] as Map?) ?? {};
    return customer['id'] as String?;
  }

  Future<String?> _createSetupIntent(String customerId) async {
    try {
  final callable = _callable('createSetupIntent');
      debugPrint('[Stripe] Creating setup intent for customer: $customerId');
      final result = await callable.call({
        'customer': customerId,
      });
      final data = result.data as Map?;
      debugPrint('[Stripe] Setup intent response: $data');
      final clientSecret = data?['client_secret'] as String?;
      if (clientSecret == null) {
        debugPrint('[Stripe] ERROR: No client_secret in response');
      }
      return clientSecret;
    } catch (e) {
      debugPrint('[Stripe] ERROR creating setup intent: $e');
      rethrow;
    }
  }

  Future<bool> addPaymentMethod(BuildContext context) async {
    try {
      debugPrint('[Stripe] addPaymentMethod starting');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');
      
      debugPrint('[Stripe] Ensuring customer exists for user: ${user.email}');
      final customerId = await _ensureCustomer(email: user.email ?? '', name: user.displayName);
      if (customerId == null) throw Exception('Failed to create Stripe customer');
      debugPrint('[Stripe] Customer ID: $customerId');

      // Web: use Stripe Elements with custom widget
      if (kIsWeb) {
        debugPrint('[Stripe] Web platform - creating setup intent');
        final clientSecret = await _createSetupIntent(customerId);
        if (clientSecret == null) throw Exception('Failed to create setup intent - no client_secret returned');

        debugPrint('[Stripe] Web platform - using Stripe Elements with secret: ${clientSecret.substring(0, 20)}...');
        
        if (!context.mounted) return false;
        
        // Import is conditional via if (kIsWeb) check
        // ignore: undefined_prefixed_name
        final result = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            // Dynamic import to avoid compile errors on non-web platforms
            return _buildStripeElementsDialog(context, clientSecret);
          },
        );
        
        return result ?? false;
      }

      // Mobile/Desktop: use SetupIntent + PaymentSheet
      await init();
      final clientSecret = await _createSetupIntent(customerId);
      if (clientSecret == null) throw Exception('Failed to create setup intent');

      debugPrint('[Stripe] Using Stripe PaymentSheet with SetupIntent');
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
      debugPrint('[Stripe] Error: $e');
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
      debugPrint('[Stripe] Fetching payment methods from Firebase Function...');
      final callable = _callable('listPaymentMethods');
      final result = await callable.call();
      debugPrint('[Stripe] Firebase Function result: ${result.data}');
      final resp = (result.data as Map?) ?? {};
      final list = (resp['data'] as List? ?? []).cast<dynamic>();
      debugPrint('[Stripe] Parsed ${list.length} payment methods');
      return list.map<Map<String, dynamic>>((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (e, stack) {
      debugPrint('[Stripe] Error fetching payment methods: $e');
      debugPrint('[Stripe] Stack trace: $stack');
      return [];
    }
  }

  Future<bool> detachPaymentMethod(String paymentMethodId) async {
    try {
  final callable = _callable('detachPaymentMethod');
  final result = await callable.call({'payment_method': paymentMethodId});
  final data = result.data as Map?;
  return (data?['success'] == true);
    } catch (_) {
      return false;
    }
  }

  Future<bool> setDefaultPaymentMethod(String paymentMethodId) async {
    try {
  final callable = _callable('setDefaultPaymentMethod');
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
  final callable = _callable('createSubscription');
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

  Widget _buildStripeElementsDialog(BuildContext context, String clientSecret) {
    // Import conditionally to avoid errors on non-web platforms
    if (kIsWeb) {
      // Dynamic import that only resolves on web
      // ignore: undefined_prefixed_name
      final widget = StripeCardInputWeb(
        clientSecret: clientSecret,
        publishableKey: _publishableKey,
        onSuccess: (paymentMethodId) {
          debugPrint('[Stripe] Payment method added: $paymentMethodId');
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Payment method added successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        },
        onError: (error) {
          debugPrint('[Stripe] Error: $error');
          Navigator.of(context).pop(false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add card: $error'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        },
      );

      return AlertDialog(
        title: const Text('Add Payment Method'),
        content: SizedBox(
          width: 500,
          child: widget,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      );
    }

    // Fallback for non-web (should never happen due to kIsWeb check in caller)
    return const AlertDialog(
      title: Text('Error'),
      content: Text('This feature is only available on web'),
    );
  }

}
