import 'dart:async';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/live_location.dart';
import '../models/emergency_contact.dart';

/// Safe Dashboard for guardians to view live location sharing from their contacts.
///
/// Shows real-time location updates from contacts in a text-based format
/// without requiring Google Maps integration.
class GuardianDashboardSafeScreen extends StatefulWidget {
  const GuardianDashboardSafeScreen({super.key});

  @override
  State<GuardianDashboardSafeScreen> createState() =>
      _GuardianDashboardSafeScreenState();
}

class _GuardianDashboardSafeScreenState
    extends State<GuardianDashboardSafeScreen> {
  final DatabaseService _databaseService = DatabaseService();

  List<EmergencyContact> _contacts = [];
  final Map<String, LiveLocation?> _liveLocations = {};
  final Map<String, StreamSubscription> _locationStreams = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContactsAndStartStreams();
  }

  @override
  void dispose() {
    _stopAllStreams();
    super.dispose();
  }

  /// Loads emergency contacts and starts listening to their live locations
  Future<void> _loadContactsAndStartStreams() async {
    try {
      setState(() => _isLoading = true);

      final contacts = await _databaseService.getEmergencyContacts();

      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });

      // Start listening to live locations for each contact
      for (final contact in contacts) {
        _startLocationStream(contact);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading contacts: $e')));
      }
    }
  }

  /// Starts listening to live location for a specific contact
  void _startLocationStream(EmergencyContact contact) {
    final stream = _databaseService.getLiveLocationStream(contact.phoneNumber);

    _locationStreams[contact.phoneNumber] = stream.listen(
      (liveLocation) {
        if (mounted) {
          setState(() {
            _liveLocations[contact.phoneNumber] = liveLocation;
          });
        }
      },
      onError: (error) {
        debugPrint('Error in location stream for ${contact.name}: $error');
      },
    );
  }

  /// Stops all location streams
  void _stopAllStreams() {
    for (final subscription in _locationStreams.values) {
      subscription.cancel();
    }
    _locationStreams.clear();
  }

  /// Gets the contact for a given phone number
  EmergencyContact? _getContactByPhoneNumber(String phoneNumber) {
    try {
      return _contacts.firstWhere(
        (contact) => contact.phoneNumber == phoneNumber,
      );
    } catch (e) {
      return null;
    }
  }

  /// Formats time ago from timestamp
  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  /// Formats coordinates for display
  String _formatCoordinates(LiveLocation location) {
    return '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
  }

  /// Opens location in external maps app
  void _openInMaps(LiveLocation location) {
    final url =
        'https://maps.google.com/?q=${location.latitude},${location.longitude}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Maps URL: $url'),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () {
            // Could implement clipboard copy here
          },
        ),
      ),
    );
  }

  /// Builds a contact card with location information
  Widget _buildContactCard(EmergencyContact contact) {
    final liveLocation = _liveLocations[contact.phoneNumber];
    final isActive = liveLocation?.status == 'active';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isActive ? Colors.green : Colors.grey,
                  radius: 24,
                  child: Text(
                    contact.name.isNotEmpty
                        ? contact.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        contact.phoneNumber,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'OFFLINE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            if (isActive && liveLocation != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Location Information
              Row(
                children: [
                  Icon(Icons.location_on, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Live Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildLocationDetail(
                'Address',
                liveLocation.address ?? 'Unknown location',
              ),
              const SizedBox(height: 8),
              _buildLocationDetail(
                'Coordinates',
                _formatCoordinates(liveLocation),
              ),
              const SizedBox(height: 8),
              _buildLocationDetail(
                'Last Updated',
                _formatTimeAgo(liveLocation.timestamp),
              ),

              const SizedBox(height: 12),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openInMaps(liveLocation),
                      icon: const Icon(Icons.map, size: 16),
                      label: const Text('View in Maps'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_off, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Not currently sharing location',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDetail(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeSharings = _liveLocations.values
        .where((loc) => loc != null && loc.status == 'active')
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian Dashboard'),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadContactsAndStartStreams,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Status Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: activeSharings > 0
                        ? Colors.green.shade50
                        : Colors.grey.shade50,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monitoring Dashboard',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            '$activeSharings of ${_contacts.length} contacts sharing location',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: activeSharings > 0
                              ? Colors.green
                              : Colors.grey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          activeSharings > 0 ? 'MONITORING' : 'IDLE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Contact List
                Expanded(
                  child: _contacts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.contacts,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Emergency Contacts',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add emergency contacts to monitor their locations',
                                style: TextStyle(color: Colors.grey.shade500),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _contacts.length,
                          itemBuilder: (context, index) {
                            return _buildContactCard(_contacts[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
