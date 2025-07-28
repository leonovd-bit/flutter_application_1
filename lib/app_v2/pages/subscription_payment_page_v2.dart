import 'package:flutter/material.dart';
import '../theme/app_theme_v2.dart';

class SubscriptionPaymentPageV2 extends StatelessWidget {
  const SubscriptionPaymentPageV2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      backgroundColor: AppThemeV2.background,
      body: Center(
        child: Text(
          'Subscription Payment Page V2',
          style: AppThemeV2.lightTheme.textTheme.headline5,
        ),
      ),
    );
  }
}
