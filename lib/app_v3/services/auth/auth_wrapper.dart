import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../pages/home_page_v3.dart';
import '../../pages/auth/welcome_page_v3.dart';
import '../../pages/auth/splash_page_v3.dart';
import '../../pages/auth/phone_verification_page_v3.dart';
import '../../pages/auth/phone_collection_page_v3.dart';
import '../../pages/onboarding/choose_meal_plan_page_v3.dart';
import 'firestore_service_v3.dart';
import 'progress_manager.dart';
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
          
          // Check onboarding progress to determine where to send user
          return FutureBuilder<Widget>(
            future: _determineNextPage(),
            builder: (context, pageSnapshot) {
              if (pageSnapshot.connectionState == ConnectionState.waiting) {
                return const SplashPageV3();
              }
              
              return pageSnapshot.data ?? const WelcomePageV3();
            },
          );
        } else {
          debugPrint('No authenticated user, showing welcome page');
          return const WelcomePageV3();
        }
      },
    );
  }
  
  /// Determine which page to show based on onboarding progress
  Future<Widget> _determineNextPage() async {
    try {
      // Check if setup is fully completed
      final prefs = await SharedPreferences.getInstance();
      final setupCompleted = prefs.getBool('setup_completed') ?? false;
      
      if (setupCompleted) {
        debugPrint('[AuthWrapper] Setup completed - showing home page');
        return const HomePageV3();
      }
      
      // Check onboarding progress
      final currentStep = await ProgressManager.getCurrentStep();
      debugPrint('[AuthWrapper] Current onboarding step: $currentStep');
      
      if (currentStep == null) {
        // No saved progress - start fresh with meal plan
        debugPrint('[AuthWrapper] No saved progress - starting with meal plan');
        return const ChooseMealPlanPageV3(isSignupFlow: true);
      }
      
      // Resume from where user left off
      switch (currentStep) {
        case OnboardingStep.welcome:
        case OnboardingStep.signup:
          return const WelcomePageV3();
          
        case OnboardingStep.emailVerification:
        case OnboardingStep.phoneVerification:
          // Get saved phone number from progress
          final signupData = await ProgressManager.getSignupProgress();
          final phoneNumber = signupData?['phone'] as String?;
          
          if (phoneNumber != null && phoneNumber.isNotEmpty) {
            debugPrint('[AuthWrapper] Resuming phone verification with saved phone');
            return PhoneVerificationPageV3(phoneNumber: phoneNumber);
          } else {
            // No phone saved - collect it first (for social sign-in users)
            debugPrint('[AuthWrapper] No phone saved - collecting phone number');
            return const PhoneCollectionPageV3();
          }
          
        case OnboardingStep.deliverySchedule:
        case OnboardingStep.paymentSetup:
          // For delivery schedule and payment, we need data from previous steps
          // If that data is missing, restart from meal plan
          debugPrint('[AuthWrapper] Partial progress - restarting from meal plan');
          return const ChooseMealPlanPageV3(isSignupFlow: true);
          
        case OnboardingStep.completed:
          debugPrint('[AuthWrapper] Onboarding marked complete - showing home');
          // Mark setup as completed in SharedPreferences
          await prefs.setBool('setup_completed', true);
          await ProgressManager.clearOnboardingProgress();
          return const HomePageV3();
      }
    } catch (e) {
      debugPrint('[AuthWrapper] Error determining next page: $e');
      // On error, default to meal plan page (safest option for authenticated users)
      return const ChooseMealPlanPageV3(isSignupFlow: true);
    }
  }
  
  Future<bool> _checkSetupCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('setup_completed') ?? false;
    } catch (e) {
      debugPrint('Error checking setup completion: $e');
      return false;
    }
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