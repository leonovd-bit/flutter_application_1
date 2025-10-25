import 'package:flutter/material.dart';
import '../pages/ai_onboarding_page_v3.dart';
import '../pages/choose_meal_plan_page_v3.dart';
import '../pages/delivery_schedule_page_v5.dart';
import '../pages/email_verification_page_v3.dart';
import '../pages/home_page_v3.dart';
import '../pages/login_page_v3.dart';
import '../pages/meal_schedule_page_v3_fixed.dart';
import '../pages/onboarding_choice_page_v3.dart';
import '../pages/payment_page_v3.dart';
import '../pages/payment_methods_page_v3.dart';
import '../pages/profile_page_v3.dart';
import '../pages/settings_page_v3.dart';
import '../pages/manage_subscription_page_v3.dart';
import '../pages/splash_page_v3.dart';
import '../pages/welcome_page_v3.dart';
import '../models/meal_model_v3.dart';
import '../theme/app_theme_v3.dart';
import '../models/mock_user_model.dart';

class PageViewerV3 extends StatefulWidget {
  const PageViewerV3({super.key});

  @override
  State<PageViewerV3> createState() => _PageViewerV3State();
}
class _PageViewerV3State extends State<PageViewerV3> {
  // Design mode: use top-level mockUser to provide a fake account
  final List<PageInfo> _pages = [
    // Auth & Onboarding Flow
    PageInfo('Splash', () => const SplashPageV3()),
    PageInfo('Welcome', () => const WelcomePageV3()),
    PageInfo('Login', () => const LoginPageV3()),
    PageInfo('Email Verification', () => const EmailVerificationPageV3(email: 'demo@example.com')),
    PageInfo('Onboarding Choice', () => const OnboardingChoicePageV3()),
    
    // AI Onboarding Path
    PageInfo('AI Onboarding', () => const AIOnboardingPageV3()),
  PageInfo('Payment Methods', () => PaymentMethodsPageV3(onPaymentComplete: () {}, isOnboarding: true, mockUser: mockUser)),
    
    // Manual Onboarding Path
    PageInfo('Choose Meal Plan', () => const ChooseMealPlanPageV3()),
  PageInfo('Delivery Schedule', () => DeliverySchedulePageV5(mockUser: mockUser)),
    PageInfo('Meal Schedule', () => MealSchedulePageV3(
      mealPlan: MealPlanModelV3(
        id: '2',
        name: 'DietKnight',
        displayName: 'DietKnight',
        description: '2 meals per day',
        mealsPerDay: 2,
        pricePerWeek: 182.0,
        pricePerMeal: 13.0,
      ),
      weeklySchedule: {
        'Monday': {'breakfast': true, 'lunch': true},
        'Tuesday': {'breakfast': true, 'lunch': true},
      },
    )),
  PageInfo('Payment', () => PaymentPageV3(
      mealPlan: MealPlanModelV3(
        id: '2',
        name: 'DietKnight',
        displayName: 'DietKnight',
        description: '2 meals per day',
        mealsPerDay: 2,
        pricePerWeek: 182.0,
        pricePerMeal: 13.0,
      ),
      weeklySchedule: {},
      selectedMeals: {},
      mockUser: mockUser,
    )),
    
    // Main App Pages
    PageInfo('Home', () => const HomePageV3()),
  PageInfo('Profile', () => ProfilePageV3(mockUser: mockUser)),
  PageInfo('Settings', () => const SettingsPageV3()),
    PageInfo('Manage Subscription', () => const ManageSubscriptionPageV3()),
  ];

  Widget? _selectedPage;
  String _selectedPageName = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV3.background,
      appBar: AppBar(
        title: Text(_selectedPageName.isEmpty ? 'Page Viewer V3' : _selectedPageName),
        backgroundColor: AppThemeV3.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedPage != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _selectedPage = null;
                _selectedPageName = '';
              }),
            ),
        ],
      ),
      body: _selectedPage ?? _buildPageList(),
    );
  }

  Widget _buildPageList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _pages.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final page = _pages[index];
        return Card(
          child: ListTile(
            title: Text(
              page.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              setState(() {
                _selectedPage = page.builder();
                _selectedPageName = page.name;
              });
            },
          ),
        );
      },
    );
  }
}

class PageInfo {
  final String name;
  final Widget Function() builder;

  PageInfo(this.name, this.builder);
}