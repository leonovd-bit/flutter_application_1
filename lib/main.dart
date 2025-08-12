import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'app_v3/pages/splash_page_v3.dart';
import 'app_v3/theme/app_theme_v3.dart';
import 'app_v3/services/memory_optimizer.dart';
import 'app_v3/debug/build_badge.dart';
import 'app_v3/config/feature_flags.dart';
import 'app_v3/debug/debug_overlay.dart';
import 'app_v3/debug/debug_state.dart';

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

    // MemoryOptimizer.optimizeImageCache(); // Disabled for web compatibility

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
      title: 'FreshPunk',
      theme: AppThemeV3.lightTheme,
      home: const SplashPageV3(),
      debugShowCheckedModeBanner: false,
      navigatorObservers: [
        _routeObserver,
        _RouteLogger(),
      ],
      builder: (context, child) {
        final wrapped = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child!,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            wrapped, // main app content
            const BuildBadge(label: 'REFINED • OneDrive'),
          ],
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
