import 'package:shared_preferences/shared_preferences.dart';
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
  static const String _scheduleDataKey = 'schedule_data';
  static const String _paymentDataKey = 'payment_data';
  static const String _currentStepKey = 'current_step';

  // Save current onboarding step
  static Future<void> saveCurrentStep(OnboardingStep step) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentStepKey, step.name);
      await prefs.setInt('step_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error saving current step: $e');
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
      print('Error getting current step: $e');
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
      print('Error saving signup progress: $e');
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
      print('Error getting signup progress: $e');
      return null;
    }
  }

  // Save delivery schedule progress
  static Future<void> saveScheduleProgress({
    String? selectedMealPlanId,
    String? selectedMealPlanName,
    String? scheduleName,
    List<String>? selectedMealTypes,
    Map<String, dynamic>? weeklySchedule,
    int? configuredDaysCount,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scheduleData = {
        'selectedMealPlanId': selectedMealPlanId,
        'selectedMealPlanName': selectedMealPlanName,
        'scheduleName': scheduleName,
        'selectedMealTypes': selectedMealTypes,
        'weeklySchedule': weeklySchedule,
        'configuredDaysCount': configuredDaysCount ?? 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      await prefs.setString(_scheduleDataKey, json.encode(scheduleData));
    } catch (e) {
      print('Error saving schedule progress: $e');
    }
  }

  // Get saved schedule data
  static Future<Map<String, dynamic>?> getScheduleProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataString = prefs.getString(_scheduleDataKey);
      if (dataString == null) return null;
      
      return json.decode(dataString) as Map<String, dynamic>;
    } catch (e) {
      print('Error getting schedule progress: $e');
      return null;
    }
  }

  // Clear all onboarding progress (when completed successfully)
  static Future<void> clearOnboardingProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentStepKey);
      await prefs.remove(_signupDataKey);
      await prefs.remove(_scheduleDataKey);
      await prefs.remove(_paymentDataKey);
      await prefs.remove('step_timestamp');
    } catch (e) {
      print('Error clearing onboarding progress: $e');
    }
  }

  // Check if onboarding was interrupted (more than 30 minutes ago)
  static Future<bool> wasOnboardingInterrupted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('step_timestamp');
      if (timestamp == null) return false;
      
      final now = DateTime.now().millisecondsSinceEpoch;
      final thirtyMinutesAgo = now - (30 * 60 * 1000); // 30 minutes in milliseconds
      
      return timestamp < thirtyMinutesAgo;
    } catch (e) {
      print('Error checking if onboarding was interrupted: $e');
      return false;
    }
  }

  // Get onboarding resume data
  static Future<Map<String, dynamic>> getResumeData() async {
    final currentStep = await getCurrentStep();
    final signupData = await getSignupProgress();
    final scheduleData = await getScheduleProgress();
    
    return {
      'currentStep': currentStep,
      'signupData': signupData,
      'scheduleData': scheduleData,
    };
  }

  // Calculate completion percentage
  static Future<double> getCompletionPercentage() async {
    try {
      final currentStep = await getCurrentStep();
      if (currentStep == null) return 0.0;
      
      final stepIndex = OnboardingStep.values.indexOf(currentStep);
      final totalSteps = OnboardingStep.values.length - 1; // Exclude 'completed'
      
      return stepIndex / totalSteps;
    } catch (e) {
      print('Error calculating completion percentage: $e');
      return 0.0;
    }
  }
}
