import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/sms_service.dart';
import '../models/emergency_contact.dart';

/// Enhanced Emergency SOS screen with Google Maps integration and auto-trigger.
///
/// Shows the emergency location on a map and provides visual confirmation
/// of SOS trigger location. Features auto-trigger after 10 seconds with
/// option to disable auto-trigger functionality.
class EmergencySOSScreen extends StatefulWidget {
  const EmergencySOSScreen({super.key});

  @override
  State<EmergencySOSScreen> createState() => _EmergencySOSScreenState();
}

class _EmergencySOSScreenState extends State<EmergencySOSScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();

  GoogleMapController? _mapController;
  Timer? _autoTriggerTimer;
  Position? _emergencyLocation;
  String? _emergencyAddress;
  List<EmergencyContact> _contacts = [];
  bool _isLoading = true;
  bool _sosTriggered = false;
  bool _autoTriggerEnabled = true;
  int _countdownSeconds = 10;

  // Map settings
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(37.4219983, -122.084), // Default to Google HQ
    zoom: 16.0,
  );

  @override
  void initState() {
    super.initState();
    _initializeEmergency();
  }

  @override
  void dispose() {
    _autoTriggerTimer?.cancel();
    super.dispose();
  }

  /// Initializes emergency data and location
  Future<void> _initializeEmergency() async {
    try {
      setState(() => _isLoading = true);

      // Get current location
      final position = await _locationService.getCurrentLocation();
      final address = await _locationService.getAddressFromLatLng(
        position.latitude,
        position.longitude,
      );

      // Get emergency contacts
      final contacts = await _databaseService.getEmergencyContacts();

      setState(() {
        _emergencyLocation = position;
        _emergencyAddress = address;
        _contacts = contacts;
        _isLoading = false;
      });

      // Update map camera
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
        );
      }

      // Start auto-trigger countdown if enabled and not already triggered
      if (_autoTriggerEnabled && !_sosTriggered) {
        _startAutoTriggerCountdown();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing emergency: $e')),
        );
      }
    }
  }

  /// Starts the auto-trigger countdown
  void _startAutoTriggerCountdown() {
    _autoTriggerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _countdownSeconds--;
      });

      if (_countdownSeconds <= 0) {
        timer.cancel();
        _triggerSOS(isAutoTriggered: true);
      }
    });
  }

  /// Stops the auto-trigger countdown
  void _stopAutoTriggerCountdown() {
    _autoTriggerTimer?.cancel();
    setState(() {
      _countdownSeconds = 10; // Reset to initial value
    });
  }

  /// Toggles auto-trigger functionality
  void _toggleAutoTrigger() {
    setState(() {
      _autoTriggerEnabled = !_autoTriggerEnabled;
      if (_autoTriggerEnabled && !_sosTriggered) {
        _countdownSeconds = 10;
        _startAutoTriggerCountdown();
      } else {
        _autoTriggerTimer?.cancel();
      }
    });
  }

  /// Triggers the SOS emergency alert
  Future<void> _triggerSOS({bool isAutoTriggered = false}) async {
    if (_emergencyLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available for emergency')),
      );
      return;
    }

    // Cancel auto-trigger timer if manually triggered
    if (!isAutoTriggered) {
      _autoTriggerTimer?.cancel();
    }

    setState(() => _sosTriggered = true);

    try {
      // Start live location sharing
      await _databaseService.startLiveSharing(
        _emergencyLocation!.latitude,
        _emergencyLocation!.longitude,
      );

      // Log emergency in database
      await _databaseService.logEmergency(
        _emergencyLocation!.latitude,
        _emergencyLocation!.longitude,
        _emergencyAddress ?? 'Location not available',
      );

      // Send automatic SMS messages
      await _sendAutomaticSMS();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAutoTriggered
                  ? '🚨 AUTO-TRIGGERED SOS: Emergency contacts notified!'
                  : '🚨 SOS TRIGGERED: Emergency contacts notified!',
            ),
            backgroundColor: Colors.red,
          ),
        );

        // Auto-navigate back after a delay
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      setState(() => _sosTriggered = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error triggering SOS: $e')));
      }
    }
  }

  /// Send automatic SMS messages to emergency contacts
  Future<void> _sendAutomaticSMS() async {
    if (_contacts.isEmpty) {
      debugPrint('No emergency contacts to notify');
      return;
    }

    try {
      // Build SMS message with location
      final mapsUrl =
          'https://maps.google.com/?q=${_emergencyLocation!.latitude},${_emergencyLocation!.longitude}';
      final smsMessage =
          'EMERGENCY! I need help!\n'
          'Location: ${_emergencyAddress ?? 'Location not available'}\n'
          'Google Maps: $mapsUrl\n'
          'Please check on me ASAP.';

      // Extract phone numbers from contacts
      final phoneNumbers = _contacts
          .map((contact) => contact.phoneNumber)
          .toList();

      // Send emergency SMS to all contacts efficiently
      final successCount = await SMSService.sendEmergencySMSBulk(
        phoneNumbers: phoneNumbers,
        message: smsMessage,
      );

      debugPrint(
        'Emergency SMS opened for $successCount/${_contacts.length} contacts',
      );
    } catch (e) {
      debugPrint('Error sending automatic SMS: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
        centerTitle: true,
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparing emergency response...'),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Emergency Status Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _sosTriggered ? Colors.red : Colors.red.shade100,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _sosTriggered ? Icons.warning : Icons.emergency,
                          color: _sosTriggered ? Colors.white : Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _sosTriggered
                              ? '🚨 EMERGENCY ACTIVATED'
                              : 'Ready to Send Emergency Alert',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _sosTriggered ? Colors.white : Colors.red,
                          ),
                        ),
                        if (_sosTriggered) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Contacts notified • Live location sharing started',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ] else if (_autoTriggerEnabled &&
                            _countdownSeconds > 0) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.timer,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Auto-trigger in $_countdownSeconds seconds',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'SOS will trigger automatically unless you disable it',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ] else if (!_autoTriggerEnabled) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_off,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Auto-trigger disabled',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Map showing emergency location
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    height: 250,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GoogleMap(
                        initialCameraPosition: _initialPosition,
                        onMapCreated: (GoogleMapController controller) {
                          _mapController = controller;
                          if (_emergencyLocation != null) {
                            controller.animateCamera(
                              CameraUpdate.newLatLng(
                                LatLng(
                                  _emergencyLocation!.latitude,
                                  _emergencyLocation!.longitude,
                                ),
                              ),
                            );
                          }
                        },
                        markers: _buildMarkers(),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        mapType: MapType.normal,
                        zoomControlsEnabled: true,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Emergency Location Info
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Emergency Location',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_emergencyAddress != null) ...[
                          Text(
                            _emergencyAddress!,
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (_emergencyLocation != null)
                          Text(
                            'Coordinates: ${_emergencyLocation!.latitude.toStringAsFixed(6)}, ${_emergencyLocation!.longitude.toStringAsFixed(6)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Emergency Contacts List
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emergency Contacts (${_contacts.length})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_contacts.isEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              border: Border.all(color: Colors.orange.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'No emergency contacts added yet. Add contacts from the main screen.',
                                    style: TextStyle(
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              itemCount: _contacts.length,
                              itemBuilder: (context, index) {
                                final contact = _contacts[index];
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.red.shade100,
                                      child: Icon(
                                        Icons.person,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                    title: Text(contact.name),
                                    subtitle: Text(contact.phoneNumber),
                                    trailing: Icon(
                                      _sosTriggered
                                          ? Icons.check_circle
                                          : Icons.phone,
                                      color: _sosTriggered
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Auto-trigger control button (only show if not triggered)
                        if (!_sosTriggered) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: _toggleAutoTrigger,
                              icon: Icon(
                                _autoTriggerEnabled
                                    ? Icons.timer_off
                                    : Icons.timer,
                                color: _autoTriggerEnabled
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                              label: Text(
                                _autoTriggerEnabled
                                    ? 'DISABLE AUTO-TRIGGER'
                                    : 'ENABLE AUTO-TRIGGER',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _autoTriggerEnabled
                                      ? Colors.orange
                                      : Colors.green,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: _autoTriggerEnabled
                                      ? Colors.orange
                                      : Colors.green,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // SOS Button
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: _sosTriggered ? null : _triggerSOS,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _sosTriggered
                                  ? Colors.grey
                                  : Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _sosTriggered
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle),
                                      SizedBox(width: 8),
                                      Text(
                                        'SOS ACTIVATED',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.emergency, size: 28),
                                      const SizedBox(width: 8),
                                      Text(
                                        _autoTriggerEnabled &&
                                                _countdownSeconds > 0
                                            ? 'TRIGGER SOS NOW ($_countdownSeconds)'
                                            : 'TRIGGER SOS',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  /// Builds markers for the map
  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // Emergency location marker
    if (_emergencyLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('emergency_location'),
          position: LatLng(
            _emergencyLocation!.latitude,
            _emergencyLocation!.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: '🚨 Emergency Location',
            snippet: _emergencyAddress ?? 'Emergency response location',
          ),
        ),
      );
    }

    return markers;
  }
}
