import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pricing_service.dart';

import '../../../utils/cloud_functions_helper.dart';

/// Service to create invoices for subscription billing
/// Handles upfront charging before meal delivery starts
class InvoicingService {
  static final InvoicingService _instance = InvoicingService._internal();

  factory InvoicingService() => _instance;

  InvoicingService._internal();

  static const _region = 'us-central1';
  final _auth = FirebaseAuth.instance;
  final _functions = FirebaseFunctions.instanceFor(region: _region);

  HttpsCallable _callable(String name) {
    return callableForPlatform(
      functions: _functions,
      functionName: name,
      region: _region,
    );
  }

  /// Create an invoice for subscription based on meal selections
  /// 
  /// This should be called after user confirms their meal selections
  /// and before the subscription is finalized.
  /// 
  /// Returns invoiceId on success
  Future<String> createSubscriptionInvoice({
    required String customerId,
    required SubscriptionPrice pricing,
    required List<Map<String, dynamic>> mealSelections,
    required List<Map<String, dynamic>> deliverySchedule,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
  final callable = _callable('createSubscriptionInvoice');
      final result = await callable.call({
        'customerId': customerId,
        'userId': userId,
        'subscriptionPricing': pricing.toMap(),
        'mealSelections': mealSelections,
        'deliverySchedule': deliverySchedule,
      });

      final data = result.data as Map<dynamic, dynamic>;
      if (data['success'] == true) {
        return data['invoiceId'] as String;
      } else {
        throw Exception(data['error'] ?? 'Failed to create invoice');
      }
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Invoice creation error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to create invoice: $e');
    }
  }

  /// Get details of a specific invoice
  Future<Map<String, dynamic>> getInvoiceDetails(String invoiceId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User must be authenticated');
    }

    try {
  final callable = _callable('getInvoiceDetails');
      final result = await callable.call({'invoiceId': invoiceId});

      final data = result.data as Map<dynamic, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['invoice'] as Map);
      } else {
        throw Exception(data['error'] ?? 'Failed to get invoice');
      }
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Invoice retrieval error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to get invoice: $e');
    }
  }
}
