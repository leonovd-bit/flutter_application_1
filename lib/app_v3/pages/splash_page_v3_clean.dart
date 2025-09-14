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
      backgroundColor: AppThemeV3.surface,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Large brand logo with enhanced styling
              Container(
                width: 300,
                height: 300,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppThemeV3.accent.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 4,
                    ),
                  ],
                ),
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
              const SizedBox(height: 32),
              // Clean loading text
              Text(
                'Loading Fresh Punk...',
                style: AppThemeV3.textTheme.bodyLarge?.copyWith(
                  color: AppThemeV3.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
