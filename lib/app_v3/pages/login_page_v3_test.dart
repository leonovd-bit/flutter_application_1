import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../theme/app_theme_v3.dart';
import 'signup_page_v3.dart';
import 'home_page_v3.dart';
import 'welcome_page_v3.dart';

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
