import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'database_service.dart';
import '../models/enhanced_emergency_contact.dart';

/// Intelligent notification service for emergency alerts
/// 
/// This service handles smart contact selection and escalation
/// based on proximity, availability, and response patterns.
class IntelligentNotificationService {
  static final IntelligentNotificationService _instance = IntelligentNotificationService._internal();
  factory IntelligentNotificationService() => _instance;
  IntelligentNotificationService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final Map<String, Timer> _responseTimers = {};
  final Map<String, int> _escalationLevels = {};

  /// Trigger emergency notifications with intelligent contact selection
  Future<void> triggerEmergencyNotifications({
    required String emergencyId,
    required double latitude,
    required double longitude,
    required String address,
    String? customMessage,
  }) async {
    try {
      debugPrint('Triggering emergency notifications for: $emergencyId');

      // Get and prioritize contacts
      final prioritizedContacts = await _getPrioritizedContacts(latitude, longitude);
      
      if (prioritizedContacts.isEmpty) {
        debugPrint('No emergency contacts available');
        return;
      }

      // Create emergency message
      final message = customMessage ?? _generateEmergencyMessage(address, latitude, longitude);

      // Start with the highest priority contacts (top 3)
      await _sendInitialNotifications(
        emergencyId: emergencyId,
        contacts: prioritizedContacts.take(3).toList(),
        message: message,
        latitude: latitude,
        longitude: longitude,
      );

      // Setup escalation for remaining contacts
      await _setupEscalation(
        emergencyId: emergencyId,
        allContacts: prioritizedContacts,
        notifiedContacts: prioritizedContacts.take(3).toList(),
        message: message,
        latitude: latitude,
        longitude: longitude,
      );

      debugPrint('Emergency notifications sent to ${prioritizedContacts.take(3).length} contacts');
    } catch (e) {
      debugPrint('Error triggering emergency notifications: $e');
      rethrow;
    }
  }

  /// Get prioritized list of contacts based on intelligent scoring
  Future<List<EnhancedEmergencyContact>> _getPrioritizedContacts(
    double latitude,
    double longitude,
  ) async {
    final contacts = await _databaseService.getEnhancedEmergencyContacts();
    
    // Update availability scores for all contacts
    final updatedContacts = <EnhancedEmergencyContact>[];
    for (final contact in contacts) {
      final availability = await _assessContactAvailability(contact);
      final updatedContact = contact.copyWith(availability: availability);
      updatedContacts.add(updatedContact);
    }

    // Sort by priority score (highest first)
    updatedContacts.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    // Apply additional intelligent filtering
    return _applyIntelligentFiltering(updatedContacts);
  }

  /// Apply intelligent filtering to contact list
  List<EnhancedEmergencyContact> _applyIntelligentFiltering(
    List<EnhancedEmergencyContact> contacts,
  ) {
    final filtered = <EnhancedEmergencyContact>[];
    final now = DateTime.now();

    for (final contact in contacts) {
      // Skip contacts that are likely unavailable
      if (contact.availability == ContactAvailability.unavailable) {
        continue;
      }

      // Prioritize contacts in similar time zones
      if (_isInSimilarTimeZone(contact, now)) {
        filtered.insert(0, contact); // Add to front
      } else {
        filtered.add(contact); // Add to end
      }
    }

    return filtered;
  }

  /// Check if contact is in a similar time zone
  bool _isInSimilarTimeZone(EnhancedEmergencyContact contact, DateTime now) {
    if (contact.frequentTimeZones.isEmpty) return true;

    final currentTimeZone = now.timeZoneName;
    return contact.frequentTimeZones.contains(currentTimeZone);
  }

  /// Assess contact availability based on various factors
  Future<ContactAvailability> _assessContactAvailability(
    EnhancedEmergencyContact contact,
  ) async {
    final now = DateTime.now();
    final hour = now.hour;

    // If contact has been active recently (within 15 minutes)
    if (contact.lastActiveTime != null) {
      final timeSinceActive = now.difference(contact.lastActiveTime!);
      if (timeSinceActive.inMinutes < 15) {
        return ContactAvailability.active;
      }
      if (timeSinceActive.inHours < 1) {
        return ContactAvailability.recentlyActive;
      }
    }

    // Check based on typical activity patterns and time zones
    if (contact.frequentTimeZones.isNotEmpty) {
      // Simulate time zone check (in real implementation, use proper time zone handling)
      final isBusinessHours = hour >= 9 && hour <= 17;
      final isEveningHours = hour >= 18 && hour <= 22;
      final isSleepingHours = hour >= 23 || hour <= 6;

      if (isSleepingHours) {
        return ContactAvailability.possiblyUnavailable;
      }
      if (isBusinessHours || isEveningHours) {
        return ContactAvailability.likelyAvailable;
      }
    }

    // Default assessment based on activity score
    if (contact.activityScore > 0.7) {
      return ContactAvailability.likelyAvailable;
    } else if (contact.activityScore > 0.3) {
      return ContactAvailability.recentlyActive;
    }

    return ContactAvailability.unknown;
  }

  /// Send initial notifications to top priority contacts
  Future<void> _sendInitialNotifications({
    required String emergencyId,
    required List<EnhancedEmergencyContact> contacts,
    required String message,
    required double latitude,
    required double longitude,
  }) async {
    for (final contact in contacts) {
      await _sendNotificationToContact(
        emergencyId: emergencyId,
        contact: contact,
        message: message,
        method: _selectBestNotificationMethod(contact),
        latitude: latitude,
        longitude: longitude,
      );

      // Setup 5-minute response timer
      _setupResponseTimer(emergencyId, contact.id);
    }
  }

  /// Send notification to a specific contact
  Future<void> _sendNotificationToContact({
    required String emergencyId,
    required EnhancedEmergencyContact contact,
    required String message,
    required NotificationMethod method,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Create notification record
      final notification = EmergencyNotification(
        id: _generateNotificationId(),
        emergencyId: emergencyId,
        contactId: contact.id,
        contactName: contact.name,
        contactPhone: contact.phoneNumber,
        message: message,
        sentAt: DateTime.now(),
        method: method,
        priorityScore: contact.priorityScore,
      );

      // Send notification via selected method
      bool success = false;
      switch (method) {
        case NotificationMethod.pushNotification:
          success = await _sendPushNotification(contact, message, latitude, longitude);
          break;
        case NotificationMethod.sms:
          success = await _sendSMS(contact, message, latitude, longitude);
          break;
        case NotificationMethod.phoneCall:
          success = await _makePhoneCall(contact);
          break;
        case NotificationMethod.email:
          success = await _sendEmail(contact, message, latitude, longitude);
          break;
      }

      // Update notification status
      final updatedNotification = notification.copyWith(
        status: success ? NotificationStatus.sent : NotificationStatus.failed,
      );

      // Store notification in database
      await _databaseService.addEmergencyNotification(updatedNotification);

      debugPrint('Notification sent to ${contact.name} via ${method.toString().split('.').last}: $success');
    } catch (e) {
      debugPrint('Error sending notification to ${contact.name}: $e');
    }
  }

  /// Select the best notification method for a contact
  NotificationMethod _selectBestNotificationMethod(EnhancedEmergencyContact contact) {
    // If contact has the app and is recently active, use push notification
    if (contact.hasApp && contact.fcmToken != null && 
        contact.availability == ContactAvailability.active) {
      return NotificationMethod.pushNotification;
    }

    // If contact is likely available, try SMS first
    if (contact.availability == ContactAvailability.likelyAvailable ||
        contact.availability == ContactAvailability.recentlyActive) {
      return NotificationMethod.sms;
    }

    // For urgent situations or unavailable contacts, try phone call
    if (contact.isPrimary || contact.availability == ContactAvailability.possiblyUnavailable) {
      return NotificationMethod.phoneCall;
    }

    // Default to SMS
    return NotificationMethod.sms;
  }

  /// Send push notification
  Future<bool> _sendPushNotification(
    EnhancedEmergencyContact contact,
    String message,
    double latitude,
    double longitude,
  ) async {
    if (contact.fcmToken == null) return false;

    try {
      // In a real implementation, this would use Firebase Cloud Messaging
      // For now, we'll simulate the API call
      debugPrint('Sending push notification to ${contact.name}: $message');
      
      // Simulate API call
      await Future.delayed(const Duration(milliseconds: 500));
      
      return true; // Simulate success
    } catch (e) {
      debugPrint('Failed to send push notification: $e');
      return false;
    }
  }

  /// Send SMS
  Future<bool> _sendSMS(
    EnhancedEmergencyContact contact,
    String message,
    double latitude,
    double longitude,
  ) async {
    try {
      // Create SMS with location link
      final locationUrl = 'https://maps.google.com/?q=$latitude,$longitude';
      final smsMessage = '$message\n\nLocation: $locationUrl';
      
      final uri = Uri(
        scheme: 'sms',
        path: contact.phoneNumber,
        queryParameters: {'body': smsMessage},
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to send SMS: $e');
      return false;
    }
  }

  /// Make phone call
  Future<bool> _makePhoneCall(EnhancedEmergencyContact contact) async {
    try {
      final uri = Uri(scheme: 'tel', path: contact.phoneNumber);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to make phone call: $e');
      return false;
    }
  }

  /// Send email
  Future<bool> _sendEmail(
    EnhancedEmergencyContact contact,
    String message,
    double latitude,
    double longitude,
  ) async {
    try {
      // For this implementation, we'll skip email as it requires contact email
      // In a real app, you'd store email addresses and use a proper email service
      debugPrint('Email notification not implemented for ${contact.name}');
      return false;
    } catch (e) {
      debugPrint('Failed to send email: $e');
      return false;
    }
  }

  /// Setup response timer for contact
  void _setupResponseTimer(String emergencyId, String contactId) {
    final timerId = '${emergencyId}_$contactId';
    
    _responseTimers[timerId] = Timer(const Duration(minutes: 5), () {
      _handleResponseTimeout(emergencyId, contactId);
    });
  }

  /// Handle response timeout and escalate if needed
  Future<void> _handleResponseTimeout(String emergencyId, String contactId) async {
    try {
      debugPrint('Response timeout for contact $contactId in emergency $emergencyId');

      // Mark notification as expired
      await _databaseService.markNotificationExpired(emergencyId, contactId);

      // Check if we need to escalate
      final currentLevel = _escalationLevels[emergencyId] ?? 0;
      await _escalateEmergency(emergencyId, currentLevel + 1);
    } catch (e) {
      debugPrint('Error handling response timeout: $e');
    }
  }

  /// Setup escalation for remaining contacts
  Future<void> _setupEscalation({
    required String emergencyId,
    required List<EnhancedEmergencyContact> allContacts,
    required List<EnhancedEmergencyContact> notifiedContacts,
    required String message,
    required double latitude,
    required double longitude,
  }) async {
    _escalationLevels[emergencyId] = 0;

    // Setup timer for first escalation (after 5 minutes)
    Timer(const Duration(minutes: 5), () {
      _escalateEmergency(emergencyId, 1);
    });
  }

  /// Escalate emergency to additional contacts
  Future<void> _escalateEmergency(String emergencyId, int level) async {
    try {
      debugPrint('Escalating emergency $emergencyId to level $level');

      _escalationLevels[emergencyId] = level;

      // Get emergency details
      final emergency = await _databaseService.getEmergencyEvent(emergencyId);
      if (emergency == null) return;

      // Get all contacts and those already notified
      final allContacts = await _getPrioritizedContacts(emergency.latitude, emergency.longitude);
      final notifiedContacts = await _databaseService.getNotifiedContacts(emergencyId);

      // Find next batch of contacts to notify
      final nextContacts = allContacts
          .where((contact) => !notifiedContacts.any((notified) => notified.contactId == contact.id))
          .take(2) // Notify 2 more contacts per escalation
          .toList();

      if (nextContacts.isEmpty) {
        debugPrint('No more contacts to escalate to');
        return;
      }

      // Send notifications to next batch
      final message = _generateEscalationMessage(emergency.address, level, emergency.latitude, emergency.longitude);
      
      for (final contact in nextContacts) {
        await _sendNotificationToContact(
          emergencyId: emergencyId,
          contact: contact,
          message: message,
          method: _selectBestNotificationMethod(contact),
          latitude: emergency.latitude,
          longitude: emergency.longitude,
        );

        _setupResponseTimer(emergencyId, contact.id);
      }

      // Setup next escalation if needed (max 3 levels)
      if (level < 3) {
        Timer(const Duration(minutes: 3), () {
          _escalateEmergency(emergencyId, level + 1);
        });
      }
    } catch (e) {
      debugPrint('Error escalating emergency: $e');
    }
  }

  /// Handle contact response
  Future<void> handleContactResponse({
    required String emergencyId,
    required String contactId,
    required ContactResponse response,
  }) async {
    try {
      debugPrint('Contact $contactId responded to emergency $emergencyId: $response');

      // Cancel response timer
      final timerId = '${emergencyId}_$contactId';
      _responseTimers[timerId]?.cancel();
      _responseTimers.remove(timerId);

      // Update notification with response
      await _databaseService.updateNotificationResponse(emergencyId, contactId, response);

      // If someone is helping, reduce escalation
      if (response == ContactResponse.willHelp || 
          response == ContactResponse.onMyWay || 
          response == ContactResponse.calledAuthorities) {
        await _reduceEscalation(emergencyId);
      }
    } catch (e) {
      debugPrint('Error handling contact response: $e');
    }
  }

  /// Reduce escalation when help is confirmed
  Future<void> _reduceEscalation(String emergencyId) async {
    debugPrint('Help confirmed for emergency $emergencyId, reducing escalation');
    
    // Cancel all pending escalation timers for this emergency
    _responseTimers.removeWhere((key, timer) {
      if (key.startsWith(emergencyId)) {
        timer.cancel();
        return true;
      }
      return false;
    });
  }

  /// Generate emergency message
  String _generateEmergencyMessage(String address, double latitude, double longitude) {
    return '''🚨 EMERGENCY ALERT 🚨

I need immediate help! This is an automated emergency alert from my safety app.

Location: $address
Coordinates: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}

Please respond within 5 minutes to confirm you can help, or call emergency services.

Time: ${DateTime.now().toString()}''';
  }

  /// Generate escalation message
  String _generateEscalationMessage(String address, int level, double latitude, double longitude) {
    return '''🚨 URGENT: Emergency Alert (Escalation Level $level) 🚨

Previous contacts haven't responded. I need immediate help!

Location: $address
Coordinates: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}

This is escalation level $level. Please respond immediately or call emergency services.

Time: ${DateTime.now().toString()}''';
  }

  /// Generate unique notification ID
  String _generateNotificationId() {
    return 'notif_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  /// Cleanup resources
  void dispose() {
    for (final timer in _responseTimers.values) {
      timer.cancel();
    }
    _responseTimers.clear();
    _escalationLevels.clear();
  }
}
