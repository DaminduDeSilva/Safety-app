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
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Syntax Safety'),
        centerTitle: true,
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(2, 2),
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 0,
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ContactsScreen()),
                );
              },
              icon: const Icon(Icons.contacts, color: Color(0xFF2563EB)),
              tooltip: 'Emergency Contacts',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(2, 2),
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 0,
                ),
              ],
            ),
            child: IconButton(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout, color: Color(0xFFF97316)),
              tooltip: 'Sign Out',
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withOpacity(0.1), width: 2),
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(6, 6),
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              offset: const Offset(2, 2),
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shield_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'You\'re Safe',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _userEmail,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.power_settings_new,
                          size: 20,
                          color: const Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Press power button 5 times for quick SOS',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Emergency SOS Section
            const Text(
              'Emergency Response',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 16),
            
            Center(
              child: Column(
                children: [
                  SOSButton(
                    onPressed: _isSOSLoading ? null : _handleSOSEmergency,
                    isLoading: _isSOSLoading,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Emergency SOS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Instantly alert emergency contacts\nwith your current location',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 16),

            // Action Cards Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                ActionCard(
                  title: 'Live Location',
                  icon: Icons.location_on_rounded,
                  color: const Color(0xFF2563EB),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LiveLocationScreen(),
                      ),
                    );
                  },
                ),
                ActionCard(
                  title: 'Guardian Dashboard',
                  icon: Icons.security_rounded,
                  color: const Color(0xFF10B981),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GuardianDashboardScreen(),
                      ),
                    );
                  },
                ),
                ActionCard(
                  title: 'Report Unsafe Zone',
                  icon: Icons.report_problem_rounded,
                  color: const Color(0xFFF97316),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReportUnsafeZoneScreen(),
                      ),
                    );
                  },
                  isLoading: _isReportingUnsafe,
                ),
                ActionCard(
                  title: 'Emergency Contacts',
                  icon: Icons.contacts_rounded,
                  color: const Color(0xFF8B5CF6),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ContactsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Bottom Info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: const Color(0xFF6B7280),
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Help make your community safer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Report dangerous areas and stay connected with your emergency contacts for maximum safety.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
