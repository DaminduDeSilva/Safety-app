import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Service to handle native Android notification functionality
///
/// This service provides communication between Flutter and the native
/// Android NotificationService for background Firebase Realtime Database listening.
class NativeNotificationService {
  static const MethodChannel _channel = MethodChannel(
    'com.safety.app/notifications',
  );

  static final NativeNotificationService _instance =
      NativeNotificationService._internal();
  factory NativeNotificationService() => _instance;
  NativeNotificationService._internal();

  /// Start the background notification service with user ID
  static Future<bool> startBackgroundService({String? userId}) async {
    try {
      final bool result = await _channel.invokeMethod(
        'startNotificationService',
        {'userId': userId},
      );
      debugPrint(
        'Background notification service started: $result for userId: $userId',
      );
      return result;
    } on PlatformException catch (e) {
      debugPrint(
        'Failed to start background notification service: ${e.message}',
      );
      return false;
    }
  }

  /// Stop the background notification service
  static Future<bool> stopBackgroundService() async {
    try {
      final bool result = await _channel.invokeMethod(
        'stopNotificationService',
      );
      debugPrint('Background notification service stopped: $result');
      return result;
    } on PlatformException catch (e) {
      debugPrint(
        'Failed to stop background notification service: ${e.message}',
      );
      return false;
    }
  }
}
