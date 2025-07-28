import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app_v2/pages/splash_page_v2.dart';
import 'app_v2/theme/app_theme_v2.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const FreshPunkAppV2());
}

class FreshPunkAppV2 extends StatelessWidget {
  const FreshPunkAppV2({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FreshPunk V2',
      theme: AppThemeV2.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashPageV2(),
        '/login': (context) => const LoginPageV2(),
        '/welcome': (context) => const WelcomePageV2(),
        '/signup': (context) => const SignupPageV2(),
        '/delivery-schedule': (context) => const DeliverySchedulePageV2(),
        '/meal-schedule': (context) => const MealSchedulePageV2(),
        '/subscription': (context) => const SubscriptionPaymentPageV2(),
        '/home': (context) => const HomePageV2(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
