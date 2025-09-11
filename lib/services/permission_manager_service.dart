import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'user_session_service.dart';

/// Comprehensive permission management service
///
/// This service handles all permission requests needed for the safety app:
/// - Location services (GPS)
/// - SMS/Phone permissions
/// - Contacts access
/// - Notifications
/// - Phone calls
class PermissionManagerService {
  static final PermissionManagerService _instance =
      PermissionManagerService._internal();
  factory PermissionManagerService() => _instance;
  PermissionManagerService._internal();

  final UserSessionService _sessionService = UserSessionService();

  /// Required permissions for the app
  static final Map<Permission, String> _requiredPermissions = {
    Permission.location: 'Location access is required for emergency services',
    Permission.locationWhenInUse:
        'Location access is required for emergency services',
    Permission.sms: 'SMS permission is required to send emergency messages',
    Permission.phone: 'Phone permission is required for emergency calls',
    Permission.contacts:
        'Contacts access is required to import emergency contacts',
    Permission.notification: 'Notifications are required for emergency alerts',
  };

  /// Check and request all necessary permissions on app startup
  Future<PermissionResult> checkAndRequestAllPermissions(
    BuildContext context,
  ) async {
    try {
      final result = PermissionResult();

      // Check location services first (critical for safety app)
      final locationResult = await _checkAndRequestLocationServices(context);
      result.locationGranted = locationResult;

      if (!locationResult) {
        result.criticalPermissionsDenied = true;
      }

      // Check other permissions
      final permissionResults = <Permission, bool>{};

      for (final permission in _requiredPermissions.keys) {
        if (permission == Permission.location ||
            permission == Permission.locationWhenInUse) {
          // Already handled location above
          continue;
        }

        final isGranted = await _checkAndRequestSinglePermission(
          permission,
          context,
        );
        permissionResults[permission] = isGranted;

        // Update result object
        switch (permission) {
          case Permission.sms:
            result.smsGranted = isGranted;
            break;
          case Permission.phone:
            result.phoneGranted = isGranted;
            break;
          case Permission.contacts:
            result.contactsGranted = isGranted;
            break;
          case Permission.notification:
            result.notificationGranted = isGranted;
            break;
          default:
            break;
        }
      }

      // Save permission status
      await _savePermissionStatus(permissionResults, result.locationGranted);

      // Show summary if any permissions denied
      if (!result.allGranted) {
        await _showPermissionSummary(context, result);
      }

      return result;
    } catch (e) {
      debugPrint('Error checking permissions: $e');
      return PermissionResult();
    }
  }

  /// Check and request location services with GPS enabling
  Future<bool> _checkAndRequestLocationServices(BuildContext context) async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        final shouldEnable = await _showLocationServiceDialog(context);
        if (shouldEnable) {
          // Try to open location settings
          await Geolocator.openLocationSettings();

          // Wait a bit and check again
          await Future.delayed(const Duration(seconds: 2));
          serviceEnabled = await Geolocator.isLocationServiceEnabled();
        }

        if (!serviceEnabled) {
          return false;
        }
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        await _showLocationPermissionDeniedDialog(context);
        return false;
      }

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      debugPrint('Error checking location services: $e');
      return false;
    }
  }

  /// Check and request a single permission
  Future<bool> _checkAndRequestSinglePermission(
    Permission permission,
    BuildContext context,
  ) async {
    try {
      final status = await permission.status;

      if (status.isGranted) {
        return true;
      }

      if (status.isDenied) {
        final requestResult = await permission.request();
        return requestResult.isGranted;
      }

      if (status.isPermanentlyDenied) {
        await _showPermissionDeniedDialog(context, permission);
        return false;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking permission $permission: $e');
      return false;
    }
  }

  /// Show location service enable dialog
  Future<bool> _showLocationServiceDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.red),
            SizedBox(width: 8),
            Text('Location Required'),
          ],
        ),
        content: const Text(
          'This safety app requires location services to function properly for emergency situations. '
          'Please enable location services to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Enable Location',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Show location permission denied dialog
  Future<void> _showLocationPermissionDeniedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Location Permission Denied'),
          ],
        ),
        content: const Text(
          'Location permission has been permanently denied. Please enable it in app settings '
          'for emergency features to work properly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Show permission denied dialog for other permissions
  Future<void> _showPermissionDeniedDialog(
    BuildContext context,
    Permission permission,
  ) async {
    final reason =
        _requiredPermissions[permission] ??
        'This permission is required for app functionality';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Permission Denied'),
          ],
        ),
        content: Text(
          'Permission has been denied permanently.\n\n$reason\n\n'
          'Please enable it in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Show permission summary dialog
  Future<void> _showPermissionSummary(
    BuildContext context,
    PermissionResult result,
  ) async {
    final deniedPermissions = <String>[];

    if (!result.locationGranted) deniedPermissions.add('Location');
    if (!result.smsGranted) deniedPermissions.add('SMS');
    if (!result.phoneGranted) deniedPermissions.add('Phone');
    if (!result.contactsGranted) deniedPermissions.add('Contacts');
    if (!result.notificationGranted) deniedPermissions.add('Notifications');

    if (deniedPermissions.isEmpty) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.criticalPermissionsDenied ? Icons.error : Icons.warning,
              color: result.criticalPermissionsDenied
                  ? Colors.red
                  : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('Permissions Summary'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.criticalPermissionsDenied)
              const Text(
                'Critical permissions were denied. The app may not function properly for emergency situations.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              const Text(
                'Some optional permissions were denied. You can enable them later in settings.',
              ),
            const SizedBox(height: 16),
            const Text('Denied permissions:'),
            const SizedBox(height: 8),
            ...deniedPermissions.map(
              (permission) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.close, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Text(permission),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (!result.criticalPermissionsDenied)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (result.criticalPermissionsDenied) {
                openAppSettings();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: result.criticalPermissionsDenied
                  ? Colors.red
                  : Colors.blue,
            ),
            child: Text(
              result.criticalPermissionsDenied
                  ? 'Open Settings'
                  : 'Open Settings (Optional)',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Save permission status to secure storage
  Future<void> _savePermissionStatus(
    Map<Permission, bool> permissions,
    bool locationGranted,
  ) async {
    final permissionMap = <String, bool>{'location': locationGranted};

    for (final entry in permissions.entries) {
      permissionMap[entry.key.toString().split('.').last] = entry.value;
    }

    await _sessionService.savePermissionsStatus(permissionMap);
  }

  /// Quick check if location is enabled (for runtime checks)
  Future<bool> isLocationEnabled() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      debugPrint('Error checking location status: $e');
      return false;
    }
  }

  /// Force location enable with dialog
  Future<bool> forceLocationEnable(BuildContext context) async {
    final isEnabled = await isLocationEnabled();
    if (isEnabled) return true;

    return await _checkAndRequestLocationServices(context);
  }
}

/// Result class for permission checks
class PermissionResult {
  bool locationGranted = false;
  bool smsGranted = false;
  bool phoneGranted = false;
  bool contactsGranted = false;
  bool notificationGranted = false;
  bool criticalPermissionsDenied = false;

  /// Check if all permissions are granted
  bool get allGranted =>
      locationGranted &&
      smsGranted &&
      phoneGranted &&
      contactsGranted &&
      notificationGranted;

  /// Check if critical permissions are granted (location)
  bool get criticalGranted => locationGranted;
}
