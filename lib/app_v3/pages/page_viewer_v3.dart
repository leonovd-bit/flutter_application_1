import 'package:flutter/mater    PageInfo('Home', () => const HomePageV3()),
    PageInfo('Choose Meal Plan', () => const ChooseMealPlanPageV3()),
    PageInfo('Delivery Schedule', () => const DeliverySchedulePageV5()),
    PageInfo('Address', () => const AddressPageV3());dart';
import '../pages/about_page_v3.dart';
import '../pages/address_page_v3.dart';
import '../pages/choose_meal_plan_page_v3.dart';
import '../pages/circle_of_health_page_v3.dart';
import '../pages/delivery_schedule_page_v5.dart';
import '../pages/email_verification_page_v3.dart';
import '../pages/home_page_v3.dart';
import '../pages/login_page_v3.dart';
import '../pages/privacy_policy_page_v3.dart';
import '../pages/settings_page_v3.dart';
import '../pages/splash_page_v3.dart';
import '../pages/terms_of_service_page_v3.dart';
import '../pages/welcome_page_v3.dart';
import '../theme/app_theme_v3.dart';

class PageViewerV3 extends StatefulWidget {
  const PageViewerV3({super.key});

  @override
  State<PageViewerV3> createState() => _PageViewerV3State();
}

class _PageViewerV3State extends State<PageViewerV3> {
  final List<PageInfo> _pages = [
    PageInfo('Splash', () => const SplashPageV3()),
    PageInfo('Welcome', () => const WelcomePageV3()),
    PageInfo('Login', () => const LoginPageV3()),
    PageInfo('Email Verification', () => const EmailVerificationPageV3(email: 'demo@example.com')),
    PageInfo('Home', () => const HomePageV3()),
    PageInfo('Choose Meal Plan', () => const ChooseMealPlanPageV3()),
    PageInfo('Delivery Schedule', () => const DeliverySchedulePageV4()),
    PageInfo('Address', () => const AddressPageV3()),
    PageInfo('Settings', () => const SettingsPageV3()),
    PageInfo('About', () => const AboutPageV3()),
    PageInfo('Privacy Policy', () => const PrivacyPolicyPageV3()),
    PageInfo('Terms of Service', () => const TermsOfServicePageV3()),
    PageInfo('Circle of Health', () => const CircleOfHealthPageV3()),
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