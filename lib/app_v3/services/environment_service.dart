import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

/// Environment Configuration Service
/// Loads and manages API keys from .env file
class EnvironmentService {
  static bool _initialized = false;

  /// Initialize environment variables from .env file
  static Future<void> init() async {
    if (_initialized) return;
    
    try {
      await dotenv.load(fileName: ".env");
      _initialized = true;
      
      if (kDebugMode) {
        debugPrint('[Environment] Configuration loaded successfully');
        debugPrint('[Environment] Mode: ${dotenv.env['ENVIRONMENT'] ?? 'development'}');
      }
    } catch (e) {
      debugPrint('[Environment] Failed to load .env file: $e');
      debugPrint('[Environment] Using default/hardcoded values');
    }
  }

  /// Get environment variable with optional fallback
  static String get(String key, [String? fallback]) {
    if (!_initialized) {
      debugPrint('[Environment] Warning: Not initialized, using fallback for $key');
      return fallback ?? '';
    }
    return dotenv.env[key] ?? fallback ?? '';
  }

  /// Check if running in debug mode
  static bool get isDebug {
    return get('DEBUG_MODE', 'false').toLowerCase() == 'true';
  }

  /// Check if running in production
  static bool get isProduction {
    return get('ENVIRONMENT', 'development').toLowerCase() == 'production';
  }

  // ===========================================
  // STRIPE PAYMENT API
  // ===========================================
  
  static String get stripePublishableKey => get('STRIPE_PUBLISHABLE_KEY');
  static String get stripePrice1Meal => get('STRIPE_PRICE_1_MEAL');
  static String get stripePrice2Meal => get('STRIPE_PRICE_2_MEAL');
  static String get stripePrice3Meal => get('STRIPE_PRICE_3_MEAL');

  // ===========================================
  // TWILIO SMS API
  // ===========================================
  
  static String get twilioAccountSid => get('TWILIO_ACCOUNT_SID');
  static String get twilioAuthToken => get('TWILIO_AUTH_TOKEN');
  static String get twilioPhoneNumber => get('TWILIO_PHONE_NUMBER');

  // ===========================================
  // GOOGLE MAPS API
  // ===========================================
  
  static String get googleMapsApiKey => get('GOOGLE_MAPS_API_KEY');
  static String get googleMapsAndroidKey => get('GOOGLE_MAPS_ANDROID_KEY');

  // ===========================================
  // DOORDASH DELIVERY API
  // ===========================================
  
  static String get doorDashDeveloperId => get('DOORDASH_DEVELOPER_ID');
  static String get doorDashKeyId => get('DOORDASH_KEY_ID');
  static String get doorDashSigningSecret => get('DOORDASH_SIGNING_SECRET');

  // ===========================================
  // FIREBASE CONFIG
  // ===========================================
  
  static String get firebaseProjectId => get('FIREBASE_PROJECT_ID');
  static String get firebaseApiKey => get('FIREBASE_API_KEY');
  static String get firebaseAppId => get('FIREBASE_APP_ID');

  // ===========================================
  // AI SERVICES (Optional)
  // ===========================================
  
  static String get openAiApiKey => get('OPENAI_API_KEY');

  // ===========================================
  // VALIDATION HELPERS
  // ===========================================

  /// Check if Stripe is properly configured
  static bool get isStripeConfigured {
    return stripePublishableKey.isNotEmpty && 
           stripePublishableKey.startsWith('pk_');
  }

  /// Check if Twilio SMS is properly configured
  static bool get isTwilioConfigured {
    return twilioAccountSid.isNotEmpty && 
           twilioAuthToken.isNotEmpty && 
           twilioPhoneNumber.isNotEmpty &&
           twilioAccountSid.startsWith('AC');
  }

  /// Check if Google Maps is properly configured
  static bool get isGoogleMapsConfigured {
    return googleMapsApiKey.isNotEmpty && 
           googleMapsApiKey.startsWith('AIzaSy');
  }

  /// Check if DoorDash is properly configured
  static bool get isDoorDashConfigured {
    return doorDashDeveloperId.isNotEmpty && 
           doorDashKeyId.isNotEmpty && 
           doorDashSigningSecret.isNotEmpty;
  }

  /// Check if OpenAI is configured
  static bool get isOpenAiConfigured {
    return openAiApiKey.isNotEmpty && 
           openAiApiKey.startsWith('sk-');
  }

  /// Get configuration summary for debugging
  static Map<String, bool> get configurationStatus {
    return {
      'stripe': isStripeConfigured,
      'twilio': isTwilioConfigured,
      'googleMaps': isGoogleMapsConfigured,
      'doorDash': isDoorDashConfigured,
      'openAi': isOpenAiConfigured,
      'environment': _initialized,
    };
  }

  /// Print configuration status (debug only)
  static void printStatus() {
    if (!kDebugMode) return;
    
    debugPrint('=== API Configuration Status ===');
    final status = configurationStatus;
    status.forEach((api, configured) {
      final icon = configured ? '✅' : '❌';
      debugPrint('$icon $api: ${configured ? 'Configured' : 'Missing'}');
    });
    debugPrint('================================');
  }
}