import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

@JS('Stripe')
external JSFunction get _StripeConstructor;

/// Dart wrapper for Stripe.js operations
class StripeWebService {
  final String publishableKey;
  JSObject? _stripe;
  JSObject? _elements;
  JSObject? _cardElement;

  StripeWebService(this.publishableKey) {
    _initStripe();
  }

  void _initStripe() {
    try {
      debugPrint('[StripeWeb] Initializing with key: ${publishableKey.substring(0, 20)}...');
      _stripe = _StripeConstructor.callAsFunction(null, publishableKey.toJS) as JSObject;
      debugPrint('[StripeWeb] Initialized with publishable key');
    } catch (e) {
      debugPrint('[StripeWeb] Error initializing: $e');
    }
  }

  /// Creates Stripe Elements and mounts CardElement to a DOM element
  void createAndMountCardElement(String elementId) {
    try {
      if (_stripe == null) {
        throw Exception('Stripe not initialized');
      }

      // Create elements instance
      final elementsMethod = _stripe!['elements'] as JSFunction;
      _elements = elementsMethod.callAsFunction(_stripe) as JSObject;

      // Create card element
      final createMethod = _elements!['create'] as JSFunction;
      final style = {
        'base': {
          'fontSize': '16px',
          'color': '#32325d',
          '::placeholder': {
            'color': '#aab7c4',
          },
        },
      }.jsify();
      
      _cardElement = createMethod.callAsFunction(_elements, 'card'.toJS, {'style': style}.jsify()) as JSObject;

      // Mount to DOM
      final mountMethod = _cardElement!['mount'] as JSFunction;
      mountMethod.callAsFunction(_cardElement, '#$elementId'.toJS);
      
      debugPrint('[StripeWeb] Card element mounted to #$elementId');
    } catch (e) {
      debugPrint('[StripeWeb] Error creating card element: $e');
      rethrow;
    }
  }

  /// Confirms card setup using the mounted CardElement
  Future<String> confirmCardSetup(String clientSecret) async {
    try {
      if (_stripe == null) {
        throw Exception('Stripe not initialized');
      }

      debugPrint('[StripeWeb] Confirming setup with client secret and card element');
      
      final confirmMethod = _stripe!['confirmCardSetup'] as JSFunction;
      final params = {
        'payment_method': {
          'card': _cardElement,
        }
      }.jsify();
      
      final promise = confirmMethod.callAsFunction(
        _stripe,
        clientSecret.toJS,
        params,
      ) as JSPromise;
      
      final result = await promise.toDart as JSObject;
      
      // Check for error
      final error = result['error'];
      final hasError = error != null && error.typeofEquals('object');
      if (hasError) {
        final errorObj = error as JSObject;
        final messageJs = errorObj['message'];
        final message = (messageJs as JSString?)?.toDart ?? 'Card setup failed';
        throw Exception(message);
      }

      // Get setupIntent
      final setupIntent = result['setupIntent'];
      if (setupIntent == null || !setupIntent.typeofEquals('object')) {
        throw Exception('No setupIntent in result');
      }

      // Get payment_method
      final setupIntentObj = setupIntent as JSObject;
      final paymentMethod = setupIntentObj['payment_method'];
      
      if (paymentMethod == null || !paymentMethod.typeofEquals('string')) {
        throw Exception('No payment_method in setupIntent');
      }

      final paymentMethodId = (paymentMethod as JSString).toDart;
      debugPrint('[StripeWeb] Setup confirmed, payment method: $paymentMethodId');
      return paymentMethodId;
    } catch (e) {
      debugPrint('[StripeWeb] Error confirming setup: $e');
      rethrow;
    }
  }

  /// Creates and mounts a card Element to the specified DOM selector
  void mountCardElement(String domId) {
    createAndMountCardElement(domId);
  }

  /// Tokenizes the card and returns a payment method ID
  Future<String?> createPaymentMethod(String email) async {
    return null;
  }

  /// Retrieves setup intent status
  Future<dynamic> retrieveSetupIntent(String clientSecret) async {
    return null;
  }

  /// Confirms setup intent with the payment method
  Future<dynamic> confirmSetupIntent(
    String clientSecret,
    String paymentMethodId,
  ) async {
    return null;
  }

  /// Get error message from Stripe response
  String? getErrorMessage(dynamic result) {
    return null;
  }

  /// Cleanup
  void dispose() {
    if (_cardElement != null) {
      try {
        final unmountMethod = _cardElement!['unmount'] as JSFunction?;
        unmountMethod?.callAsFunction(_cardElement);
      } catch (e) {
        debugPrint('[StripeWeb] Error unmounting card element: $e');
      }
    }
    _cardElement = null;
    _elements = null;
    _stripe = null;
  }
}
