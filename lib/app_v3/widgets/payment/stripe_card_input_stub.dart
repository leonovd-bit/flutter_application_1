import 'package:flutter/material.dart';

/// Stub for StripeCardInputWeb on non-web platforms
/// This should never be instantiated since we check kIsWeb before using it
class StripeCardInputWeb extends StatelessWidget {
  final String clientSecret;
  final void Function(String) onSuccess;
  final void Function(String) onError;
  final String publishableKey;

  const StripeCardInputWeb({
    super.key,
    required this.clientSecret,
    required this.onSuccess,
    required this.onError,
    required this.publishableKey,
  });

  @override
  Widget build(BuildContext context) {
    throw UnsupportedError(
      'StripeCardInputWeb is only available on web platform',
    );
  }
}
