import 'package:flutter/material.dart';
import '../../theme/app_theme_v3.dart';
import 'choose_meal_plan_page_v3.dart';

class OnboardingChoicePageV3 extends StatelessWidget {
  const OnboardingChoicePageV3({super.key});

  @override
  Widget build(BuildContext context) {
    print('[OnboardingChoice] Building OnboardingChoicePageV3');
    
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        title: const Text('Welcome to Victus!'),
        backgroundColor: AppThemeV3.accent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Remove back button
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Victus Logo/Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppThemeV3.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  size: 50,
                  color: AppThemeV3.accent,
                ),
              ),
              
              const SizedBox(height: 32),
              
              Text(
                'Welcome to Victus!',
                style: AppThemeV3.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppThemeV3.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                'How would you like to set up your meal plan?',
                style: AppThemeV3.textTheme.bodyLarge?.copyWith(
                  color: AppThemeV3.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 48),
              
              // Quick Setup Option
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppThemeV3.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppThemeV3.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.flash_on,
                          color: AppThemeV3.accent,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Quick Setup',
                          style: AppThemeV3.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppThemeV3.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Choose from our pre-designed meal plans and get started immediately. Perfect if you know what you want.',
                      style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                        color: AppThemeV3.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _navigateToMealPlanSelection(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppThemeV3.accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Get Started',
                          style: AppThemeV3.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToMealPlanSelection(BuildContext context) {
    print('[OnboardingChoice] Navigating to meal plan selection');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChooseMealPlanPageV3(isSignupFlow: true),
      ),
    );
  }
}