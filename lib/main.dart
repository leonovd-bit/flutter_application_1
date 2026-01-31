import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'app_v3/pages/auth/splash_page_v3.dart';
import 'app_v3/pages/home_page_v3.dart';
import 'app_v3/pages/page_viewer_v3.dart';
import 'app_v3/pages/restaurant/restaurant_onboarding_page_v3.dart';
import 'app_v3/pages/restaurant/square_restaurant_onboarding_page_v3.dart';
import 'app_v3/pages/restaurant/combined_restaurant_portal_page.dart';
import 'app_v3/services/auth/auth_wrapper.dart';
import 'app_v3/theme/app_theme_v3.dart';
import 'app_v3/services/memory_optimizer.dart';
import 'app_v3/config/feature_flags.dart';
import 'app_v3/debug/debug_overlay.dart';
import 'app_v3/debug/debug_state.dart';
import 'app_v3/services/notifications/fcm_service_v3.dart';
import 'app_v3/services/environment_service.dart';
import 'app_v3/services/payment/stripe_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Background message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

void main() async {
  // Important: initialize bindings first
  WidgetsFlutterBinding.ensureInitialized();

  // Error handlers for visibility during startup
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  // Initialize Firebase - ignore if already initialized (happens on Android)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[Firebase] Initialized successfully');
  } catch (e) {
    // Firebase might already be initialized by google-services plugin on Android
    if (e.toString().contains('duplicate-app')) {
      debugPrint('[Firebase] Already initialized, continuing...');
    } else {
      debugPrint('[Firebase] Initialization error: $e');
    }
  }

  // Initialize Firebase App Check
  // Use debug provider for debug builds, PlayIntegrity for release
  try {
    final webSiteKey = const String.fromEnvironment('RECAPTCHA_V3_SITE_KEY');
    final shouldEnableWebAppCheck = !kIsWeb || webSiteKey.trim().isNotEmpty;

    if (!shouldEnableWebAppCheck) {
      debugPrint('[AppCheck] Skipping web App Check (no RECAPTCHA site key provided)');
    } else {
      await FirebaseAppCheck.instance.activate(
        androidProvider: kDebugMode
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.appAttest,
        webProvider: kIsWeb ? ReCaptchaV3Provider(webSiteKey) : null,
      );
      debugPrint('[AppCheck] Initialized successfully with ${kDebugMode ? "Debug" : "PlayIntegrity"} provider');
    }
    
    // Get and print debug token for registration in Firebase Console (debug builds only)
    if (kDebugMode && !kIsWeb) {
      // Wait a moment for debug token to be generated
      await Future.delayed(const Duration(seconds: 2));
      try {
        // Get debug token
        await FirebaseAppCheck.instance.getToken();
        debugPrint('[AppCheck] ⚠️ To get debug token, check logcat:');
        debugPrint('[AppCheck]   Run: adb logcat | grep -i "FirebaseAppCheck"');
        debugPrint('[AppCheck]   Or check Android Studio Logcat for "FirebaseAppCheck" tag');
        debugPrint('[AppCheck]   Then register it in Firebase Console > App Check > Manage debug tokens');
      } catch (e) {
        debugPrint('[AppCheck] Token error: $e');
      }
    }
  } catch (e) {
    debugPrint('[AppCheck] Initialization error: $e');
  }

  // Initialize environment variables from .env file
  await EnvironmentService.init();
  
  // Print API configuration status in debug mode
  if (kDebugMode) {
    EnvironmentService.printStatus();
  }

  // Set background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // MemoryOptimizer.optimizeImageCache(); // Disabled for web compatibility

  // Initialize Stripe (mobile/desktop only; skip on web)
  if (!kIsWeb) {
    try {
      await StripeService.instance.init();
      debugPrint('[Stripe] Initialized successfully');
    } catch (e) {
      debugPrint('[Stripe] Initialization failed: $e');
    }
  } else {
    debugPrint('[Stripe] Skipping init on web');
  }

  // Initialize enhanced FCM service (FREE push notifications)
  try {
    await FCMServiceV3.instance.initAndRegisterToken();
  } catch (e) {
    debugPrint('[FCM] Initialization failed: $e');
  }



  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _routeObserver = RouteObserver<PageRoute>();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Debug: Check initial route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentRoute = ModalRoute.of(context)?.settings.name;
      debugPrint('[InitialRoute] Current route: $currentRoute');
      debugPrint('[InitialRoute] Window location: ${Uri.base}');
    });
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
    // Check if we're starting with a specific route
    String initialRoute = '/';
    
    if (kIsWeb) {
      final currentUri = Uri.base;
      final fragment = currentUri.fragment;
      final path = currentUri.path;
      
      debugPrint('[AppStart] URI: $currentUri');
      debugPrint('[AppStart] Fragment: $fragment');
      debugPrint('[AppStart] Path: $path');
      
      // Check fragment first (Flutter web default routing)
      if (fragment.isNotEmpty) {
        if (fragment.startsWith('/kitchen-access') || fragment.startsWith('/kitchen-login')) {
          initialRoute = '/kitchen-access';
        } else if (fragment.startsWith('/kitchen-dashboard') || fragment.startsWith('/kitchen')) {
          initialRoute = '/kitchen-dashboard';
        } else if (fragment.startsWith('/restaurant-portal')) {
          initialRoute = '/restaurant-portal';
        } else if (fragment.startsWith('/restaurant-onboarding')) {
          initialRoute = '/restaurant-onboarding';
        } else if (fragment.startsWith('/restaurant-partner')) {
          initialRoute = '/restaurant-partner';
        }
      }
      // Also check path (Firebase hosting routing)
      else if (path.startsWith('/restaurant-portal')) {
        initialRoute = '/restaurant-portal';
      } else if (path.startsWith('/restaurant-onboarding')) {
        initialRoute = '/restaurant-onboarding';
      } else if (path.startsWith('/restaurant-partner')) {
        initialRoute = '/restaurant-partner';
      }
    }
    
    debugPrint('[AppStart] Initial route: $initialRoute');
    
    return MaterialApp(
      title: 'Victus',
      theme: AppThemeV3.lightTheme,
      debugShowCheckedModeBanner: false,
      // Restore normal app flow: use routes with an explicit initialRoute
      initialRoute: initialRoute,
      routes: {
        '/': (context) => const AuthWrapper(),
        '/home': (context) => const HomePageV3(),
        '/page-viewer': (context) => const PageViewerV3(),
        '/restaurant-onboarding': (context) => const RestaurantOnboardingPageV3(),
        '/restaurant-partner': (context) => const SquareRestaurantOnboardingPageV3(),
        '/restaurant-portal': (context) => const CombinedRestaurantPortalPage(),
        // Kitchen routes temporarily disabled
        // '/kitchen-access': (context) => const KitchenAccessPage(),
        // '/kitchen-login': (context) => const KitchenAccessPage(),
        // '/kitchen-dashboard': (context) => const KitchenDashboardPage(),
        // '/kitchen': (context) => const KitchenDashboardPage(),
      },
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        debugPrint('[Route] Generating route for: $name');
        
        return null; // fall back to normal
      },
      navigatorObservers: [
        _routeObserver,
        _RouteLogger(),
      ],
      builder: (context, child) {
        // Normalize text scaling across platforms
        final baseApp = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child!,
        );

        // On web, center and constrain to an iPhone 13 width (390px)
        return LayoutBuilder(
          builder: (context, constraints) {
            const phoneWidth = 390.0; // iPhone 13 logical width
            Widget content = baseApp;

            if (kIsWeb && constraints.maxWidth > phoneWidth) {
              content = Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: phoneWidth,
                  ),
                  child: content,
                ),
              );
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                content, // main app content (optionally constrained on web)
                if (FeatureFlags.showDebugOverlay) const DebugOverlay(),
              ],
            );
          },
        );
      },
    );
  }
}

class _RouteLogger extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    debugPrint('[Route] push -> ${route.settings.name ?? route.runtimeType}');
  DebugState.updateRoute(route.settings.name?.toString() ?? route.runtimeType.toString());
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    debugPrint('[Route] replace -> ${newRoute?.settings.name ?? newRoute?.runtimeType}');
    if (newRoute != null) {
      DebugState.updateRoute(newRoute.settings.name?.toString() ?? newRoute.runtimeType.toString());
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    debugPrint('[Route] pop <- ${route.settings.name ?? route.runtimeType}');
    if (previousRoute != null) {
      DebugState.updateRoute(previousRoute.settings.name?.toString() ?? previousRoute.runtimeType.toString());
    }
    super.didPop(route, previousRoute);
  }
}
