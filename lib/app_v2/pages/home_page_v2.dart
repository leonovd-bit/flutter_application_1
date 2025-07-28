import 'package:flutter/material.dart';
import '../theme/app_theme_v2.dart';

class HomePageV2 extends StatelessWidget {
  const HomePageV2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      backgroundColor: AppThemeV2.background,
      body: Center(
        child: Text(
          'Home Page V2',
          style: AppThemeV2.lightTheme.textTheme.headline5,
        ),
      ),
    );
  }
}
