import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/home_page_v3.dart';
import '../pages/login_page_v3.dart';
import '../pages/delivery_schedule_page_v4.dart';
import '../pages/meal_schedule_page_v3_fixed.dart';
import 'progress_manager.dart';

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
        // User is signed in and verified, check if they completed setup
        final prefs = await SharedPreferences.getInstance();
        final setupCompleted = prefs.getBool('setup_completed') ?? false;
        final savedSchedules = prefs.getStringList('saved_schedules') ?? const [];
        _hasSavedSchedules = savedSchedules.isNotEmpty;
  _setupCompletedLocal = setupCompleted;
        
        if (!setupCompleted) {
          // If user has an existing schedule, keep it and allow them to continue without wiping data.
          if (_hasSavedSchedules) {
            print('User has incomplete setup but existing schedules found; preserving progress and skipping clear.');
          } else {
            // No schedules to resume; safe to clear onboarding-only progress
            print('User has incomplete setup and no existing schedules; clearing onboarding progress.');
            await ProgressManager.clearOnboardingProgress();
          }
        } else {
          print('User has completed setup, staying signed in');
        }
      }
      else {
        // Even if not currently authenticated, honor completed setup for offline/home resume
        final prefs = await SharedPreferences.getInstance();
        _setupCompletedLocal = prefs.getBool('setup_completed') ?? false;
      }
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Error initializing auth: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<bool> _checkSetupCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('setup_completed') ?? false;
    } catch (e) {
      print('Error checking setup completion: $e');
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
          print('User authenticated: ${snapshot.data!.uid}');
          
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
                  print('Setup incomplete but schedules exist; directing to meal schedule.');
                  return const MealSchedulePageV3();
                }
                print('Setup incomplete, directing to delivery schedule page');
                return const DeliverySchedulePageV4();
              }
            },
          );
        } else {
          // If onboarding was completed previously, resume directly to Home (offline-friendly)
          if (_setupCompletedLocal) {
            print('No authenticated user but setup completed; resuming to Home');
            return const HomePageV3();
          }
          print('No authenticated user, showing login page');
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
      print('Force sign out completed');
    } catch (e) {
      print('Error during force sign out: $e');
    }
  }
}
