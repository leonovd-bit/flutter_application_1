import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Run this script to completely clear all local app data
/// Usage: dart run clear_all_data.dart
Future<void> main() async {
  try {
    print('🧹 Starting complete data cleanup...');
    
    // Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    print('📦 Found ${keys.length} SharedPreferences keys');
    
    for (var key in keys) {
      print('   Removing: $key');
      await prefs.remove(key);
    }
    
    // Clear everything
    await prefs.clear();
    print('✅ SharedPreferences cleared!');
    
    print('\n🎉 Complete data cleanup finished!');
    print('📝 Next steps:');
    print('   1. Stop the app if running');
    print('   2. Delete the app data folder manually (see below)');
    print('   3. Run: flutter clean');
    print('   4. Run: flutter pub get');
    print('   5. Restart the app');
    print('\n💡 Manual cleanup locations:');
    print('   Windows: C:\\Users\\YOUR_USERNAME\\AppData\\Local\\flutter_application_1');
    print('   Or search for: %LOCALAPPDATA%\\flutter_application_1');
    
  } catch (e, stackTrace) {
    print('❌ Error during cleanup: $e');
    if (kDebugMode) {
      print('Stack trace: $stackTrace');
    }
  }
}
