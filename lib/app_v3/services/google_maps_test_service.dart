import 'package:flutter/foundation.dart';

class GoogleMapsTestService {
  static void testMapsIntegration() {
    debugPrint('🗺️ [GoogleMapsTest] Testing Google Maps integration...');
    
    // For web, check if Google Maps JavaScript API is loaded
    if (kIsWeb) {
      debugPrint('🌐 [GoogleMapsTest] Platform: Web');
      debugPrint('🌐 [GoogleMapsTest] Check browser console for Google Maps API errors');
      debugPrint('🌐 [GoogleMapsTest] Expected: No 403 or API key errors');
    } else {
      debugPrint('📱 [GoogleMapsTest] Platform: Mobile (Android/iOS)');
      debugPrint('📱 [GoogleMapsTest] Verify API keys in native configuration');
    }
    
    debugPrint('🗺️ [GoogleMapsTest] Integration test logged');
  }
  
  static void logMapError(String error) {
    debugPrint('❌ [GoogleMapsError] $error');
    debugPrint('💡 [GoogleMapsError] Check API key configuration');
    debugPrint('💡 [GoogleMapsError] Verify API restrictions in Google Cloud Console');
  }
  
  static void logMapSuccess() {
    debugPrint('✅ [GoogleMapsSuccess] Maps loaded successfully');
  }
}
