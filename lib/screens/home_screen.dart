import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';

/// Main dashboard screen for authenticated users.
///
/// Provides access to emergency features, unsafe zone reporting,
/// and user management functionality.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();

  bool _isSOSLoading = false;
  bool _isReportingUnsafe = false;

  /// Gets the current user's email for display
  String get _userEmail {
    final user = FirebaseAuth.instance.currentUser;
    return user?.email ?? 'Unknown User';
  }

  /// Handles the SOS emergency button press
  Future<void> _handleSOSEmergency() async {
    setState(() {
      _isSOSLoading = true;
    });

    try {
      // Step 1: Get current location using LocationService
      final position = await _locationService.getCurrentLocation();

      // Step 2: Convert coordinates to address using LocationService
      final address = await _locationService.getAddressFromLatLng(
        position.latitude,
        position.longitude,
      );

      // Step 3: Log emergency to database
      await _databaseService.logEmergency(
        position.latitude,
        position.longitude,
        address,
      );

      // Step 4: Show success message
      if (mounted) {
        _showSuccessSnackBar('🚨 Emergency alert sent! Location: $address');
      }
    } on LocationServiceException catch (e) {
      // Handle location-specific errors with clear messages
      if (mounted) {
        _showErrorSnackBar(e.message);
      }
    } catch (e) {
      debugPrint('SOS Emergency error: $e');
      if (mounted) {
        String errorMessage = 'Failed to send emergency alert';
        if (e.toString().contains('No authenticated user')) {
          errorMessage = 'Authentication error. Please log in again.';
        }
        _showErrorSnackBar(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSOSLoading = false;
        });
      }
    }
  }

  /// Handles reporting an unsafe zone at current location
  Future<void> _handleReportUnsafeZone() async {
    // First, show dialog to get the reason
    final String? reason = await _showReasonDialog();
    if (reason == null || reason.trim().isEmpty) {
      return; // User cancelled or didn't provide a reason
    }

    setState(() {
      _isReportingUnsafe = true;
    });

    try {
      // Get current location using LocationService
      final position = await _locationService.getCurrentLocation();

      // Report unsafe zone to database
      await _databaseService.reportUnsafeZone(
        position.latitude,
        position.longitude,
        reason.trim(),
      );

      // Show success message
      if (mounted) {
        _showSuccessSnackBar(
          '⚠️ Unsafe zone reported successfully! Thank you for keeping the community safe.',
        );
      }
    } on LocationServiceException catch (e) {
      // Handle location-specific errors with clear messages
      if (mounted) {
        _showErrorSnackBar(e.message);
      }
    } catch (e) {
      debugPrint('Report Unsafe Zone error: $e');
      if (mounted) {
        String errorMessage = 'Failed to report unsafe zone';
        if (e.toString().contains('No authenticated user')) {
          errorMessage = 'Authentication error. Please log in again.';
        }
        _showErrorSnackBar(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isReportingUnsafe = false;
        });
      }
    }
  }

  /// Shows dialog to get the reason for reporting unsafe zone
  Future<String?> _showReasonDialog() async {
    final TextEditingController controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Report Unsafe Zone'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason why this area is unsafe:'),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'e.g., Poor lighting, Recent incidents, etc.',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 200,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = controller.text.trim();
                if (reason.isNotEmpty) {
                  Navigator.of(context).pop(reason);
                }
              },
              child: const Text('Report'),
            ),
          ],
        );
      },
    );
  }

  /// Handles user logout
  Future<void> _handleLogout() async {
    try {
      await AuthService.signOut();
      // Navigation will be handled automatically by AuthWrapper
    } catch (e) {
      _showErrorSnackBar('Failed to sign out: ${e.toString()}');
    }
  }

  /// Shows success message
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Shows error message
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Safety App',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: () {
              // Placeholder for Manage Contacts navigation
              _showErrorSnackBar('Manage Contacts feature coming soon!');
            },
            icon: const Icon(Icons.contacts),
            tooltip: 'Manage Contacts',
          ),
          IconButton(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back!',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _userEmail,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Stay safe and help keep your community secure.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Emergency SOS Button
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Emergency Alert',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                    ),
                    const SizedBox(height: 16),
                    FloatingActionButton.large(
                      onPressed: _isSOSLoading ? null : _handleSOSEmergency,
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      child: _isSOSLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            )
                          : const Icon(Icons.warning, size: 48),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Press for Emergency',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This will send your location to emergency services',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Report Unsafe Zone Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isReportingUnsafe ? null : _handleReportUnsafeZone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isReportingUnsafe
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.report_problem),
                label: Text(
                  _isReportingUnsafe ? 'Reporting...' : 'Report Unsafe Zone',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Additional Info
            Text(
              'Help make your community safer by reporting dangerous areas or requesting immediate assistance.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
