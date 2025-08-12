import 'package:flutter/material.dart';
import '../theme/app_theme_v3.dart';
import 'welcome_page_v3.dart';

class SplashPageV3 extends StatefulWidget {
  const SplashPageV3({super.key});

  @override
  State<SplashPageV3> createState() => _SplashPageV3State();
}

class _SplashPageV3State extends State<SplashPageV3> {
  @override
  void initState() {
    super.initState();
    _navigateToWelcome();
  }

  void _navigateToWelcome() async {
    // Show splash screen for 3 seconds
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomePageV3()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      body: Container(
        decoration: BoxDecoration(gradient: AppThemeV3.backgroundGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Large brand logo without background box
              SizedBox(
                width: 280,
                height: 280,
                child: Image.asset(
                  'assets/images/freshpunk_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 48),
              // Progress indicator
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(AppThemeV3.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}