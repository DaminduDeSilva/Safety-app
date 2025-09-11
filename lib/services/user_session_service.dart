import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service to manage user session data with secure storage
///
/// This service handles storing and retrieving user information securely
/// including user ID for Firebase Realtime Database listeners and other
/// persistent user data that should survive app restarts and even logout.
class UserSessionService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static final UserSessionService _instance = UserSessionService._internal();
  factory UserSessionService() => _instance;
  UserSessionService._internal();

  // Storage keys
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserName = 'user_name';
  static const String _keyLastLoginTime = 'last_login_time';
  static const String _keyNotificationToken = 'notification_token';
  static const String _keyPermissionsGranted = 'permissions_granted';

  /// Save user session data when user logs in
  Future<void> saveUserSession({
    required String userId,
    required String email,
    String? displayName,
  }) async {
    try {
      await Future.wait([
        _storage.write(key: _keyUserId, value: userId),
        _storage.write(key: _keyUserEmail, value: email),
        if (displayName != null)
          _storage.write(key: _keyUserName, value: displayName),
        _storage.write(
          key: _keyLastLoginTime,
          value: DateTime.now().millisecondsSinceEpoch.toString(),
        ),
      ]);

      debugPrint('User session saved securely for user: $userId');
    } catch (e) {
      debugPrint('Error saving user session: $e');
    }
  }

  /// Update user session when Firebase Auth state changes
  Future<void> updateFromFirebaseUser(User? user) async {
    if (user != null) {
      await saveUserSession(
        userId: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
      );
    }
  }

  /// Get stored user ID (persists even after logout)
  Future<String?> getStoredUserId() async {
    try {
      return await _storage.read(key: _keyUserId);
    } catch (e) {
      debugPrint('Error getting stored user ID: $e');
      return null;
    }
  }

  /// Get stored user email
  Future<String?> getStoredUserEmail() async {
    try {
      return await _storage.read(key: _keyUserEmail);
    } catch (e) {
      debugPrint('Error getting stored user email: $e');
      return null;
    }
  }

  /// Get stored user name
  Future<String?> getStoredUserName() async {
    try {
      return await _storage.read(key: _keyUserName);
    } catch (e) {
      debugPrint('Error getting stored user name: $e');
      return null;
    }
  }

  /// Get last login time
  Future<DateTime?> getLastLoginTime() async {
    try {
      final timeString = await _storage.read(key: _keyLastLoginTime);
      if (timeString != null) {
        return DateTime.fromMillisecondsSinceEpoch(int.parse(timeString));
      }
      return null;
    } catch (e) {
      debugPrint('Error getting last login time: $e');
      return null;
    }
  }

  /// Save notification token
  Future<void> saveNotificationToken(String token) async {
    try {
      await _storage.write(key: _keyNotificationToken, value: token);
    } catch (e) {
      debugPrint('Error saving notification token: $e');
    }
  }

  /// Get notification token
  Future<String?> getNotificationToken() async {
    try {
      return await _storage.read(key: _keyNotificationToken);
    } catch (e) {
      debugPrint('Error getting notification token: $e');
      return null;
    }
  }

  /// Save permissions status
  Future<void> savePermissionsStatus(Map<String, bool> permissions) async {
    try {
      final permissionsJson = permissions.entries
          .map((e) => '${e.key}:${e.value}')
          .join(',');
      await _storage.write(key: _keyPermissionsGranted, value: permissionsJson);
    } catch (e) {
      debugPrint('Error saving permissions status: $e');
    }
  }

  /// Get permissions status
  Future<Map<String, bool>> getPermissionsStatus() async {
    try {
      final permissionsString = await _storage.read(
        key: _keyPermissionsGranted,
      );
      if (permissionsString != null && permissionsString.isNotEmpty) {
        final permissions = <String, bool>{};
        for (final entry in permissionsString.split(',')) {
          final parts = entry.split(':');
          if (parts.length == 2) {
            permissions[parts[0]] = parts[1].toLowerCase() == 'true';
          }
        }
        return permissions;
      }
      return {};
    } catch (e) {
      debugPrint('Error getting permissions status: $e');
      return {};
    }
  }

  /// Clear only authentication-related data (keep user ID and permissions)
  Future<void> clearAuthData() async {
    try {
      // Don't delete user ID and permissions - keep them for notifications
      await Future.wait([
        _storage.delete(key: _keyUserEmail),
        _storage.delete(key: _keyUserName),
        _storage.delete(key: _keyNotificationToken),
      ]);

      debugPrint('Auth data cleared (user ID and permissions preserved)');
    } catch (e) {
      debugPrint('Error clearing auth data: $e');
    }
  }

  /// Clear all stored data (use only when completely removing user data)
  Future<void> clearAllData() async {
    try {
      await _storage.deleteAll();
      debugPrint('All secure storage data cleared');
    } catch (e) {
      debugPrint('Error clearing all data: $e');
    }
  }

  /// Check if user has valid session data
  Future<bool> hasValidSession() async {
    final userId = await getStoredUserId();
    final email = await getStoredUserEmail();
    return userId != null && email != null;
  }

  /// Get current user ID (from Firebase Auth or secure storage)
  Future<String?> getCurrentUserId() async {
    // First try to get from current Firebase Auth user
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      return currentUser.uid;
    }

    // Fall back to stored user ID
    return await getStoredUserId();
  }
}
