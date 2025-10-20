import 'package:flutter/material.dart';
import '../theme/app_theme_v3.dart';
// Removed unused imports for cleaner tests

class LoginPageV3Test extends StatefulWidget {
  const LoginPageV3Test({super.key});

  @override
  State<LoginPageV3Test> createState() => _LoginPageV3TestState();
}

class _LoginPageV3TestState extends State<LoginPageV3Test> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      body: Center(
        child: Text('Test Login Page'),
      ),
    );
  }
}
