import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class Constants {
  static String get baseUrl {
    // Use API_BASE_URL from dart-define if available, otherwise use default
    const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://pcmc-updated.onrender.com');

    if (kIsWeb) return apiBaseUrl;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      default:
        return apiBaseUrl;
    }
  }
}
