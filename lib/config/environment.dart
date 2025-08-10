// Production Environment Configuration
class ProductionConfig {
  // App Identity
  static const String appName = 'YourAppName'; // Change this
  static const String appId = 'com.yourdomain.yourapp'; // Change this
  static const String version = '1.0.0';
  
  // Production API Keys (REPLACE WITH YOUR PRODUCTION KEYS)
  static const String stripePublishableKey = 'pk_live_YOUR_PRODUCTION_STRIPE_KEY';
  static const String googleMapsApiKey = 'YOUR_PRODUCTION_GOOGLE_MAPS_KEY';
  
  // Firebase Configuration
  static const String firebaseProjectId = 'your-production-firebase-project';
  
  // Feature Flags
  static const bool enableDebugLogging = false;
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;
  
  // App Store URLs
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=$appId';
  static const String appStoreUrl = 'https://apps.apple.com/app/id[YOUR_APP_ID]';
  
  // Support & Legal
  static const String supportEmail = 'support@yourdomain.com';
  static const String privacyPolicyUrl = 'https://yourdomain.com/privacy';
  static const String termsOfServiceUrl = 'https://yourdomain.com/terms';
  
  // Production Settings
  static const bool isProduction = true;
  static const String baseApiUrl = 'https://api.yourdomain.com';
}

// Development Configuration (for comparison)
class DevelopmentConfig {
  static const String appName = 'YourAppName (Debug)';
  static const String appId = 'com.yourdomain.yourapp.debug';
  static const String version = '1.0.0-dev';
  
  // Development/Test API Keys
  static const String stripePublishableKey = 'pk_test_YOUR_TEST_STRIPE_KEY';
  static const String googleMapsApiKey = 'YOUR_DEVELOPMENT_GOOGLE_MAPS_KEY';
  
  static const String firebaseProjectId = 'your-development-firebase-project';
  
  static const bool enableDebugLogging = true;
  static const bool enableAnalytics = false;
  static const bool enableCrashReporting = false;
  
  static const bool isProduction = false;
  static const String baseApiUrl = 'https://api-dev.yourdomain.com';
}

// Environment selector
class Environment {
  static const bool _isProduction = bool.fromEnvironment('dart.vm.product');
  
  static String get appName => _isProduction ? ProductionConfig.appName : DevelopmentConfig.appName;
  static String get appId => _isProduction ? ProductionConfig.appId : DevelopmentConfig.appId;
  static String get version => _isProduction ? ProductionConfig.version : DevelopmentConfig.version;
  
  static String get stripePublishableKey => _isProduction 
    ? ProductionConfig.stripePublishableKey 
    : DevelopmentConfig.stripePublishableKey;
    
  static String get googleMapsApiKey => _isProduction 
    ? ProductionConfig.googleMapsApiKey 
    : DevelopmentConfig.googleMapsApiKey;
    
  static String get firebaseProjectId => _isProduction 
    ? ProductionConfig.firebaseProjectId 
    : DevelopmentConfig.firebaseProjectId;
    
  static bool get enableDebugLogging => _isProduction 
    ? ProductionConfig.enableDebugLogging 
    : DevelopmentConfig.enableDebugLogging;
    
  static bool get enableAnalytics => _isProduction 
    ? ProductionConfig.enableAnalytics 
    : DevelopmentConfig.enableAnalytics;
    
  static bool get enableCrashReporting => _isProduction 
    ? ProductionConfig.enableCrashReporting 
    : DevelopmentConfig.enableCrashReporting;
    
  static bool get isProduction => _isProduction;
  
  static String get baseApiUrl => _isProduction 
    ? ProductionConfig.baseApiUrl 
    : DevelopmentConfig.baseApiUrl;
}
