import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/home_page_v3.dart';
import '../pages/login_page_v3.dart';
import '../pages/delivery_schedule_page_v4.dart';
import '../pages/meal_schedule_page_v3_fixed.dart';
import 'progress_manager.dart';
import 'firestore_service_v3.dart';
import 'data_migration_v3.dart';
import 'scheduler_service_v3.dart';
import 'notification_service_v3.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInitialized = false;
  bool _hasSavedSchedules = false;
  bool _setupCompletedLocal = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null && user.emailVerified) {
        // Ensure a user profile document exists (idempotent upsert)
        try {
          await FirestoreServiceV3.updateUserProfile(user.uid, {
            'id': user.uid,
            'email': user.email ?? '',
            if (user.displayName != null && user.displayName!.trim().isNotEmpty)
              'fullName': user.displayName,
          });
        } catch (_) {}
  // User is signed in and verified, check if they completed setup
        final prefs = await SharedPreferences.getInstance();

        // Proactively cache the user's current plan locally for UI fallbacks
        try {
          // 1) Try denormalized fields from user profile
          final profile = await FirestoreServiceV3.getUserProfile(user.uid);
          final profilePlanName = (profile?['currentPlanName'] ?? '').toString().trim();
          final profilePlanId = (profile?['currentMealPlanId'] ?? '').toString().trim();
          if (profilePlanName.isNotEmpty) {
            await prefs.setString('selected_meal_plan_display_name', profilePlanName);
          }
          if (profilePlanId.isNotEmpty) {
            await prefs.setString('selected_meal_plan_id', profilePlanId);
          }

          // 2) If still missing a display name, resolve via service helper
          if ((prefs.getString('selected_meal_plan_display_name') ?? '').trim().isEmpty) {
            final resolved = await FirestoreServiceV3.getDisplayPlanName(user.uid);
            if (resolved != null && resolved.trim().isNotEmpty) {
              await prefs.setString('selected_meal_plan_display_name', resolved.trim());
            }
          }
        } catch (_) {
          // Best-effort only; UI has additional fallbacks
        }
        
        // Initialize notifications (no-op stub) and seed/generate essential data
        try {
          await NotificationServiceV3.instance.init();
        } catch (_) {}

        try {
          // Seed canonical plans if user's collection is empty, then generate upcoming orders
          await DataMigrationV3.seedMealPlansIfMissing(user.uid);
          await SchedulerServiceV3.generateUpcomingOrders(userId: user.uid, daysAhead: 7);
        } catch (_) {}
        final setupCompleted = prefs.getBool('setup_completed') ?? false;
        final savedSchedules = prefs.getStringList('saved_schedules') ?? const [];
        _hasSavedSchedules = savedSchedules.isNotEmpty;
  _setupCompletedLocal = setupCompleted;
        
        if (!setupCompleted) {
          // If user has an existing schedule, keep it and allow them to continue without wiping data.
          if (_hasSavedSchedules) {
            debugPrint('User has incomplete setup but existing schedules found; preserving progress and skipping clear.');
          } else {
            // No schedules to resume; safe to clear onboarding-only progress
            debugPrint('User has incomplete setup and no existing schedules; clearing onboarding progress.');
            await ProgressManager.clearOnboardingProgress();
          }
        } else {
          debugPrint('User has completed setup, staying signed in');
        }
      }
      else {
        // Even if not currently authenticated, honor completed setup for offline/home resume
        final prefs = await SharedPreferences.getInstance();
        _setupCompletedLocal = prefs.getBool('setup_completed') ?? false;
      }
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing auth: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
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

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasData && snapshot.data != null) {
          debugPrint('User authenticated: ${snapshot.data!.uid}');
          
          // Check if setup is completed
          return FutureBuilder<bool>(
            future: _checkSetupCompleted(),
            builder: (context, setupSnapshot) {
              if (setupSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              final setupCompleted = setupSnapshot.data ?? false;
              
              if (setupCompleted) {
                return const HomePageV3();
              } else {
                // If there's any saved schedule, jump straight to meal scheduling to continue.
                if (_hasSavedSchedules) {
                  debugPrint('Setup incomplete but schedules exist; directing to meal schedule.');
                  return const MealSchedulePageV3();
                }
                debugPrint('Setup incomplete, directing to delivery schedule page');
                return const DeliverySchedulePageV4();
              }
            },
          );
        } else {
          // If onboarding was completed previously, resume directly to Home (offline-friendly)
          if (_setupCompletedLocal) {
            debugPrint('No authenticated user but setup completed; resuming to Home');
            return const HomePageV3();
          }
          debugPrint('No authenticated user, showing login page');
          return const LoginPageV3();
        }
      },
    );
  }
}

// Helper function to force sign out from anywhere in the app
class AuthHelper {
  static Future<void> forceSignOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('force_sign_out', true);
      await FirebaseAuth.instance.signOut();
      await prefs.clear();
  debugPrint('Force sign out completed');
    } catch (e) {
  debugPrint('Error during force sign out: $e');
    }
  }
}
