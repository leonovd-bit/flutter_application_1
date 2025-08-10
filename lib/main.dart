import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app_v3/services/auth_wrapper.dart';
import 'app_v3/theme/app_theme_v3.dart';
import 'app_v3/services/memory_optimizer.dart';

void main() {
  runZonedGuarded(() async {
    // Important: initialize bindings in the same zone as runApp
    WidgetsFlutterBinding.ensureInitialized();

    // Error handlers for visibility during startup
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      // ignore: avoid_print
      print('Top-level framework error: $error\n$stack');
      return true;
    };

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // MemoryOptimizer.optimizeImageCache(); // disabled while diagnosing

    runApp(const MyApp());
  }, (error, stack) {
    // ignore: avoid_print
    print('Uncaught error during app startup: $error\n$stack');
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Clear caches when app goes to background to save memory
    if (state == AppLifecycleState.paused) {
      MemoryOptimizer.clearImageCache();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: AppThemeV3.lightTheme,
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
      // Optimize app performance
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(1.0), // Prevent font scaling issues
          ),
          child: child!,
        );
      },
    );
  }
}
