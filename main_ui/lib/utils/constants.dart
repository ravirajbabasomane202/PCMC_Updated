import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class Constants {
  static String get baseUrl {
    // Use API_BASE_URL from dart-define if available, otherwise use default.
    // For mobile builds, this ensures the app points to the Render backend.
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://pcmcapp.onrender.com',
    );

    return apiBaseUrl;
  }
}
