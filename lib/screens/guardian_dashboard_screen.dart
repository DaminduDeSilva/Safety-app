import 'dart:async';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/live_location.dart';
import '../models/emergency_contact.dart';

/// Dashboard for guardians to view live location sharing from their contacts.
///
/// Shows real-time location updates from contacts who are sharing their location.
/// Displays contact information in a clean list format without requiring Google Maps.
class GuardianDashboardScreen extends StatefulWidget {
  const GuardianDashboardScreen({super.key});

  @override
  State<GuardianDashboardScreen> createState() =>
      _GuardianDashboardScreenState();
}

class _GuardianDashboardScreenState extends State<GuardianDashboardScreen> {
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
    // Use the contact's phone number as identifier since EmergencyContact doesn't have userId
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

  /// Shows detailed location information in a dialog
  void _showLocationDetails(
    BuildContext context,
    EmergencyContact contact,
    LiveLocation liveLocation,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${contact.name}\'s Location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                Icons.location_on,
                'Address',
                liveLocation.address ?? 'Unknown location',
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.gps_fixed,
                'Coordinates',
                '${liveLocation.latitude.toStringAsFixed(6)}, ${liveLocation.longitude.toStringAsFixed(6)}',
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.access_time,
                'Last Updated',
                _formatTimeAgo(liveLocation.timestamp),
              ),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.signal_cellular_alt,
                'Status',
                liveLocation.status.toUpperCase(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                // Open in external maps app
                final mapsUrl =
                    'https://maps.google.com/?q=${liveLocation.latitude},${liveLocation.longitude}';
                // You could use url_launcher here to open the URL
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Maps URL: $mapsUrl'),
                    action: SnackBarAction(
                      label: 'Copy',
                      onPressed: () {
                        // Could implement clipboard copy here
                      },
                    ),
                  ),
                );
              },
              child: const Text('View in Maps'),
            ),
          ],
        );
      },
    );
  }

  /// Builds a detail row for the location dialog
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
                            'Active Locations',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            '$activeSharings of ${_contacts.length} contacts',
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

                // Contact List (Full Space)
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
                                'Add emergency contacts from the main screen\nto monitor their live locations here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: _contacts.length,
                          itemBuilder: (context, index) {
                            final contact = _contacts[index];
                            final liveLocation =
                                _liveLocations[contact.phoneNumber];
                            final isActive = liveLocation?.status == 'active';

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isActive
                                      ? Colors.green
                                      : Colors.grey,
                                  child: Text(
                                    contact.name.isNotEmpty
                                        ? contact.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  contact.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: isActive
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.location_on,
                                                size: 16,
                                                color: Colors.green,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  liveLocation!.address ??
                                                      'Unknown location',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Updated: ${_formatTimeAgo(liveLocation.timestamp)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.gps_fixed,
                                                size: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${liveLocation.latitude.toStringAsFixed(6)}, ${liveLocation.longitude.toStringAsFixed(6)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.location_off,
                                                size: 16,
                                                color: Colors.grey.shade400,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Not sharing location',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isActive
                                          ? Icons.location_on
                                          : Icons.location_off,
                                      color: isActive
                                          ? Colors.green
                                          : Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isActive ? 'LIVE' : 'OFFLINE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isActive
                                            ? Colors.green
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: isActive
                                    ? () {
                                        // Show detailed location info
                                        _showLocationDetails(
                                          context,
                                          contact,
                                          liveLocation!,
                                        );
                                      }
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
