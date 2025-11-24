import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
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
import 'app_v3/services/auth/doordash_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:freshpunk/services/billing_service.dart';

// Background message handler (must be top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

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
    await FCMServiceV3.instance.initAndRegisterToken();

    // Initialize Stripe publishable key (mobile/desktop only)
    if (!kIsWeb) {
      await BillingService.initialize();
    }

    // Test DoorDash API connection only if credentials are configured
    if (EnvironmentService.isDoorDashConfigured) {
      debugPrint('[App] Testing DoorDash credentials...');
      final doorDashConnected = await DoorDashService.instance.testConnection();
      debugPrint('[App] DoorDash connection result: ${doorDashConnected ? '✅ CONNECTED' : '❌ FAILED'}');
      // Optional: run a one-off delivery creation test in debug builds
      if (kDebugMode) {
        await testDoorDashDeliveryCreation();
      }
    } else {
      debugPrint('[App] Skipping DoorDash tests: credentials not configured (set DOORDASH_* via --dart-define or .env)');
    }

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
      title: 'FreshPunk',
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
        
        // Block legacy routes
        if (name.contains('V1') || name.contains('_v1')) {
          debugPrint('[RouteBlock] Attempted navigation to legacy route: $name');
          return MaterialPageRoute(builder: (_) => const SplashPageV3());
        }
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
