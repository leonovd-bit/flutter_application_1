import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../pages/home_page_v3.dart';
import '../../pages/auth/welcome_page_v3.dart';
import '../../pages/auth/splash_page_v3.dart';
import 'firestore_service_v3.dart';
import '../../debug/debug_state.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInitialized = false;
  DateTime? _bootStartedAt;
  static const Duration _minSplashDuration = Duration(milliseconds: 800);

  @override
  void initState() {
    super.initState();
    _bootStartedAt = DateTime.now();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        DebugState.updateUser(user.uid);
        
        // Ensure a user profile document exists
        try {
          await FirestoreServiceV3.updateUserProfile(user.uid, {
            'id': user.uid,
            'email': user.email ?? '',
            if (user.displayName != null && user.displayName!.trim().isNotEmpty)
              'fullName': user.displayName,
          });
        } catch (_) {}
      } else {
        DebugState.updateUser(null);
      }
      
      // Ensure splash shows for minimum duration
      final elapsed = _bootStartedAt == null ? Duration.zero : DateTime.now().difference(_bootStartedAt!);
      final wait = elapsed >= _minSplashDuration ? Duration.zero : (_minSplashDuration - elapsed);
      await Future.delayed(wait);
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing auth: $e');
      // Even on error, keep splash visible for minimum duration
      final elapsed = _bootStartedAt == null ? Duration.zero : DateTime.now().difference(_bootStartedAt!);
      final wait = elapsed >= _minSplashDuration ? Duration.zero : (_minSplashDuration - elapsed);
      await Future.delayed(wait);
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const SplashPageV3();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashPageV3();
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          debugPrint('User authenticated: ${snapshot.data!.uid}');
          return const HomePageV3();
        } else {
          debugPrint('No authenticated user, showing welcome page');
          return const WelcomePageV3();
        }
      },
    );
  }
}

// Inherited widget to provide approval callback deeper in the tree without tight coupling.
class _ExplicitSetupScope extends InheritedWidget {
  final VoidCallback onApprove;
  const _ExplicitSetupScope({required this.onApprove, required super.child});

  static _ExplicitSetupScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_ExplicitSetupScope>();

  @override
  bool updateShouldNotify(covariant _ExplicitSetupScope oldWidget) => false;
}

/// Public helper for pages to mark explicit user setup consent.
class ExplicitSetupApproval {
  static void approve(BuildContext context) {
    _ExplicitSetupScope.of(context)?.onApprove();
  }
}

// Helper function to force sign out
class AuthHelper {
  static Future<void> forceSignOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      debugPrint('Force sign out completed');
      DebugState.updateUser(null);
    } catch (e) {
      debugPrint('Error during force sign out: $e');
    }
  }
}