import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app_v3/pages/splash_page_v3.dart';
import 'app_v3/theme/app_theme_v3.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const FreshPunkApp());
}

class FreshPunkApp extends StatelessWidget {
  const FreshPunkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FreshPunk',
      theme: AppThemeV3.lightTheme,
      home: const SplashPageV3(),
      debugShowCheckedModeBanner: false,
    );
  }
}
