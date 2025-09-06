import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/database_service.dart';
import '../models/live_location.dart';
import '../models/emergency_contact.dart';

/// Dashboard for guardians to view live location sharing from their contacts.
///
/// Shows real-time location updates from contacts who are sharing their location.
/// Displays multiple contacts on a map with their current positions and status.
class GuardianDashboardScreen extends StatefulWidget {
  const GuardianDashboardScreen({super.key});

  @override
  State<GuardianDashboardScreen> createState() =>
      _GuardianDashboardScreenState();
}

class _GuardianDashboardScreenState extends State<GuardianDashboardScreen> {
  final DatabaseService _databaseService = DatabaseService();

  GoogleMapController? _mapController;
  List<EmergencyContact> _contacts = [];
  final Map<String, LiveLocation?> _liveLocations = {};
  final Map<String, StreamSubscription> _locationStreams = {};
  bool _isLoading = true;

  // Map settings
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(37.4219983, -122.084), // Default center
    zoom: 12.0,
  );

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
          _updateMapView();
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

  /// Updates map view to show all active locations
  void _updateMapView() {
    if (_mapController == null) return;

    final activeLocs = _liveLocations.values
        .where((loc) => loc != null && loc.status == 'active')
        .cast<LiveLocation>()
        .toList();

    if (activeLocs.isEmpty) return;

    // Calculate bounds to show all active locations
    if (activeLocs.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(activeLocs.first.latitude, activeLocs.first.longitude),
          14.0,
        ),
      );
    } else {
      double minLat = activeLocs.first.latitude;
      double maxLat = activeLocs.first.latitude;
      double minLng = activeLocs.first.longitude;
      double maxLng = activeLocs.first.longitude;

      for (final loc in activeLocs) {
        minLat = minLat < loc.latitude ? minLat : loc.latitude;
        maxLat = maxLat > loc.latitude ? maxLat : loc.latitude;
        minLng = minLng < loc.longitude ? minLng : loc.longitude;
        maxLng = maxLng > loc.longitude ? maxLng : loc.longitude;
      }

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          100.0, // padding
        ),
      );
    }
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

  /// Builds markers for the map
  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    for (final entry in _liveLocations.entries) {
      final phoneNumber = entry.key;
      final liveLocation = entry.value;

      if (liveLocation == null || liveLocation.status != 'active') continue;

      final contact = _getContactByPhoneNumber(phoneNumber);
      if (contact == null) continue;

      markers.add(
        Marker(
          markerId: MarkerId(phoneNumber),
          position: LatLng(liveLocation.latitude, liveLocation.longitude),
          infoWindow: InfoWindow(
            title: contact.name,
            snippet:
                '${liveLocation.address ?? 'Unknown location'}\n'
                'Updated: ${_formatTimeAgo(liveLocation.timestamp)}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }

    return markers;
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

                // Map
                Expanded(
                  flex: 3,
                  child: GoogleMap(
                    initialCameraPosition: _initialPosition,
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                      _updateMapView();
                    },
                    markers: _buildMarkers(),
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                  ),
                ),

                // Contact List
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: ListView.builder(
                      itemCount: _contacts.length,
                      itemBuilder: (context, index) {
                        final contact = _contacts[index];
                        final liveLocation =
                            _liveLocations[contact.phoneNumber];
                        final isActive = liveLocation?.status == 'active';

                        return ListTile(
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
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: isActive
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      liveLocation!.address ??
                                          'Unknown location',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    Text(
                                      'Updated: ${_formatTimeAgo(liveLocation.timestamp)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                )
                              : const Text('Not sharing location'),
                          trailing: isActive
                              ? Icon(Icons.location_on, color: Colors.green)
                              : Icon(
                                  Icons.location_off,
                                  color: Colors.grey.shade400,
                                ),
                          onTap: isActive
                              ? () {
                                  // Focus on this contact's location
                                  _mapController?.animateCamera(
                                    CameraUpdate.newLatLngZoom(
                                      LatLng(
                                        liveLocation!.latitude,
                                        liveLocation.longitude,
                                      ),
                                      16.0,
                                    ),
                                  );
                                }
                              : null,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
