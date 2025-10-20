/// DoorDash Configuration Service
/// Manages API credentials and environment settings
import 'package:flutter/foundation.dart';
import '../services/environment_service.dart';

class DoorDashConfig {
  static const bool _isProduction = false; // Set to true when you get production credentials
  
  // Environment-based configuration using EnvironmentService
  static String get developerId => EnvironmentService.doorDashDeveloperId;
  static String get keyId => EnvironmentService.doorDashKeyId;
  static String get signingKey => EnvironmentService.doorDashSigningSecret;
  
  static String get baseUrl => _isProduction 
      ? 'https://openapi.doordash.com/drive/v2'
      : 'https://openapi.doordash.com/drive/v2'; // Same URL, different credentials
  
  static String get developerUrl => _isProduction
      ? 'https://openapi.doordash.com/developer/v1'
      : 'https://openapi.doordash.com/developer/v1';

  // Validation helpers
  static bool get hasValidCredentials => EnvironmentService.isDoorDashConfigured;

  static String get credentialStatus {
    if (!hasValidCredentials) {
      return _isProduction 
          ? 'Production credentials not configured'
          : 'Test credentials not configured';
    }
    return _isProduction ? 'Production ready' : 'Test environment';
  }

  // Debug information (remove in production)
  static void printDebugInfo() {
    if (kDebugMode) {
      debugPrint('=== DoorDash Config Debug ===');
      debugPrint('Environment: ${_isProduction ? "Production" : "Test"}');
      debugPrint('Base URL: $baseUrl');
      debugPrint('Developer ID: ${developerId.isNotEmpty ? developerId.substring(0, 8) + "..." : "Empty"}');
      debugPrint('Key ID: ${keyId.isNotEmpty ? keyId.substring(0, 8) + "..." : "Empty"}');
      debugPrint('Has Signing Key: ${signingKey.isNotEmpty}');
      debugPrint('Status: $credentialStatus');
      debugPrint('============================');
    }
  }
}