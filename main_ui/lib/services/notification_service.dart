import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:main_ui/services/api_service.dart';

/// Local notification service — no Firebase / FCM dependency.
///
/// On mobile, flutter_local_notifications shows heads-up banners.
/// The backend stores notifications in its DB; this service can be
/// called after any API response to trigger a local notification,
/// or you can add a periodic polling mechanism here.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'pcmc_grievance_channel',
    'PCMC Grievance Notifications',
    description: 'Notifications for grievance status updates',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    if (kIsWeb) return; // Web uses browser notifications — future work

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(initSettings);

    // Create the high-importance channel (Android 8+)
    if (!kIsWeb && Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }
  }

  /// Show a local notification immediately.
  static Future<void> show({
    required String title,
    required String body,
    int id = 0,
  }) async {
    if (kIsWeb) return;

    final androidDetails = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  /// Poll the backend for new unread notifications and surface them locally.
  /// Call this after login or from a periodic timer in your app lifecycle.
  static Future<void> syncFromBackend() async {
    try {
      final response = await ApiService.get('/notifications/unread');
      final List items = response.data is List ? response.data : [];
      for (int i = 0; i < items.length; i++) {
        final n = items[i];
        await show(
          id: n['id'] ?? i,
          title: n['title'] ?? 'PCMC Update',
          body: n['body'] ?? '',
        );
      }
    } catch (_) {
      // Silently ignore — notifications are non-critical
    }
  }
}
