import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

enum OnboardingStep {
  welcome,
  signup,
  emailVerification,
  deliverySchedule,
  paymentSetup,
  completed
}

class ProgressManager {
  static const String _signupDataKey = 'signup_data';
  static const String _currentStepKey = 'current_step';

  // Save current onboarding step
  static Future<void> saveCurrentStep(OnboardingStep step) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentStepKey, step.name);
      await prefs.setInt('step_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error saving current step: $e');
    }
  }

  // Get current onboarding step
  static Future<OnboardingStep?> getCurrentStep() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stepName = prefs.getString(_currentStepKey);
      if (stepName == null) return null;
      
      return OnboardingStep.values.firstWhere(
        (e) => e.name == stepName,
        orElse: () => OnboardingStep.welcome,
      );
    } catch (e) {
      debugPrint('Error getting current step: $e');
      return null;
    }
  }

  // Save signup progress
  static Future<void> saveSignupProgress({
    String? email,
    String? phone,
    String? name,
    bool? isEmailVerified,
    String? authMethod, // 'email', 'google', 'apple'
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final signupData = {
        'email': email,
        'phone': phone,
        'name': name,
        'isEmailVerified': isEmailVerified ?? false,
        'authMethod': authMethod,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await prefs.setString(_signupDataKey, json.encode(signupData));
    } catch (e) {
      debugPrint('Error saving signup progress: $e');
    }
  }

  // Get saved signup data
  static Future<Map<String, dynamic>?> getSignupProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataString = prefs.getString(_signupDataKey);
      if (dataString == null) return null;
      
      return json.decode(dataString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error getting signup progress: $e');
      return null;
    }
  }

  // Clear all onboarding progress (when completed successfully)
  static Future<void> clearOnboardingProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentStepKey);
      await prefs.remove(_signupDataKey);
      await prefs.remove('step_timestamp');
    } catch (e) {
      debugPrint('Error clearing onboarding progress: $e');
    }
  }
}