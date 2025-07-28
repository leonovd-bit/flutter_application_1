import 'package:flutter/material.dart';
import '../theme/app_theme_v2.dart';

class MealSchedulePageV2 extends StatelessWidget {
  const MealSchedulePageV2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meal Schedule')),
      backgroundColor: AppThemeV2.background,
      body: Center(
        child: Text(
          'Meal Schedule Page V2',
          style: AppThemeV2.lightTheme.textTheme.headline5,
        ),
      ),
    );
  }
}
