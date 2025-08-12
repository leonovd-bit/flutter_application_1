import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pages/home_page_v3.dart';
import '../pages/login_page_v3.dart';
import '../pages/splash_page_v3.dart';
import '../pages/delivery_schedule_page_v4.dart';
import '../pages/meal_schedule_page_v3_fixed.dart';
import 'progress_manager.dart';
import 'firestore_service_v3.dart';
import 'data_migration_v3.dart';
import 'scheduler_service_v3.dart';
import 'notification_service_v3.dart';
import 'meal_service_v3.dart';
import '../../app_v3/debug/debug_state.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInitialized = false;
  bool _hasSavedSchedules = false;
  bool _explicitUserSetupApproved = false; // set true only after user action in login/signup UI
  DateTime? _bootStartedAt;
  static const Duration _minSplashDuration = Duration(milliseconds: 1200);

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
          // Only proceed with seeding + generation if explicit user setup approved.
          // This prevents unintended automatic account bootstrap if a stray auth user appears.
          if (_explicitUserSetupApproved) {
            await DataMigrationV3.seedMealPlansIfMissing(user.uid);
            final generated = await SchedulerServiceV3.generateUpcomingOrders(userId: user.uid, daysAhead: 7);
            debugPrint('[AuthBootstrap] scheduler generated=$generated');
          } else {
            debugPrint('[AuthBootstrap] Skipping seeding/scheduler until explicit setup approval.');
          }

          // Backfill notifications for any existing future orders without reminders yet
          try {
            if (_explicitUserSetupApproved) {
              final upcoming = await FirestoreServiceV3.getUpcomingOrders(user.uid);
              for (final o in upcoming) {
              final ts = o['deliveryDate'];
              DateTime dt;
              if (ts is Timestamp) {
                dt = ts.toDate();
              } else if (ts is int) {
                dt = DateTime.fromMillisecondsSinceEpoch(ts);
              } else if (ts is DateTime) {
                dt = ts;
              } else {
                continue;
              }
              final notifId = dt.millisecondsSinceEpoch ~/ 60000;
              final orderId = (o['id'] ?? '').toString();
              final mealType = (o['meals'] is List && (o['meals'] as List).isNotEmpty)
                  ? (((o['meals'] as List).first as Map)['mealType'] ?? 'meal').toString()
                  : (o['mealType'] ?? 'meal').toString();
              final addressLabel = (o['deliveryAddress'] ?? 'your address').toString();
              await NotificationServiceV3.instance.scheduleIfNotExists(
                id: notifId,
                deliveryTime: dt,
                title: 'FreshPunk delivery',
                body: 'Your $mealType arrives in 1 hour at $addressLabel.',
                payload: orderId,
              );
              }
              debugPrint('[AuthBootstrap] notification backfill scheduled (explicit)');
            } else {
              debugPrint('[AuthBootstrap] Skipping notification backfill (no explicit approval).');
            }
          } catch (e) {
            debugPrint('[AuthBootstrap] notification backfill error: $e');
          }
          // Ensure meals are seeded (idempotent upsert). Safe to run anytime.
          try {
            if (_explicitUserSetupApproved) {
              final seeded = await MealServiceV3.seedFromJsonAsset();
              debugPrint('[AuthBootstrap] meals seeded (attempted): $seeded');
            } else {
              debugPrint('[AuthBootstrap] Skipping meal seed until explicit approval.');
            }
          } catch (e) {
            debugPrint('[AuthBootstrap] meals seed error: $e');
          }
          // Ensure token plan exists (idempotent)
          try {
            if (_explicitUserSetupApproved) {
              await MealServiceV3.seedTokenPlanIfNeeded();
              debugPrint('[AuthBootstrap] token plan ensured');
            } else {
              debugPrint('[AuthBootstrap] Skipping token plan seed until explicit approval.');
            }
          } catch (e) {
            debugPrint('[AuthBootstrap] token plan seed error: $e');
          }
        } catch (_) {}
  final setupCompleted = prefs.getBool('setup_completed') ?? false;
        final savedSchedules = prefs.getStringList('saved_schedules') ?? const [];
        _hasSavedSchedules = savedSchedules.isNotEmpty;
        
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
        // Not authenticated; nothing else to do here
  DebugState.updateUser(null);
      }
      
  // Ensure splash shows at least for UX consistency
  final elapsed = _bootStartedAt == null ? Duration.zero : DateTime.now().difference(_bootStartedAt!);
  final wait = elapsed >= _minSplashDuration ? Duration.zero : (_minSplashDuration - elapsed);
      await Future.delayed(wait);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
  DebugState.update(explicitApproved: _explicitUserSetupApproved);
      }
    } catch (e) {
      debugPrint('Error initializing auth: $e');
  // Even on error, keep splash visible for the minimum duration
  final elapsed = _bootStartedAt == null ? Duration.zero : DateTime.now().difference(_bootStartedAt!);
  final wait = elapsed >= _minSplashDuration ? Duration.zero : (_minSplashDuration - elapsed);
      await Future.delayed(wait);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
  DebugState.update(explicitApproved: _explicitUserSetupApproved);
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
      // Show a dedicated splash while bootstrapping
  return const SplashPageV3();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Keep showing splash while auth state resolves
          return const SplashPageV3();
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
                // Expose a tiny inherited bridge so signup/login pages can mark explicit approval
                return _ExplicitSetupScope(
                  onApprove: () {
                    if (!_explicitUserSetupApproved) {
                      setState(() => _explicitUserSetupApproved = true);
                      debugPrint('[AuthBootstrap] Explicit user setup approved via scope.');
                      // Re-run initialize to perform seeding now that flag is set
                      _initializeAuth();
                      DebugState.updateExplicit(true);
                    }
                  },
                  child: _hasSavedSchedules
                      ? const MealSchedulePageV3()
                      : const DeliverySchedulePageV4(),
                );
              }
            },
          );
        } else {
          // Never route unauthenticated users to Home. Show login/welcome instead.
          debugPrint('No authenticated user, showing login page');
          DebugState.update(explicitApproved: false);
          return const LoginPageV3();
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

// Helper function to force sign out from anywhere in the app
class AuthHelper {
  static Future<void> forceSignOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('force_sign_out', true);
      await FirebaseAuth.instance.signOut();
      await prefs.clear();
  debugPrint('Force sign out completed');
  DebugState.updateUser(null);
  DebugState.updateExplicit(false);
    } catch (e) {
  debugPrint('Error during force sign out: $e');
    }
  }
}
