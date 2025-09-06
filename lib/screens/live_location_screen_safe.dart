import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';

/// Screen for users to start and manage their live location sharing session.
///
/// Allows users to start/stop sharing their location in real-time with emergency contacts.
/// Shows location information in a text-based format as a fallback when Google Maps isn't available.
class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();

  Timer? _locationUpdateTimer;
  bool _isSharing = false;
  bool _isLoading = false;
  Position? _currentPosition;
  String? _currentAddress;
  String? _errorMessage;

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

  /// Gets the current location and updates the display
  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

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
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
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

  /// Formats coordinates for display
  String _formatCoordinates(Position position) {
    return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
  }

  /// Opens Google Maps with current location
  void _openInMaps() {
    if (_currentPosition != null) {
      final url =
          'https://maps.google.com/?q=${_currentPosition!.latitude},${_currentPosition!.longitude}';
      // You could use url_launcher here to open the URL
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Location Sharing'),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_currentPosition != null)
            IconButton(
              icon: const Icon(Icons.map),
              onPressed: _openInMaps,
              tooltip: 'View in Maps',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getCurrentLocation,
            tooltip: 'Refresh Location',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
                  const SizedBox(height: 12),
                  Text(
                    _isSharing
                        ? 'Sharing Live Location'
                        : 'Location Sharing Off',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _isSharing ? Colors.green : Colors.grey.shade700,
                    ),
                  ),
                  if (_isSharing) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Your location is being shared with emergency contacts',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Location Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Current Location',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_isLoading) ...[
                      const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 16),
                      const Text('Getting current location...'),
                    ] else if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error, color: Colors.red[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Error: $_errorMessage',
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_currentPosition != null) ...[
                      _buildLocationDetail(
                        'Address',
                        _currentAddress ?? 'Unknown',
                      ),
                      const SizedBox(height: 12),
                      _buildLocationDetail(
                        'Coordinates',
                        _formatCoordinates(_currentPosition!),
                      ),
                      const SizedBox(height: 12),
                      _buildLocationDetail(
                        'Accuracy',
                        '±${_currentPosition!.accuracy.toStringAsFixed(1)} meters',
                      ),
                      const SizedBox(height: 12),
                      _buildLocationDetail(
                        'Last Updated',
                        DateTime.now().toString().split('.')[0],
                      ),
                    ] else ...[
                      const Text('No location data available'),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 56,
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
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(_isSharing ? Icons.stop : Icons.play_arrow),
                label: Text(
                  _isLoading
                      ? 'Processing...'
                      : _isSharing
                      ? 'Stop Sharing Location'
                      : 'Start Sharing Location',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSharing ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'How Live Location Works',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Your location is updated every 30 seconds while sharing\n'
                    '• Emergency contacts can view your location on their Guardian Dashboard\n'
                    '• Location sharing stops automatically when you close the app\n'
                    '• You can stop sharing anytime using the button above',
                    style: TextStyle(color: Colors.blue[700], fontSize: 14),
                  ),
                ],
              ),
            ),
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
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
