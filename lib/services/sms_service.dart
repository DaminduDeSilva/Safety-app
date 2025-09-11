import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'android_sms_service.dart';

/// Service for sending SMS messages using URL launcher
/// This approach opens the SMS app but pre-fills the message and recipient
class SMSService {
  /// Check if SMS permissions are granted
  static Future<bool> hasPermissions() async {
    try {
      final smsPermission = await Permission.sms.status;
      return smsPermission.isGranted;
    } catch (e) {
      debugPrint('Error checking SMS permissions: $e');
      return false;
    }
  }

  /// Request SMS permissions
  static Future<bool> requestPermissions() async {
    try {
      final smsPermission = await Permission.sms.request();
      return smsPermission.isGranted;
    } catch (e) {
      debugPrint('Error requesting SMS permissions: $e');
      return false;
    }
  }

  /// Send SMS using multiple methods (prioritizes automatic sending)
  static Future<bool> sendSMS({
    required String phoneNumber,
    required String message,
    bool preferAutomatic = true,
  }) async {
    try {
      // Clean and validate phone number
      final cleanedPhone = _cleanPhoneNumber(phoneNumber);

      if (!_isValidPhoneNumber(cleanedPhone)) {
        debugPrint(
          'Invalid phone number: $phoneNumber (cleaned: $cleanedPhone)',
        );
        return false;
      }

      // For emergency situations, try automatic SMS first
      if (preferAutomatic) {
        try {
          debugPrint('Attempting automatic SMS send to $cleanedPhone');
          final automaticSuccess = await AndroidSMSService.sendSMSNative(
            phoneNumber: cleanedPhone,
            message: message,
          );
          if (automaticSuccess) {
            debugPrint('Automatic SMS sent successfully to $phoneNumber');
            return true;
          }
          debugPrint('Automatic SMS failed, falling back to SMS app');
        } catch (e) {
          debugPrint('Automatic SMS error: $e');
        }
      }

      // Fallback to opening SMS app with pre-filled message
      final List<Uri> smsUrls = [
        // Standard SMS URL
        Uri(
          scheme: 'sms',
          path: cleanedPhone,
          query: 'body=${Uri.encodeComponent(message)}',
        ),
        // Alternative SMSTO format
        Uri(
          scheme: 'smsto',
          path: cleanedPhone,
          query: 'body=${Uri.encodeComponent(message)}',
        ),
        // Another alternative format
        Uri.parse('sms:$cleanedPhone?body=${Uri.encodeComponent(message)}'),
      ];

      for (final smsUrl in smsUrls) {
        try {
          if (await canLaunchUrl(smsUrl)) {
            await launchUrl(smsUrl, mode: LaunchMode.externalApplication);
            debugPrint(
              'SMS app opened for $phoneNumber using ${smsUrl.scheme}',
            );
            return true;
          }
        } catch (e) {
          debugPrint('Failed to launch SMS URL ${smsUrl.toString()}: $e');
          continue;
        }
      }

      // If all URL methods fail, try using SEND intent
      try {
        final sendUri = Uri(
          scheme: 'mailto',
          path: '',
          query:
              'to=$cleanedPhone&subject=Emergency&body=${Uri.encodeComponent(message)}',
        );

        if (await canLaunchUrl(sendUri)) {
          await launchUrl(sendUri, mode: LaunchMode.externalApplication);
          debugPrint('Opened messaging app for $phoneNumber via email intent');
          return true;
        }
      } catch (e) {
        debugPrint('Failed to launch email intent: $e');
      }

      // Final fallback: try native Android SMS service
      try {
        debugPrint('Trying native Android SMS service for $phoneNumber');
        final nativeSuccess = await AndroidSMSService.openSMSApp(
          phoneNumber: cleanedPhone,
          message: message,
        );
        if (nativeSuccess) {
          debugPrint('Native SMS app opened for $phoneNumber');
          return true;
        }
      } catch (e) {
        debugPrint('Native SMS service failed: $e');
      }

      debugPrint('All SMS methods failed for $phoneNumber');
      return false;
    } catch (e) {
      debugPrint('Failed to send SMS to $phoneNumber: $e');
      return false;
    }
  }

  /// Clean phone number by removing unwanted characters
  static String _cleanPhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) {
      return '';
    }

    // Trim whitespace first
    String cleaned = phoneNumber.trim();

    // Remove all non-digit characters except + at the beginning
    cleaned = cleaned.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleaned.isEmpty) {
      return '';
    }

    // If starts with +, keep it, otherwise remove any + in the middle
    if (cleaned.startsWith('+')) {
      cleaned = '+' + cleaned.substring(1).replaceAll('+', '');
    } else {
      cleaned = cleaned.replaceAll('+', '');

      // Handle common country-specific formatting
      if (cleaned.isNotEmpty) {
        // Sri Lankan numbers: convert 0XXXXXXXXX to +94XXXXXXXXX
        if (cleaned.startsWith('0') && cleaned.length == 10) {
          cleaned = '+94${cleaned.substring(1)}';
        }
        // US/Canada numbers: convert 1XXXXXXXXXX or XXXXXXXXXX to +1XXXXXXXXXX
        else if (cleaned.length == 11 && cleaned.startsWith('1')) {
          cleaned = '+$cleaned';
        } else if (cleaned.length == 10 && !cleaned.startsWith('0')) {
          cleaned = '+1$cleaned'; // Assume US/Canada
        }
        // If it's just digits and not matching above patterns,
        // assume it needs a country code - try to add Sri Lankan code
        else if (cleaned.length == 9 && cleaned.startsWith('7')) {
          // Sri Lankan mobile without leading 0
          cleaned = '+94$cleaned';
        }
      }
    }

    return cleaned;
  }

  /// Validate if phone number is in correct format
  static bool _isValidPhoneNumber(String phoneNumber) {
    if (phoneNumber.isEmpty) return false;

    // Must be in international format starting with +
    if (!phoneNumber.startsWith('+')) {
      return false;
    }

    // International format: +[country code][number] (at least 11 digits total)
    return phoneNumber.length >= 11 &&
        phoneNumber.length <= 16 && // Maximum international number length
        RegExp(r'^\+\d{10,15}$').hasMatch(phoneNumber);
  }

  /// Send SMS to multiple contacts (prioritizes automatic sending)
  static Future<Map<String, bool>> sendBulkSMS({
    required List<String> phoneNumbers,
    required String message,
    bool preferAutomatic = true,
  }) async {
    final results = <String, bool>{};

    for (final phoneNumber in phoneNumbers) {
      final success = await sendSMS(
        phoneNumber: phoneNumber,
        message: message,
        preferAutomatic: preferAutomatic,
      );
      results[phoneNumber] = success;

      // Add small delay between SMS launches to prevent overwhelming the system
      if (success) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    return results;
  }

  /// Alternative method that combines multiple recipients into one SMS
  static Future<bool> sendBulkSMSCombined({
    required List<String> phoneNumbers,
    required String message,
    bool preferAutomatic = true,
  }) async {
    try {
      if (phoneNumbers.isEmpty) {
        debugPrint('No phone numbers provided');
        return false;
      }

      // Clean all phone numbers and filter out valid ones
      final cleanedPhones = phoneNumbers
          .map((phone) => _cleanPhoneNumber(phone))
          .where((phone) => _isValidPhoneNumber(phone))
          .toList();

      if (cleanedPhones.isEmpty) {
        debugPrint('No valid phone numbers after cleaning');
        debugPrint('Original numbers: $phoneNumbers');
        debugPrint(
          'After cleaning: ${phoneNumbers.map(_cleanPhoneNumber).toList()}',
        );
        return false;
      }

      debugPrint(
        'Attempting to send SMS to ${cleanedPhones.length} recipients: $cleanedPhones',
      );

      // For emergency situations, try automatic SMS to each contact first
      if (preferAutomatic) {
        try {
          debugPrint('Attempting automatic SMS to all contacts');
          final results = await AndroidSMSService.sendBulkSMSNative(
            phoneNumbers: cleanedPhones,
            message: message,
          );

          final successCount = results.values
              .where((success) => success)
              .length;
          if (successCount > 0) {
            debugPrint(
              'Automatic SMS sent to $successCount/${cleanedPhones.length} contacts',
            );
            return true; // Consider success if at least one message was sent
          }
          debugPrint('All automatic SMS failed, falling back to SMS app');
        } catch (e) {
          debugPrint('Bulk automatic SMS error: $e');
        }
      }

      // Create SMS URL with multiple recipients
      final recipients = cleanedPhones.join(',');

      // Try different SMS URL formats for bulk sending
      final List<Uri> smsUrls = [
        // Standard SMS with comma-separated numbers
        Uri(
          scheme: 'sms',
          path: recipients,
          query: 'body=${Uri.encodeComponent(message)}',
        ),
        // Alternative format with semicolon separation
        Uri(
          scheme: 'sms',
          path: cleanedPhones.join(';'),
          query: 'body=${Uri.encodeComponent(message)}',
        ),
        // SMSTO format
        Uri(
          scheme: 'smsto',
          path: recipients,
          query: 'body=${Uri.encodeComponent(message)}',
        ),
      ];

      for (final smsUrl in smsUrls) {
        try {
          debugPrint('Trying SMS URL: ${smsUrl.toString()}');
          if (await canLaunchUrl(smsUrl)) {
            await launchUrl(smsUrl, mode: LaunchMode.externalApplication);
            debugPrint(
              'SMS app opened for ${cleanedPhones.length} recipients using ${smsUrl.scheme}',
            );
            return true;
          }
        } catch (e) {
          debugPrint('Failed SMS URL ${smsUrl.toString()}: $e');
          continue;
        }
      }

      // Final fallback: try native Android SMS service for bulk
      try {
        debugPrint('Trying native Android bulk SMS service');
        final nativeSuccess = await AndroidSMSService.openSMSAppBulk(
          phoneNumbers: cleanedPhones,
          message: message,
        );
        if (nativeSuccess) {
          debugPrint('Native bulk SMS app opened');
          return true;
        }
      } catch (e) {
        debugPrint('Native bulk SMS service failed: $e');
      }

      debugPrint('All bulk SMS methods failed');
      return false;
    } catch (e) {
      debugPrint('Failed to send bulk SMS: $e');
      return false;
    }
  }

  /// Send SMS with enhanced error handling and retries
  static Future<bool> sendSMSWithRetry({
    required String phoneNumber,
    required String message,
    int maxRetries = 1, // Reduced retries since we're using URL launcher
  }) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final success = await sendSMS(
          phoneNumber: phoneNumber,
          message: message,
        );

        if (success) {
          return true;
        }

        if (attempt < maxRetries) {
          debugPrint('SMS send attempt ${attempt + 1} failed, retrying...');
          await Future.delayed(Duration(milliseconds: 1000 * (attempt + 1)));
        }
      } catch (e) {
        debugPrint('SMS send attempt ${attempt + 1} error: $e');
        if (attempt == maxRetries) {
          return false;
        }
      }
    }

    return false;
  }

  /// Send emergency SMS to all contacts (prioritizes automatic sending)
  static Future<int> sendEmergencySMSBulk({
    required List<String> phoneNumbers,
    required String message,
    bool preferAutomatic = true,
  }) async {
    if (phoneNumbers.isEmpty) {
      debugPrint('No phone numbers provided for emergency SMS');
      return 0;
    }

    try {
      // Ensure we have SMS permissions for automatic sending
      if (preferAutomatic) {
        final hasPermission = await hasPermissions();
        if (!hasPermission) {
          debugPrint('SMS permission not granted, requesting...');
          final granted = await requestPermissions();
          if (!granted) {
            debugPrint('SMS permission denied, falling back to SMS app');
            preferAutomatic = false;
          }
        }
      }

      // Clean all phone numbers first
      final cleanedPhones = phoneNumbers
          .map((phone) => _cleanPhoneNumber(phone))
          .where((phone) => _isValidPhoneNumber(phone))
          .toList();

      if (cleanedPhones.isEmpty) {
        debugPrint('No valid phone numbers for emergency SMS');
        return 0;
      }

      debugPrint(
        'Sending emergency SMS to ${cleanedPhones.length} contacts: $cleanedPhones',
      );

      // For emergency situations, prioritize automatic SMS sending
      if (preferAutomatic) {
        try {
          debugPrint('Attempting automatic emergency SMS to all contacts');
          final results = await AndroidSMSService.sendBulkSMSNative(
            phoneNumbers: cleanedPhones,
            message: message,
          );

          final successCount = results.values
              .where((success) => success)
              .length;
          if (successCount > 0) {
            debugPrint(
              '✅ Emergency SMS automatically sent to $successCount/${cleanedPhones.length} contacts',
            );
            return successCount;
          }
          debugPrint(
            'All automatic SMS failed, falling back to SMS app method',
          );
        } catch (e) {
          debugPrint('Automatic emergency SMS error: $e');
        }
      }

      // Fallback: Try combined approach (opens SMS app with all recipients)
      final combinedSuccess = await sendBulkSMSCombined(
        phoneNumbers: cleanedPhones,
        message: message,
        preferAutomatic: false, // Don't retry automatic in the nested call
      );

      if (combinedSuccess) {
        debugPrint(
          'Emergency SMS app opened for all ${cleanedPhones.length} contacts',
        );
        return cleanedPhones.length;
      }

      // Fallback to individual SMS if combined approach fails
      debugPrint('Combined SMS failed, sending individual messages...');
      final results = await sendBulkSMS(
        phoneNumbers: phoneNumbers,
        message: message,
      );

      final successCount = results.values.where((success) => success).length;
      debugPrint(
        'Emergency SMS sent individually to $successCount/${phoneNumbers.length} contacts',
      );
      return successCount;
    } catch (e) {
      debugPrint('Failed to send emergency SMS bulk: $e');
      return 0;
    }
  }
}
