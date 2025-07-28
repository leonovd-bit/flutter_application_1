import 'package:flutter/material.dart';
import '../theme/app_theme_v2.dart';

class SignupPageV2 extends StatelessWidget {
  const SignupPageV2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      backgroundColor: AppThemeV2.background,
      body: Center(
        child: Text(
          'Sign Up Page V2',
          style: AppThemeV2.lightTheme.textTheme.headline5,
        ),
      ),
    );
  }
}
