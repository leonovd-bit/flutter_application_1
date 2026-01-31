import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class SquareWebPayments {
  SquareWebPayments._();

  static final SquareWebPayments instance = SquareWebPayments._();

  static const MethodChannel _channel = MethodChannel('freshpunk/square_payments');

  Future<void> initialize({
    required String applicationId,
    required String locationId,
    required String env,
  }) async {
    await _channel.invokeMethod('initialize', {
      'applicationId': applicationId,
      'locationId': locationId,
      'env': env,
    });
  }

  Future<String> tokenize() async {
    final result = await _channel.invokeMethod<String>('tokenizeCard');
    if (result == null || result.isEmpty) {
      throw Exception('Square tokenization returned an empty token');
    }
    return result;
  }

  Widget buildCardView() {
    return const SizedBox.shrink();
  }
}
