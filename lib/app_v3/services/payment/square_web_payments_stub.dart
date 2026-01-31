import 'package:flutter/widgets.dart';

class SquareWebPayments {
  SquareWebPayments._();

  static final SquareWebPayments instance = SquareWebPayments._();

  Future<void> initialize({
    required String applicationId,
    required String locationId,
    required String env,
  }) async {
    throw UnsupportedError('Square Web Payments is only supported on web.');
  }

  Future<String> tokenize() async {
    throw UnsupportedError('Square Web Payments is only supported on web.');
  }

  Widget buildCardView() {
    return const SizedBox.shrink();
  }
}
