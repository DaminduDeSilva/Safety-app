import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/realtime_notification.dart';
import 'database_service.dart';
import 'user_session_service.dart';

/// Service for managing real-time notifications using Firebase Realtime Database
///
/// This service handles:
/// - Sending notifications to live guardians who don't have phone numbers
/// - Real-time listening for incoming notifications
/// - Background notification display
/// - Integration with local notifications
class RealtimeNotificationService {
  static final RealtimeNotificationService _instance =
      RealtimeNotificationService._internal();
  factory RealtimeNotificationService() => _instance;
  RealtimeNotificationService._internal();

  late final FirebaseDatabase _database;
  final DatabaseService _databaseService = DatabaseService();
  final UserSessionService _sessionService = UserSessionService();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<DatabaseEvent>? _notificationListener;
  final Map<String, StreamSubscription<DatabaseEvent>> _guardianListeners = {};

  /// Initialize the notification service
  Future<void> initialize() async {
    try {
      debugPrint('🔄 Initializing Firebase Realtime Database...');

      // Initialize Firebase Realtime Database with proper URL
      _database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://safety-app-487c6-default-rtdb.firebaseio.com',
      );

      debugPrint('✅ Firebase Realtime Database initialized successfully');

      // Test basic connectivity first
      await _testBasicConnectivity();

      await _initializeLocalNotifications();
      await _startListeningForNotifications();
    } catch (e) {
      debugPrint('❌ Error initializing RealtimeNotificationService: $e');
      rethrow;
    }
  }

  /// Test basic Firebase connectivity
  Future<void> _testBasicConnectivity() async {
    try {
      debugPrint('🔄 Testing basic Firebase connectivity...');

      // Simple write test
      final testRef = _database.ref('connection_test');
      await testRef.set({
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'message': 'Connection test successful',
      });

      debugPrint('✅ Basic write test passed');

      // Simple read test
      final snapshot = await testRef.get();
      if (snapshot.exists) {
        debugPrint('✅ Basic read test passed: ${snapshot.value}');
      } else {
        debugPrint('❌ Basic read test failed');
      }

      // Clean up test data
      await testRef.remove();
      debugPrint('✅ Test cleanup completed');
    } catch (e) {
      debugPrint('❌ Basic connectivity test failed: $e');
      rethrow;
    }
  }

  /// Initialize Flutter Local Notifications
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request notification permissions for Android 13+
    await _requestNotificationPermissions();
  }

  /// Request notification permissions for Android 13+
  Future<void> _requestNotificationPermissions() async {
    try {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('Notification permission granted: $granted');
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');

    // Don't automatically mark as read - let user use the "Mark Read" button in UI
    debugPrint('Notification tapped, user can mark as read using UI button');

    // Navigate to appropriate screen based on payload
    // This will be handled by the main app navigation
  }

  /// Get the current user ID from session service (persists across logout)
  Future<String?> _getCurrentUserId() async {
    return await _sessionService.getCurrentUserId();
  }

  /// Start listening for notifications addressed to the current user
  Future<void> _startListeningForNotifications() async {
    final userId = await _getCurrentUserId();
    if (userId == null) {
      debugPrint('❌ No user ID found, cannot start notification listener');
      return;
    }

    debugPrint('🔄 Starting notification listener for user: $userId');

    // Listen for notifications where current user is the guardian
    final notificationsRef = _database.ref('notifications/$userId');

    // Add error handling for the listener
    _notificationListener = notificationsRef.onValue.listen(
      (DatabaseEvent event) {
        debugPrint('🔔 Notification listener triggered');
        debugPrint('🔔 Event type: ${event.type}');
        debugPrint('🔔 Event data: ${event.snapshot.value}');
        _handleIncomingNotification(event);
      },
      onError: (error) {
        debugPrint('❌ Notification listener error: $error');
      },
    );

    debugPrint(
      '✅ Started listening for notifications at path: notifications/$userId',
    );
  }

  /// Handle incoming notification
  void _handleIncomingNotification(DatabaseEvent event) async {
    try {
      debugPrint('🔔 Processing incoming notification...');

      if (event.snapshot.value == null) {
        debugPrint('🔔 Null notification value, skipping');
        return;
      }

      debugPrint('🔔 Raw notification data: ${event.snapshot.value}');

      // Handle different data structures
      dynamic rawData = event.snapshot.value;

      // If it's a Map, process each child notification
      if (rawData is Map) {
        final dataMap = Map<String, dynamic>.from(rawData);
        debugPrint('🔔 Processing ${dataMap.length} notifications');

        for (final entry in dataMap.entries) {
          debugPrint('🔔 Processing notification key: ${entry.key}');

          if (entry.value is Map) {
            final notificationData = Map<String, dynamic>.from(
              entry.value as Map,
            );
            debugPrint('🔔 Notification data: $notificationData');

            // Check if notification is already read and timestamp for recent notifications
            final isRead = notificationData['isRead'] as bool? ?? false;
            final timestamp = notificationData['timestamp'] as int? ?? 0;
            final fiveMinutesAgo =
                DateTime.now().millisecondsSinceEpoch - (5 * 60 * 1000);

            if (!isRead && timestamp > fiveMinutesAgo) {
              debugPrint('🔔 Showing unread recent notification');

              // Show simple notification
              await _showSimpleNotification(
                title:
                    notificationData['senderName']?.toString() ??
                    'Safety Alert',
                message:
                    notificationData['message']?.toString() ??
                    'New notification',
                notificationId:
                    entry.key, // Pass the notification ID for tracking
              );
            } else {
              debugPrint(
                '🔔 Skipping notification (read: $isRead, timestamp: $timestamp)',
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling incoming notification: $e');
    }
  }

  /// Show simple local notification
  Future<void> _showSimpleNotification({
    required String title,
    required String message,
    String? notificationId,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'emergency_notifications',
        'Emergency Notifications',
        channelDescription: 'Notifications for emergency alerts',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecond,
        title,
        message,
        notificationDetails,
        payload: notificationId, // Pass sender ID as payload for reference
      );

      debugPrint('✅ Local notification shown: $title - $message');
      debugPrint(
        '📌 Notification will remain unread until user marks it as read in UI',
      );
    } catch (e) {
      debugPrint('❌ Error showing local notification: $e');
    }
  }

  // Removed automatic mark-as-read functionality
  // Notifications are now only marked as read when user clicks "Mark Read" button in UI

  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) return;

      final notificationsRef = _database.ref('notifications/$userId');
      final snapshot = await notificationsRef.get();

      if (snapshot.exists && snapshot.value is Map) {
        final notifications = Map<String, dynamic>.from(snapshot.value as Map);

        for (final senderId in notifications.keys) {
          await notificationsRef.child(senderId).update({
            'isRead': true,
            'readAt': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }

      debugPrint('✅ Marked all notifications as read');
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }

  /// Send notification to live guardian using the working approach
  Future<bool> sendNotificationToGuardian({
    required String guardianId,
    required String message,
    required String type,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('🔄 Sending notification to guardian: $guardianId');

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('❌ No authenticated user found');
        return false;
      }

      debugPrint('✅ Current user ID: ${currentUser.uid}');

      // Use the same simple approach that works in tests
      final notificationData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'senderId': currentUser.uid,
        'senderName':
            currentUser.displayName ?? currentUser.email ?? 'Safety App User',
        'guardianId': guardianId,
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': type,
        'created_at': DateTime.now().toIso8601String(),
        'isRead': false,
      };

      // Add metadata if provided
      if (metadata != null) {
        notificationData['metadata'] = metadata;
      }

      // Store in Realtime Database using the same pattern as successful tests
      final dbPath = 'notifications/$guardianId/${currentUser.uid}';
      debugPrint('🔄 Writing notification to: $dbPath');
      debugPrint('🔄 Notification data: $notificationData');

      await _database.ref(dbPath).set(notificationData);

      debugPrint('✅ Successfully sent notification to guardian $guardianId');
      debugPrint('✅ Message: $message');

      return true;
    } catch (e) {
      debugPrint('❌ Error sending notification to guardian: $e');
      if (e is FirebaseException) {
        debugPrint('❌ Firebase error code: ${e.code}');
        debugPrint('❌ Firebase error message: ${e.message}');
      }
      return false;
    }
  }

  /// Send emergency notifications to all live guardians without phone numbers
  Future<void> sendEmergencyNotificationsToGuardians({
    required String emergencyMessage,
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    try {
      // Get all emergency contacts
      final contacts = await _databaseService.getEmergencyContacts();

      // Filter contacts that don't have phone numbers (live guardians with app access only)
      final appOnlyContacts = contacts
          .where(
            (contact) =>
                contact.phoneNumber.isEmpty || contact.phoneNumber == 'N/A',
          )
          .toList();

      if (appOnlyContacts.isEmpty) {
        debugPrint('No app-only emergency contacts found');
        return;
      }

      final metadata = {
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'mapUrl': 'https://maps.google.com/?q=$latitude,$longitude',
      };

      // Send notification to each app-only contact
      for (final contact in appOnlyContacts) {
        if (contact.contactId != null) {
          await sendNotificationToGuardian(
            guardianId: contact.contactId!,
            message: emergencyMessage,
            type: 'emergency',
            metadata: metadata,
          );
        }
      }

      debugPrint(
        'Emergency notifications sent to ${appOnlyContacts.length} live guardians',
      );
    } catch (e) {
      debugPrint('Error sending emergency notifications to guardians: $e');
    }
  }

  /// Get notifications for current user as a stream
  Stream<List<RealtimeNotification>> getNotificationsStream() {
    return Stream.fromFuture(_getCurrentUserId()).asyncExpand((userId) {
      if (userId == null) {
        return Stream.value([]);
      }

      return _database.ref('notifications/$userId').onValue.map((event) {
        final notifications = <RealtimeNotification>[];

        if (event.snapshot.value != null) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);

          for (final entry in data.entries) {
            try {
              // Check if the entry value is a Map (valid notification object)
              if (entry.value is! Map) {
                debugPrint(
                  'Skipping non-map notification entry: ${entry.key} = ${entry.value}',
                );
                continue;
              }

              final notificationData = Map<String, dynamic>.from(
                entry.value as Map,
              );

              // Validate that this looks like a notification object
              if (!_isValidNotificationData(notificationData)) {
                debugPrint('Skipping invalid notification data: ${entry.key}');
                continue;
              }

              final notification = RealtimeNotification.fromMap(
                notificationData,
                entry.key,
              );
              notifications.add(notification);
            } catch (e) {
              debugPrint('Error parsing notification: $e');
            }
          }
        }

        // Sort by timestamp (newest first)
        notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return notifications;
      });
    });
  }

  /// Mark notification as read
  Future<void> markAsRead(String senderId) async {
    final userId = await _getCurrentUserId();
    if (userId == null) return;

    try {
      await _database.ref('notifications/$userId/$senderId').update({
        'isRead': true,
        'readAt': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('✅ Marked notification as read: $senderId');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  /// Clear all notifications for current user
  Future<void> clearAllNotifications() async {
    final userId = await _getCurrentUserId();
    if (userId == null) return;

    try {
      await _database.ref('notifications/$userId').remove();
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  /// Test database connectivity with simple write/read
  Future<void> testDatabaseConnection() async {
    try {
      debugPrint('🔄 Testing Firebase Realtime Database connection...');

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('❌ No authenticated user for database test');
        return;
      }

      debugPrint('🔄 User authenticated: ${currentUser.uid}');

      // Test simple write
      final testPath = 'test/${currentUser.uid}';
      final testData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'message': 'Simple database test',
        'userId': currentUser.uid,
      };

      debugPrint('🔄 Writing to path: $testPath');
      debugPrint('🔄 Data: $testData');

      await _database.ref(testPath).set(testData);
      debugPrint('✅ Database write successful');

      // Test read
      debugPrint('🔄 Reading from path: $testPath');
      final snapshot = await _database.ref(testPath).get();

      if (snapshot.exists) {
        debugPrint('✅ Database read successful: ${snapshot.value}');
      } else {
        debugPrint('❌ Database read failed: no data found');
      }

      // Test listener
      debugPrint('🔄 Testing database listener...');
      final listenerRef = _database.ref(testPath);
      final listener = listenerRef.onValue.listen((event) {
        debugPrint('✅ Database listener triggered: ${event.snapshot.value}');
      });

      // Update data to trigger listener
      await listenerRef.update({
        'updated': DateTime.now().millisecondsSinceEpoch,
      });

      // Clean up
      await Future.delayed(const Duration(seconds: 2));
      listener.cancel();
      await listenerRef.remove();
      debugPrint('✅ Database test cleanup completed');
    } catch (e) {
      debugPrint('❌ Database connection test failed: $e');
      if (e is FirebaseException) {
        debugPrint('❌ Firebase error code: ${e.code}');
        debugPrint('❌ Firebase error message: ${e.message}');
      }
      rethrow;
    }
  }

  /// Simple notification send test
  Future<bool> sendSimpleTestNotification(
    String guardianId,
    String message,
  ) async {
    try {
      debugPrint('🔄 Sending simple test notification...');

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('❌ No authenticated user');
        return false;
      }

      final notificationData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'senderId': currentUser.uid,
        'senderName': currentUser.displayName ?? 'Test User',
        'guardianId': guardianId,
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': 'test',
      };

      final path = 'notifications/$guardianId/${currentUser.uid}';
      debugPrint('🔄 Writing notification to: $path');
      debugPrint('🔄 Notification data: $notificationData');

      await _database.ref(path).set(notificationData);
      debugPrint('✅ Simple notification sent successfully');

      return true;
    } catch (e) {
      debugPrint('❌ Failed to send simple notification: $e');
      return false;
    }
  }

  /// Write persistent test data that won't be cleaned up
  Future<bool> writePersistentTestData() async {
    try {
      debugPrint('🔄 Writing persistent test data to Firebase...');

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('❌ No authenticated user for persistent test');
        return false;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final testData = {
        'test_timestamp': timestamp,
        'test_message':
            'Persistent test data - should appear in Firebase console',
        'user_id': currentUser.uid,
        'user_email': currentUser.email ?? 'no_email',
        'created_at': DateTime.now().toIso8601String(),
      };

      // Write to multiple paths for visibility
      await _database.ref('persistent_test').set(testData);
      await _database.ref('test_data/$timestamp').set(testData);
      await _database.ref('users/${currentUser.uid}/test_data').set(testData);

      debugPrint('✅ Persistent test data written to multiple paths');
      debugPrint('✅ Data: $testData');
      debugPrint(
        '✅ Check Firebase console at: https://console.firebase.google.com/project/safety-app-487c6/database/safety-app-487c6-default-rtdb/data',
      );

      return true;
    } catch (e) {
      debugPrint('❌ Failed to write persistent test data: $e');
      if (e is FirebaseException) {
        debugPrint('❌ Firebase error code: ${e.code}');
        debugPrint('❌ Firebase error message: ${e.message}');
        debugPrint('❌ Firebase error details: ${e.plugin}');
      }
      return false;
    }
  }

  /// Dispose listeners and cleanup
  void dispose() {
    _notificationListener?.cancel();
    for (final listener in _guardianListeners.values) {
      listener.cancel();
    }
    _guardianListeners.clear();
  }

  /// Check for unread notifications count
  Future<int> getUnreadCount() async {
    final userId = await _getCurrentUserId();
    if (userId == null) return 0;

    try {
      final snapshot = await _database.ref('notifications/$userId').get();

      if (!snapshot.exists || snapshot.value == null) return 0;

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      int unreadCount = 0;

      for (final entry in data.values) {
        // Check if the entry is a Map (valid notification object)
        if (entry is! Map) {
          continue;
        }

        final notificationData = Map<String, dynamic>.from(entry);

        // Validate that this looks like a notification object
        if (!_isValidNotificationData(notificationData)) {
          continue;
        }

        // Count only unread notifications
        if (notificationData['isRead'] != true) {
          unreadCount++;
        }
      }

      return unreadCount;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// Validate if data represents a valid notification object
  bool _isValidNotificationData(Map<String, dynamic> data) {
    // Check for required fields that should exist in a notification
    return data.containsKey('message') &&
        data.containsKey('senderId') &&
        data.containsKey('senderName') &&
        data.containsKey('timestamp');
  }
}
