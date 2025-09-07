import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../widgets/modern_app_bar.dart';

/// Screen for users to start and manage their live location sharing session.
///
/// Allows users to start/stop sharing their location in real-time with emergency contacts.
/// Shows their current location on a map and provides status updates.
class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();

  GoogleMapController? _mapController;
  Timer? _locationUpdateTimer;
  bool _isSharing = false;
  bool _isLoading = false;
  Position? _currentPosition;
  String? _currentAddress;

  // Map settings
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(37.4219983, -122.084), // Default to Google HQ
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _checkSharingStatus();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _stopLocationUpdates();
    super.dispose();
  }

  /// Checks if user is currently sharing location
  Future<void> _checkSharingStatus() async {
    try {
      final isSharing = await _databaseService.isCurrentUserSharingLocation();
      if (mounted) {
        setState(() {
          _isSharing = isSharing;
        });
      }
    } catch (e) {
      debugPrint('Error checking sharing status: $e');
    }
  }

  /// Gets the current location and updates the map
  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isLoading = true);

      final position = await _locationService.getCurrentLocation();
      final address = await _locationService.getAddressFromLatLng(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _currentAddress = address;
          _isLoading = false;
        });

        // Update map camera
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(position.latitude, position.longitude),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
      }
    }
  }

  /// Starts live location sharing
  Future<void> _startSharing() async {
    if (_currentPosition == null) {
      await _getCurrentLocation();
      if (_currentPosition == null) return;
    }

    try {
      setState(() => _isLoading = true);

      // Start sharing in database
      await _databaseService.startLiveSharing(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        address: _currentAddress,
      );

      // Start periodic location updates (every 30 seconds)
      _locationUpdateTimer = Timer.periodic(
        const Duration(seconds: 30),
        (timer) => _updateLocation(),
      );

      setState(() {
        _isSharing = true;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Live location sharing started'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting sharing: $e')));
      }
    }
  }

  /// Stops live location sharing
  Future<void> _stopSharing() async {
    try {
      setState(() => _isLoading = true);

      await _databaseService.stopLiveSharing();
      _stopLocationUpdates();

      setState(() {
        _isSharing = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Live location sharing stopped'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error stopping sharing: $e')));
      }
    }
  }

  /// Updates location in the background
  Future<void> _updateLocation() async {
    if (!_isSharing) return;

    try {
      final position = await _locationService.getCurrentLocation();
      final address = await _locationService.getAddressFromLatLng(
        position.latitude,
        position.longitude,
      );

      await _databaseService.updateLiveLocation(
        position.latitude,
        position.longitude,
        address: address,
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _currentAddress = address;
        });

        // Update map
        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLng(
              LatLng(position.latitude, position.longitude),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating location: $e');
    }
  }

  /// Stops location update timer
  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(title: 'Live Location Sharing'),
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Status Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isSharing ? Colors.green.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isSharing ? Colors.green : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _isSharing ? Icons.location_on : Icons.location_off,
                  size: 48,
                  color: _isSharing ? Colors.green : Colors.grey,
                ),
                const SizedBox(height: 8),
                Text(
                  _isSharing ? 'Sharing Live Location' : 'Location Sharing Off',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _isSharing ? Colors.green : Colors.grey.shade700,
                  ),
                ),
                if (_currentAddress != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _currentAddress!,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),

          // Map
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.hardEdge,
              child: _currentPosition != null
                  ? GoogleMap(
                      initialCameraPosition: _initialPosition,
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        // Move to current position when map is ready
                        controller.animateCamera(
                          CameraUpdate.newLatLng(
                            LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                          ),
                        );
                      },
                      markers: {
                        if (_currentPosition != null)
                          Marker(
                            markerId: const MarkerId('current_location'),
                            position: LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                            infoWindow: InfoWindow(
                              title: 'Your Location',
                              snippet: _currentAddress ?? 'Current position',
                            ),
                          ),
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),

          // Action Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _isLoading
                  ? null
                  : _isSharing
                  ? _stopSharing
                  : _startSharing,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_isSharing ? Icons.stop : Icons.play_arrow),
              label: Text(
                _isLoading
                    ? 'Processing...'
                    : _isSharing
                    ? 'Stop Sharing'
                    : 'Start Sharing',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSharing ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
