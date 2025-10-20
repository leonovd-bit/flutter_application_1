import 'package:flutter/foundation.dart';

// Conditional imports for web-specific functionality
import 'web_utils_stub.dart'
    if (dart.library.html) 'web_utils_web.dart';

class WebUtils {
  static void openUrl(String url) {
    if (kIsWeb) {
      openUrlImpl(url);
    }
  }
}