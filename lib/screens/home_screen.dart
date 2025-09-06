import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import 'contacts_screen.dart';
import 'live_location_screen.dart'; // Updated to use Google Maps version
import 'guardian_dashboard_screen.dart'; // Updated to use Google Maps version
import 'report_unsafe_zone_screen.dart'; // New map-based unsafe zone reporting
import 'emergency_sos_screen.dart'; // New map-based emergency SOS
import 'live_location_test_screen.dart';

/// Main dashboard screen for authenticated users.
///
/// Provides access to emergency features, unsafe zone reporting,
/// and user management functionality.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();

  // Method channel for native power button service
  static const MethodChannel _powerButtonChannel = MethodChannel(
    'power_button_service',
  );

  bool _isSOSLoading = false;
  final bool _isReportingUnsafe = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePowerButtonService();
    _checkForSOSIntent();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPowerButtonService();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForSOSIntent();
    }
  }

  /// Checks if the app was launched with an SOS intent
  Future<void> _checkForSOSIntent() async {
    try {
      // We'll check this through method channel for now since
      // the intent data comes from our native service
      // This is simpler than the full android_intent_plus implementation
      debugPrint('Checking for SOS intent...');
    } catch (e) {
      debugPrint('Error checking intent: $e');
    }
  }

  /// Initializes the power button service and sets up method channel
  Future<void> _initializePowerButtonService() async {
    // Set up method channel listener for power button events
    _powerButtonChannel.setMethodCallHandler(_handleMethodCall);

    try {
      // Start the power button service
      await _powerButtonChannel.invokeMethod('startPowerButtonService');
      debugPrint('Power button service started successfully');
    } catch (e) {
      debugPrint('Failed to start power button service: $e');
    }
  }

  /// Stops the power button service
  Future<void> _stopPowerButtonService() async {
    try {
      await _powerButtonChannel.invokeMethod('stopPowerButtonService');
      debugPrint('Power button service stopped');
    } catch (e) {
      debugPrint('Failed to stop power button service: $e');
    }
  }

  /// Handles method calls from native Android code
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'triggerSOS':
        debugPrint('Power button SOS triggered from native code');
        await _showPowerButtonConfirmationDialog();
        break;
      case 'triggerAutomaticSOS':
        debugPrint(
          'Automatic SOS triggered from native code - starting SOS immediately',
        );
        // Delay slightly to allow the UI to build
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleSOSEmergency(); // Directly call the SOS function!
        });
        break;
      default:
        debugPrint('Unknown method call: ${call.method}');
    }
  }

  /// Shows confirmation dialog for power button SOS trigger
  Future<void> _showPowerButtonConfirmationDialog() async {
    // Prevent multiple triggers if SOS is already in progress
    if (_isSOSLoading) {
      return;
    }

    final bool? shouldSendSOS = await _showSOSConfirmationDialog();

    if (shouldSendSOS == true) {
      await _handleSOSEmergency();
    }
  }

  /// Shows confirmation dialog with countdown timer
  Future<bool?> _showSOSConfirmationDialog() async {
    int countdown = 3;
    bool? result;

    result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Start countdown timer
            if (countdown > 0) {
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted && Navigator.of(context).canPop()) {
                  setState(() {
                    countdown--;
                  });

                  // Auto-send SOS if countdown reaches 0
                  if (countdown == 0) {
                    Navigator.of(context).pop(true);
                  }
                }
              });
            }

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.power_settings_new, color: Colors.red, size: 28),
                  const SizedBox(width: 8),
                  Expanded(child: const Text('Power Button SOS Detected!')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Emergency SOS will be sent automatically!',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Auto-send in: $countdown seconds',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Send SOS Now'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  /// Gets the current user's email for display
  String get _userEmail {
    final user = FirebaseAuth.instance.currentUser;
    return user?.email ?? 'Unknown User';
  }

  /// Handles the SOS emergency button press
  Future<void> _handleSOSEmergency() async {
    // Navigate to the Emergency SOS screen for enhanced visual feedback
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EmergencySOSScreen(),
      ),
    );

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

      // Step 4: Fetch emergency contacts
      final contacts = await _databaseService.getEmergencyContacts();

      // Step 5: Build the alert message
      final mapsUrl =
          'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      final smsMessage =
          'EMERGENCY! I need help!\n'
          'Location: $address\n'
          'Google Maps: $mapsUrl\n'
          'Please check on me ASAP.';

      // Step 6: Send SMS to each contact
      for (final contact in contacts) {
        try {
          final smsUrl = Uri.parse(
            'sms:${contact.phoneNumber}?body=${Uri.encodeComponent(smsMessage)}',
          );
          await launchUrl(smsUrl);
          debugPrint('SMS sent to ${contact.name} (${contact.phoneNumber})');
        } catch (e) {
          debugPrint('Failed to send SMS to ${contact.phoneNumber}: $e');
          // Continue to next contact - don't let SMS failure stop the emergency alert
        }
      }

      // Step 7: Show success message
      if (mounted) {
        final contactCount = contacts.length;
        final contactText = contactCount > 0
            ? ' SMS alerts sent to $contactCount contact${contactCount == 1 ? '' : 's'}.'
            : ' No emergency contacts found to notify.';
        _showSuccessSnackBar(
          '🚨 Emergency alert saved!$contactText Location: $address',
        );
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

  /// Handles reporting an unsafe zone using the new map-based screen
  Future<void> _handleReportUnsafeZone() async {
    // Navigate to the new map-based unsafe zone reporting screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReportUnsafeZoneScreen(),
      ),
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
          'Syntax Safety',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ContactsScreen()),
              );
            },
            icon: const Icon(Icons.contacts),
            tooltip: 'Manage Contacts',
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const LiveLocationTestScreen(),
                ),
              );
            },
            icon: const Icon(Icons.bug_report),
            tooltip: 'Test Live Location',
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
                    const SizedBox(height: 16),
                    // Power Button SOS indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.power_settings_new,
                            size: 18,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Press power button 5 times for quick SOS',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Live Location and Guardian Dashboard Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LiveLocationScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.location_on),
                      label: const Text(
                        'Live Location',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const GuardianDashboardScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.security),
                      label: const Text(
                        'Guardian',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

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
