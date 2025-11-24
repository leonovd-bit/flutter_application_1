import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../utils/cloud_functions_helper.dart';
import 'environment_service.dart';

/// Central helper for sending transactional SMS messages via Cloud Functions.
class SMSService {
  SMSService._();

  static const _region = 'us-central1';
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: _region);

  static HttpsCallable _callable(String name) {
    return callableForPlatform(
      functions: _functions,
      functionName: name,
      region: _region,
    );
  }

  /// Whether Twilio/SMS credentials are configured in the current environment.
  static bool get isConfigured => EnvironmentService.isTwilioConfigured;

  static Future<bool> sendOrderConfirmation({
    required String toNumber,
    required String orderNumber,
    required String customerName,
    required String estimatedTime,
    required List<String> items,
  }) {
    return _dispatch(
      event: 'order_confirmation',
      payload: {
        'toNumber': toNumber,
        'orderNumber': orderNumber,
        'customerName': customerName,
        'estimatedTime': estimatedTime,
        'items': items,
      },
    );
  }

  static Future<bool> sendDeliveryUpdate({
    required String toNumber,
    required String orderNumber,
    required String status,
    String? eta,
    String? driverName,
  }) {
    return _dispatch(
      event: 'delivery_update',
      payload: {
        'toNumber': toNumber,
        'orderNumber': orderNumber,
        'status': status,
        if (eta != null) 'eta': eta,
        if (driverName != null) 'driverName': driverName,
      },
    );
  }

  static Future<bool> sendDriverArrival({
    required String toNumber,
    required String orderNumber,
    required String driverName,
    String? driverPhone,
  }) {
    return _dispatch(
      event: 'driver_arrival',
      payload: {
        'toNumber': toNumber,
        'orderNumber': orderNumber,
        'driverName': driverName,
        if (driverPhone != null) 'driverPhone': driverPhone,
      },
    );
  }

  static Future<bool> sendSubscriptionReminder({
    required String toNumber,
    required String customerName,
    required String nextDeliveryDate,
    required String planName,
  }) {
    return _dispatch(
      event: 'subscription_reminder',
      payload: {
        'toNumber': toNumber,
        'customerName': customerName,
        'nextDeliveryDate': nextDeliveryDate,
        'planName': planName,
      },
    );
  }

  static Future<bool> sendTestSMS(String toNumber) {
    return _dispatch(
      event: 'test',
      payload: {
        'toNumber': toNumber,
      },
    );
  }

  static Future<bool> _dispatch({
    required String event,
    required Map<String, dynamic> payload,
  }) async {
    if (!isConfigured) {
      debugPrint('[SMSService] SMS skipped ($event): Twilio not configured');
      return false;
    }

    try {
      final callable = _callable('sendTransactionalSms');
      final result = await callable.call({
        'event': event,
        'payload': payload,
      });

      if (result.data is Map && result.data['success'] == true) {
        return true;
      }

      debugPrint('[SMSService] SMS callable returned non-success for $event: ${result.data}');
      return false;
    } catch (e) {
      debugPrint('[SMSService] Failed to dispatch $event SMS: $e');
      return false;
    }
  }
}
