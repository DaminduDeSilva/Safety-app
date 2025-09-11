import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/fake_call_service.dart';
import '../services/sms_service.dart';
import '../services/realtime_notification_service.dart';
import '../services/native_notification_service.dart';
import '../services/permission_manager_service.dart';
import '../models/user_model.dart';
import '../widgets/modern_app_bar.dart';
import '../widgets/notification_alerts_section.dart';
import 'live_location_screen.dart';
import 'report_unsafe_zone_screen.dart';
import 'emergency_sos_screen.dart';

/// Clean and focused home dashboard for the safety app.
///
/// Displays user welcome message, safety status, and quick access
/// to key features like live location and unsafe zone reporting.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();
  final RealtimeNotificationService _realtimeNotificationService =
      RealtimeNotificationService();
  final PermissionManagerService _permissionManager =
      PermissionManagerService();
  UserModel? _userProfile;
  bool _isSOSLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _initializeNotificationServices();
    _checkAndForceLocation();
  }

  /// Check and force location to be enabled
  Future<void> _checkAndForceLocation() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final isLocationEnabled = await _permissionManager.isLocationEnabled();
      if (!isLocationEnabled && mounted) {
        await _permissionManager.forceLocationEnable(context);
      }
    });
  }

  /// Initialize notification services
  Future<void> _initializeNotificationServices() async {
    try {
      // Initialize realtime notification service
      await _realtimeNotificationService.initialize();

      // Test database connection
      // await _realtimeNotificationService.testDatabaseConnection();

      // Get current user ID and start background notification service
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid;
      await NativeNotificationService.startBackgroundService(userId: userId);

      debugPrint(
        'Notification services initialized successfully for user: $userId',
      );
    } catch (e) {
      debugPrint('Error initializing notification services: $e');
    }
  }

  /// Loads the current user's profile information
  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = await _databaseService.getUserProfile(user.uid);
        setState(() {
          _userProfile = profile;
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  /// Triggers a quick fake call for emergency situations
  Future<void> _triggerQuickFakeCall() async {
    try {
      // Create an emergency fake call configuration
      final emergencyCall = FakeCallService.instance.createEmergencyFakeCall();

      // Show a brief confirmation dialog
      final shouldTrigger = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Quick Fake Call'),
          content: Text(
            'This will immediately trigger a fake call from "${emergencyCall.callerName}".\n\nProceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Start Call'),
            ),
          ],
        ),
      );

      if (shouldTrigger == true) {
        await FakeCallService.instance.triggerImmediateFakeCall(
          context,
          emergencyCall,
        );
      }
    } catch (e) {
      debugPrint('Error triggering fake call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to trigger fake call'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(
        title: 'Safety Dashboard',
        automaticallyImplyLeading: false,
      ),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome Section
            _buildWelcomeSection(),

            // Notification Alerts Section
            NotificationAlertsSection(),

            const SizedBox(height: 20),

            // Emergency SOS Button Section
            _buildEmergencySOSSection(),

            const SizedBox(height: 24),

            // Safety Status Card
            _buildSafetyStatusCard(),

            const SizedBox(height: 24),

            // Quick Actions Section
            _buildQuickActionsSection(),

            const SizedBox(height: 24),

            // Recent Activity Card (placeholder for future implementation)
            _buildRecentActivityCard(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _triggerQuickFakeCall,
        backgroundColor: Colors.green[600],
        icon: const Icon(Icons.phone_in_talk, color: Colors.white),
        label: const Text(
          'Quick Call',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        tooltip: 'Trigger emergency fake call',
      ),
    );
  }

  /// Builds the welcome section with user greeting
  Widget _buildWelcomeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    _userProfile?.username.substring(0, 1).toUpperCase() ?? 'U',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back, ${_userProfile?.username ?? 'User'}!',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Stay safe and connected',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the safety status card
  Widget _buildSafetyStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.green[600], size: 28),
                const SizedBox(width: 12),
                Text(
                  'Safety Status',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'All systems operational',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Your location services are active and guardians can see your status.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the quick actions section
  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.location_on,
                title: 'Share Location',
                subtitle: 'Real-time tracking',
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LiveLocationScreen(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _buildActionCard(
                icon: Icons.warning,
                title: 'Report Zone',
                subtitle: 'Mark unsafe area',
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReportUnsafeZoneScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Second row with fake call features
        // Row(
        //   children: [
        //     Expanded(
        //       child: _buildActionCard(
        //         icon: Icons.phone_in_talk,
        //         title: 'Quick Call',
        //         subtitle: 'Emergency fake call',
        //         color: Colors.green,
        //         onTap: () {
        //           Navigator.push(
        //             context,
        //             MaterialPageRoute(
        //               builder: (context) => FakeCallScreen(
        //                 config: FakeCallTemplates.defaultTemplates.first,
        //               ),
        //             ),
        //           );
        //         },
        //       ),
        //     ),

        //     // const SizedBox(width: 12),

        //     // Expanded(
        //     //   child: _buildActionCard(
        //     //     icon: Icons.settings_phone,
        //     //     title: 'Call Settings',
        //     //     subtitle: 'Configure fake calls',
        //     //     color: Colors.purple,
        //     //     onTap: () {
        //     //       Navigator.push(
        //     //         context,
        //     //         MaterialPageRoute(
        //     //           builder: (context) => FakeCallScreen(
        //     //             config: FakeCallTemplates.defaultTemplates.first,
        //     //           ),
        //     //         ),
        //     //       );
        //     //     },
        //     //   ),
        //     // ),
        //   ],
        // ),

        // const SizedBox(height: 12),

        // Third row with notification testing
        // Row(
        //   children: [
        //     Expanded(
        //       child: _buildActionCard(
        //         icon: Icons.notification_add,
        //         title: 'Test Notification',
        //         subtitle: 'Test database connection',
        //         color: Colors.red,
        //         onTap: _testNotificationSend,
        //       ),
        //     ),

        //     const SizedBox(width: 12),

        //     Expanded(
        //       child: Container(), // Empty space for symmetry
        //     ),
        //   ],
        // ),
      ],
    );
  }

  /// Builds an action card for quick access features
  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the recent activity card (placeholder)
  Widget _buildRecentActivityCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: Colors.blue[600]),
                const SizedBox(width: 8),
                Text(
                  'Recent Activity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Icon(Icons.timeline, color: Colors.grey[400], size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'No recent activity',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your activity timeline will appear here',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
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

  /// Builds the emergency SOS section
  Widget _buildEmergencySOSSection() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[600]!, Colors.red[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSOSLoading ? null : _handleSOSEmergency,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSOSLoading) ...[
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ] else ...[
                      const Icon(
                        Icons.warning_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                    ],
                    const Text(
                      'EMERGENCY SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _isSOSLoading
                      ? 'Sending emergency alert...'
                      : 'Tap to alert guardians & emergency services',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '🚨 Only use in real emergencies',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Handles the SOS emergency button press
  Future<void> _handleSOSEmergency() async {
    // Navigate to the Emergency SOS screen for enhanced visual feedback
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EmergencySOSScreen()),
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

      // Step 6: Send automatic SMS to contacts with phone numbers
      final phoneNumbers = contacts
          .map((contact) => contact.phoneNumber)
          .where((phone) => phone.isNotEmpty && phone != 'N/A')
          .toList();
      int smsSuccessCount = 0;

      try {
        smsSuccessCount = await SMSService.sendEmergencySMSBulk(
          phoneNumbers: phoneNumbers,
          message: smsMessage,
        );
        debugPrint(
          'Emergency SMS sent to $smsSuccessCount/${phoneNumbers.length} phone contacts',
        );
      } catch (e) {
        debugPrint('Failed to send emergency SMS: $e');
      }

      // Step 7: Send real-time notifications to app-connected contacts
      int notificationSuccessCount = 0;
      final appContacts = contacts
          .where(
            (contact) =>
                contact.contactId != null && contact.contactId!.isNotEmpty,
          )
          .toList();

      for (final contact in appContacts) {
        try {
          final success = await _realtimeNotificationService
              .sendNotificationToGuardian(
                guardianId: contact.contactId!,
                message: '🚨 EMERGENCY ALERT: I need help! Location: $address',
                type: 'emergency',
                metadata: {
                  'latitude': position.latitude,
                  'longitude': position.longitude,
                  'address': address,
                  'mapsUrl': mapsUrl,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                },
              );
          if (success) notificationSuccessCount++;
        } catch (e) {
          debugPrint(
            'Failed to send emergency notification to ${contact.name}: $e',
          );
        }
      }

      debugPrint(
        'Emergency notifications sent to $notificationSuccessCount/${appContacts.length} app contacts',
      );

      // Step 7: Make emergency call
      // final Uri emergencyCall = Uri(scheme: 'tel', path: '911');
      // if (await canLaunchUrl(emergencyCall)) {
      //   await launchUrl(emergencyCall);
      // }

      if (mounted) {
        final totalContacts = contacts.length;
        final smsContacts = phoneNumbers.length;
        final appContactsCount = appContacts.length;

        String alertText = '🚨 Emergency alert activated!';
        if (smsContacts > 0) {
          alertText += '\n📱 SMS: $smsSuccessCount/$smsContacts sent';
        }
        if (appContactsCount > 0) {
          alertText +=
              '\n🔔 App notifications: $notificationSuccessCount/$appContactsCount sent';
        }
        if (totalContacts == 0) {
          alertText += '\n⚠️ No emergency contacts found to notify.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(alertText),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to send emergency alert';
        if (e.toString().contains('No authenticated user')) {
          errorMessage = 'Authentication error. Please log in again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSOSLoading = false;
        });
      }
    }
  }

  /// Test notification sending functionality
  // Future<void> _testNotificationSend() async {
  //   try {
  //     final user = FirebaseAuth.instance.currentUser;
  //     if (user == null) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('Not logged in! Please authenticate first.'),
  //           backgroundColor: Colors.orange,
  //         ),
  //       );
  //       return;
  //     }

  //     // Show loading indicator
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('🔄 Testing full notification system...'),
  //         backgroundColor: Colors.blue,
  //         duration: Duration(seconds: 2),
  //       ),
  //     );

  //     // Test 1: Write persistent test data
  //     await _realtimeNotificationService.writePersistentTestData();

  //     // Test 2: Send notification to self (tests both foreground and background listeners)
  //     final notificationSuccess = await _realtimeNotificationService
  //         .sendNotificationToGuardian(
  //           guardianId: user.uid, // Send to self
  //           message:
  //               '🧪 Test notification sent at ${DateTime.now()}. This tests both Flutter and Kotlin listeners!',
  //           type: 'test',
  //           metadata: {
  //             'test_type': 'full_system_test',
  //             'sent_from': 'flutter_app',
  //             'timestamp': DateTime.now().millisecondsSinceEpoch,
  //           },
  //         );

  //     final success = notificationSuccess;

  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(
  //             success
  //                 ? '✅ Full notification system test completed!\n• Data written to Firebase\n• Self-notification sent\n• Check logs for Flutter & Kotlin listeners'
  //                 : '❌ Notification system test failed. Check logs for details.',
  //           ),
  //           backgroundColor: success ? Colors.green : Colors.red,
  //           duration: const Duration(seconds: 6),
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     debugPrint('Error in test notification: $e');
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('❌ Error in test: ${e.toString()}'),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //   }
  // }
}
