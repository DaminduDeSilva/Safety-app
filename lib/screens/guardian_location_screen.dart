import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/live_guardian.dart';
import '../services/database_service.dart';

/// Screen for viewing a specific guardian's live location on a map.
///
/// Shows the guardian's current location with real-time updates and provides
/// information about their location sharing status and last update time.
class GuardianLocationScreen extends StatefulWidget {
  final LiveGuardian guardian;

  const GuardianLocationScreen({super.key, required this.guardian});

  @override
  State<GuardianLocationScreen> createState() => _GuardianLocationScreenState();
}

class _GuardianLocationScreenState extends State<GuardianLocationScreen> {
  final DatabaseService _databaseService = DatabaseService();

  GoogleMapController? _mapController;
  StreamSubscription? _locationStreamSubscription;
  LiveGuardian? _currentGuardian;

  // Map settings
  late CameraPosition _initialPosition;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _currentGuardian = widget.guardian;
    _setupInitialPosition();
    _startLocationStream();
  }

  @override
  void dispose() {
    _locationStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  /// Sets up the initial map position based on guardian's location
  void _setupInitialPosition() {
    if (_currentGuardian?.liveLocation != null) {
      final location = _currentGuardian!.liveLocation!;
      _initialPosition = CameraPosition(
        target: LatLng(location.latitude, location.longitude),
        zoom: 15.0,
      );
      _updateMarker(location.latitude, location.longitude);
    } else {
      // Default position if no location available
      _initialPosition = const CameraPosition(
        target: LatLng(37.4219983, -122.084),
        zoom: 14.0,
      );
    }
  }

  /// Starts listening to real-time location updates for the guardian
  void _startLocationStream() {
    if (_currentGuardian?.contact.contactId == null) return;

    _locationStreamSubscription = _databaseService
        .getLiveLocationStream(_currentGuardian!.contact.contactId!)
        .listen(
          (liveLocation) {
            if (mounted && liveLocation != null) {
              setState(() {
                _currentGuardian = _currentGuardian!.copyWith(
                  liveLocation: liveLocation,
                );
              });
              _updateMarker(liveLocation.latitude, liveLocation.longitude);
              _animateToLocation(liveLocation.latitude, liveLocation.longitude);
            }
          },
          onError: (error) {
            debugPrint('Error listening to guardian location: $error');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error updating location: $error'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        );
  }

  /// Updates the map marker with the guardian's current location
  void _updateMarker(double latitude, double longitude) {
    setState(() {
      _markers = {
        Marker(
          markerId: MarkerId('guardian_${_currentGuardian!.contact.contactId}'),
          position: LatLng(latitude, longitude),
          infoWindow: InfoWindow(
            title: _currentGuardian!.contact.name,
            snippet: _currentGuardian!.lastSeenText,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      };
    });
  }

  /// Animates the map camera to the guardian's location
  void _animateToLocation(double latitude, double longitude) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(latitude, longitude)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentGuardian?.contact.name}\'s Location'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _refreshLocation,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Location',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Card
          Card(
            margin: const EdgeInsets.all(16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                            _currentGuardian?.isSharingLocation == true
                            ? Colors.green
                            : Colors.grey,
                        radius: 16,
                        child: Icon(
                          _currentGuardian?.isSharingLocation == true
                              ? Icons.location_on
                              : Icons.location_off,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentGuardian?.contact.name ?? 'Unknown',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              _currentGuardian?.contact.relationship ?? '',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  _buildStatusRow(
                    'Status',
                    _currentGuardian?.isSharingLocation == true
                        ? 'Sharing Location'
                        : 'Not Sharing',
                    _currentGuardian?.isSharingLocation == true
                        ? Colors.green
                        : Colors.grey,
                  ),
                  const SizedBox(height: 8),
                  _buildStatusRow(
                    'Last Update',
                    _currentGuardian?.lastSeenText ?? 'Unknown',
                    Colors.blue,
                  ),
                  if (_currentGuardian?.liveLocation?.address != null) ...[
                    const SizedBox(height: 8),
                    _buildStatusRow(
                      'Address',
                      _currentGuardian!.liveLocation!.address!,
                      Colors.orange,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Map
          Expanded(
            child: _currentGuardian?.liveLocation != null
                ? GoogleMap(
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                    },
                    initialCameraPosition: _initialPosition,
                    markers: _markers,
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                    mapType: MapType.normal,
                  )
                : Container(
                    margin: const EdgeInsets.all(16.0),
                    child: Card(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Location Not Available',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_currentGuardian?.contact.name} is not currently sharing their location.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _currentGuardian?.isSharingLocation == true
          ? FloatingActionButton(
              onPressed: _centerOnGuardian,
              tooltip: 'Center on Guardian',
              child: const Icon(Icons.my_location),
            )
          : null,
    );
  }

  /// Builds a status row with icon, label, and value
  Widget _buildStatusRow(String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Centers the map on the guardian's current location
  void _centerOnGuardian() {
    if (_currentGuardian?.liveLocation != null) {
      final location = _currentGuardian!.liveLocation!;
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(location.latitude, location.longitude),
            zoom: 17.0,
          ),
        ),
      );
    }
  }

  /// Manually refreshes the guardian's location
  void _refreshLocation() {
    // The stream should automatically update, but we can show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing location...'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}
