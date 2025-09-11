import 'package:flutter/material.dart';
import '../services/permission_manager_service.dart';
import 'main_navigation_screen.dart';

/// Screen to handle initial permission requests when the app first opens
///
/// This screen is shown once to request all necessary permissions for the safety app
/// including location, SMS, contacts, notifications, and phone permissions.
class PermissionRequestScreen extends StatefulWidget {
  const PermissionRequestScreen({super.key});

  @override
  State<PermissionRequestScreen> createState() =>
      _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends State<PermissionRequestScreen> {
  final PermissionManagerService _permissionManager =
      PermissionManagerService();
  bool _isChecking = true;
  bool _showRetry = false;
  PermissionResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  /// Check and request all necessary permissions
  Future<void> _checkPermissions() async {
    setState(() {
      _isChecking = true;
      _showRetry = false;
    });

    try {
      final result = await _permissionManager.checkAndRequestAllPermissions(
        context,
      );

      setState(() {
        _lastResult = result;
        _isChecking = false;
        _showRetry = !result.criticalGranted;
      });

      // If critical permissions are granted, proceed to main app
      if (result.criticalGranted) {
        await Future.delayed(
          const Duration(seconds: 1),
        ); // Brief delay to show success
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const MainNavigationScreen(),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isChecking = false;
        _showRetry = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking permissions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),

              // App Logo/Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.security,
                  size: 60,
                  color: Colors.red.shade600,
                ),
              ),

              const SizedBox(height: 32),

              // Title
              const Text(
                'Safety App Permissions',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              const Text(
                'To keep you safe in emergencies, this app needs access to certain features of your device.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Permission List
              _buildPermissionsList(),

              const Spacer(),

              // Action Buttons
              if (_isChecking) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text(
                  'Checking permissions...',
                  style: TextStyle(color: Colors.black54),
                ),
              ] else if (_showRetry) ...[
                ElevatedButton(
                  onPressed: _checkPermissions,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Grant Permissions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const MainNavigationScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Continue without all permissions',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ] else if (_lastResult?.criticalGranted == true) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Permissions granted! Loading app...',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the permissions list UI
  Widget _buildPermissionsList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildPermissionItem(
            Icons.location_on,
            'Location Services',
            'Required for emergency location sharing',
            Colors.red,
            _lastResult?.locationGranted,
          ),
          const SizedBox(height: 16),
          _buildPermissionItem(
            Icons.sms,
            'SMS Messages',
            'Send emergency messages to contacts',
            Colors.blue,
            _lastResult?.smsGranted,
          ),
          const SizedBox(height: 16),
          _buildPermissionItem(
            Icons.contacts,
            'Contacts Access',
            'Import your emergency contacts',
            Colors.green,
            _lastResult?.contactsGranted,
          ),
          const SizedBox(height: 16),
          _buildPermissionItem(
            Icons.notifications,
            'Notifications',
            'Receive emergency alerts',
            Colors.orange,
            _lastResult?.notificationGranted,
          ),
          const SizedBox(height: 16),
          _buildPermissionItem(
            Icons.phone,
            'Phone Calls',
            'Make emergency calls',
            Colors.purple,
            _lastResult?.phoneGranted,
          ),
        ],
      ),
    );
  }

  /// Build individual permission item
  Widget _buildPermissionItem(
    IconData icon,
    String title,
    String description,
    Color color,
    bool? isGranted,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                description,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ),
        if (isGranted != null)
          Icon(
            isGranted ? Icons.check_circle : Icons.cancel,
            color: isGranted ? Colors.green : Colors.red,
            size: 20,
          )
        else
          Icon(Icons.help_outline, color: Colors.grey.shade400, size: 20),
      ],
    );
  }
}
