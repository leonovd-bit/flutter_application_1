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
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WelcomePageV3()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Match logo's white background color
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Large brand logo - clean display on white background
              Container(
                width: 300,
                height: 300,
                padding: const EdgeInsets.all(20),
                child: Image.asset(
                  'assets/images/freshpunk_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 48),
              // Progress indicator with Victus brand color
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF000000)), // Victus black
                ),
              ),
              const SizedBox(height: 32),
              // Clean loading text
              Text(
                'Loading Victus...',
                style: AppThemeV3.textTheme.bodyLarge?.copyWith(
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
