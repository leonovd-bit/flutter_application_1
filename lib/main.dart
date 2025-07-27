import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/splash_page.dart';
import 'services/stripe_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Only initialize Stripe on mobile platforms
  if (!kIsWeb) {
    await StripeService.init();
  }
  
  await NotificationService.initialize();
  runApp(const FreshPunkApp());
}

class FreshPunkApp extends StatelessWidget {
  const FreshPunkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FreshPunk',
      theme: AppTheme.darkTheme,
      home: const SplashPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
