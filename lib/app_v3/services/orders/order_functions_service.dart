import 'package:cloud_functions/cloud_functions.dart';

/// Lightweight wrapper around Firebase Callable Cloud Functions
/// for orders and payments. Safe to import anywhere; no UI coupling.
class OrderFunctionsService {
  OrderFunctionsService._();
  static final instance = OrderFunctionsService._();

  // Match server region (see setGlobalOptions in Functions):
  final _functions = FirebaseFunctions.instanceFor(region: 'us-east4');

  // Orders
  Future<Map<String, dynamic>> placeOrder({
    required List<Map<String, dynamic>> items,
    required String addressId,
    String? scheduleName,
    DateTime? deliveryDate,
  }) async {
    final callable = _functions.httpsCallable('placeOrder');
    final res = await callable.call({
      'items': items,
      'addressId': addressId,
      'scheduleName': scheduleName,
      'deliveryDate': deliveryDate?.toIso8601String(),
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<bool> cancelOrder(String orderId) async {
    final callable = _functions.httpsCallable('cancelOrder');
    final res = await callable.call({'orderId': orderId});
    final data = Map<String, dynamic>.from(res.data as Map);
    return data['success'] == true;
  }

  // Payments (Stripe)
  Future<Map<String, dynamic>> createPaymentIntent({
    required int amount,
    String currency = 'usd',
    String? customer,
    String? orderId,
  }) async {
    // Defensive client-side validation to avoid generic INTERNAL from server
  // 'amount' is already declared as int (cents); no need for runtime type check.
    if (amount <= 0) {
      throw Exception('Amount must be positive integer (cents).');
    }
    if (currency != 'usd') {
      throw Exception('Only USD currency is supported at this time.');
    }
    final callable = _functions.httpsCallable('createPaymentIntent');
    final res = await callable.call({
      'amount': amount,
      'currency': currency,
      'customer': customer,
      'metadata': orderId == null ? null : {'orderId': orderId},
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> getBillingOptions({
    required int amount,
    String currency = 'usd',
    String? customer,
    String? paymentMethod,
  }) async {
    final callable = _functions.httpsCallable('getBillingOptions');
    final res = await callable.call({
      'amount': amount,
      'currency': currency,
      'customer': customer,
      'paymentMethod': paymentMethod,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> createCustomer({
    required String email,
    String? name,
  }) async {
    final callable = _functions.httpsCallable('createCustomer');
    final res = await callable.call({'email': email, 'name': name});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> createSetupIntent({
    required String customer,
  }) async {
    final callable = _functions.httpsCallable('createSetupIntent');
    final res = await callable.call({'customer': customer});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> createSubscription({
    required String customer,
    required String paymentMethod,
    required String priceId,
  }) async {
    final callable = _functions.httpsCallable('createSubscription');
    final res = await callable.call({
      'customer': customer,
      'paymentMethod': paymentMethod,
      'priceId': priceId,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> updateSubscription({
    required String subscriptionId,
    required String newPriceId,
  }) async {
    final callable = _functions.httpsCallable('updateSubscription');
    final res = await callable.call({
      'subscriptionId': subscriptionId,
      'newPriceId': newPriceId,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<bool> cancelSubscription(String subscriptionId) async {
    final callable = _functions.httpsCallable('cancelSubscription');
    final res = await callable.call({'subscriptionId': subscriptionId});
    final data = Map<String, dynamic>.from(res.data as Map);
    return data['subscription'] != null;
  }

  Future<bool> pauseSubscription(String subscriptionId) async {
    final callable = _functions.httpsCallable('pauseSubscription');
    final res = await callable.call({'subscriptionId': subscriptionId});
    final data = Map<String, dynamic>.from(res.data as Map);
    return data['subscription'] != null;
  }

  Future<bool> resumeSubscription(String subscriptionId) async {
    final callable = _functions.httpsCallable('resumeSubscription');
    final res = await callable.call({'subscriptionId': subscriptionId});
    final data = Map<String, dynamic>.from(res.data as Map);
    return data['subscription'] != null;
  }

  Future<List<Map<String, dynamic>>> listPaymentMethods({
    String? customer,
    String? email,
    String? name,
  }) async {
    final callable = _functions.httpsCallable('listPaymentMethods');
    final res = await callable.call({
      'customer': customer,
      'email': email,
      'name': name,
    });
    final data = Map<String, dynamic>.from(res.data as Map);
    final list = (data['data'] as List?) ?? const [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<bool> detachPaymentMethod(String paymentMethodId) async {
    final callable = _functions.httpsCallable('detachPaymentMethod');
    final res = await callable.call({'payment_method': paymentMethodId});
    final data = Map<String, dynamic>.from(res.data as Map);
    return data['success'] == true;
  }

  Future<bool> setDefaultPaymentMethod({
    String? customer,
    String? email,
    String? name,
    required String paymentMethodId,
  }) async {
    final callable = _functions.httpsCallable('setDefaultPaymentMethod');
    final res = await callable.call({
      'customer': customer,
      'email': email,
      'name': name,
      'payment_method': paymentMethodId,
    });
    final data = Map<String, dynamic>.from(res.data as Map);
    return data['success'] == true;
  }

  // Connectivity check
  Future<Map<String, dynamic>> ping() async {
    final callable = _functions.httpsCallable('ping');
    final res = await callable.call();
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<bool> registerFcmToken({
    required String token,
    String? platform,
  }) async {
    final callable = _functions.httpsCallable('registerFcmToken');
    final res = await callable.call({'token': token, 'platform': platform});
    final data = Map<String, dynamic>.from(res.data as Map);
    return data['success'] == true;
  }
}
