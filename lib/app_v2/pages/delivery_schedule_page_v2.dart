import 'package:flutter/material.dart';
import '../theme/app_theme_v2.dart';

class DeliverySchedulePageV2 extends StatelessWidget {
  const DeliverySchedulePageV2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Schedule')),
      backgroundColor: AppThemeV2.background,
      body: Center(
        child: Text(
          'Delivery Schedule Page V2',
          style: AppThemeV2.lightTheme.textTheme.headline5,
        ),
      ),
    );
  }
}
