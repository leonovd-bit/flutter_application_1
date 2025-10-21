import 'package:flutter/material.dart';
import '../theme/app_theme_v3.dart';
import 'choose_meal_plan_page_v3.dart';

class OnboardingChoicePageV3 extends StatelessWidget {
  const OnboardingChoicePageV3({super.key});

  @override
  Widget build(BuildContext context) {
    print('[OnboardingChoice] Building OnboardingChoicePageV3');
    
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header
              const SizedBox(height: 40),
              
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
              
              const SizedBox(height: 24),
              
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
              
              const SizedBox(height: 32),
              
              // Choice Cards  
              Expanded(
                child: Column(
                  children: [
                    // AI Setup Option
                    Expanded(
                      flex: 6,
                      child: GestureDetector(
                        onTap: () => _navigateToAISetup(context),
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppThemeV3.accent,
                                AppThemeV3.accent.withValues(alpha: 0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppThemeV3.accent.withValues(alpha: 0.3),
                                offset: const Offset(0, 8),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'AI-Powered Setup',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      '5 min',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              const Text(
                                'Let our AI create a personalized meal plan based on your preferences, goals, and lifestyle.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  height: 1.4,
                                ),
                              ),
                              
                              const Spacer(),
                              
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Personalized recommendations',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Smart meal scheduling',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Manual Setup Option
                    Expanded(
                      flex: 4,
                      child: GestureDetector(
                        onTap: () => _navigateToManualSetup(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppThemeV3.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppThemeV3.border,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppThemeV3.textSecondary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.tune,
                                      color: AppThemeV3.textSecondary,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Manual Setup',
                                      style: AppThemeV3.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: AppThemeV3.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppThemeV3.textSecondary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '10+ min',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppThemeV3.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              Text(
                                'Choose your own meal plan, set up delivery schedules, and manually select your meals.',
                                style: AppThemeV3.textTheme.bodyMedium?.copyWith(
                                  color: AppThemeV3.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              
                              const Spacer(),
                              
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: AppThemeV3.textSecondary.withValues(alpha: 0.6),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Full control over selections',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: AppThemeV3.textSecondary.withValues(alpha: 0.6),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Traditional setup process',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAISetup(BuildContext context) {
    // For now, just redirect to manual setup
    // AI setup is coming soon
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('AI Setup coming soon! Redirecting to manual setup...'),
        duration: Duration(seconds: 2),
      ),
    );
    
    // Navigate to manual setup after a brief delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (context.mounted) {
        _navigateToManualSetup(context);
      }
    });
  }

  void _navigateToManualSetup(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChooseMealPlanPageV3(),
      ),
    );
  }
}
