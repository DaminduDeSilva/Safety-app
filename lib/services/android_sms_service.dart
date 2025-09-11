import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Native Android SMS service using platform channels
/// This provides a backup method for sending SMS when URL launcher fails
class AndroidSMSService {
  static const MethodChannel _channel = MethodChannel('com.safety.app/sms');

  /// Send SMS using native Android method
  static Future<bool> sendSMSNative({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      if (phoneNumber.isEmpty || message.isEmpty) {
        debugPrint('Phone number or message is empty');
        return false;
      }

      final result = await _channel.invokeMethod('sendSMS', {
        'phoneNumber': phoneNumber,
        'message': message,
      });

      debugPrint('Native SMS result: $result');
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('Platform exception in native SMS: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error in native SMS: $e');
      return false;
    }
  }

  /// Send SMS to multiple recipients using native Android method
  static Future<Map<String, bool>> sendBulkSMSNative({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    final results = <String, bool>{};

    for (final phoneNumber in phoneNumbers) {
      final success = await sendSMSNative(
        phoneNumber: phoneNumber,
        message: message,
      );
      results[phoneNumber] = success;

      // Add small delay between SMS sends
      if (success) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    return results;
  }

  /// Check if SMS functionality is available
  static Future<bool> isSMSAvailable() async {
    try {
      final result = await _channel.invokeMethod('isSMSAvailable');
      return result == true;
    } catch (e) {
      debugPrint('Error checking SMS availability: $e');
      return false;
    }
  }

  /// Open default SMS app with pre-filled message
  static Future<bool> openSMSApp({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final result = await _channel.invokeMethod('openSMSApp', {
        'phoneNumber': phoneNumber,
        'message': message,
      });

      debugPrint('SMS app opened: $result');
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('Platform exception opening SMS app: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error opening SMS app: $e');
      return false;
    }
  }

  /// Open SMS app with multiple recipients
  static Future<bool> openSMSAppBulk({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    try {
      final result = await _channel.invokeMethod('openSMSAppBulk', {
        'phoneNumbers': phoneNumbers,
        'message': message,
      });

      debugPrint('Bulk SMS app opened: $result');
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('Platform exception opening bulk SMS app: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error opening bulk SMS app: $e');
      return false;
    }
  }
}
