import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';

/// Enhanced screen for reporting unsafe zones with Google Maps integration.
///
/// Allows users to select exact locations on a map to report as unsafe zones.
/// Provides visual feedback and precise location selection.
class ReportUnsafeZoneScreen extends StatefulWidget {
  const ReportUnsafeZoneScreen({super.key});

  @override
  State<ReportUnsafeZoneScreen> createState() => _ReportUnsafeZoneScreenState();
}

class _ReportUnsafeZoneScreenState extends State<ReportUnsafeZoneScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();
  final TextEditingController _reasonController = TextEditingController();

  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isLoading = false;
  bool _isLoadingLocation = true;

  // Map settings
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(37.4219983, -122.084), // Default to Google HQ
    zoom: 15.0,
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  /// Gets the current location and centers the map
  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isLoadingLocation = true);

      final position = await _locationService.getCurrentLocation();
      final currentLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedLocation = currentLatLng;
        _isLoadingLocation = false;
      });

      // Update map camera to user's location
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(currentLatLng),
        );
      }

      // Get address for the current location
      await _updateSelectedAddress();
    } catch (e) {
      setState(() => _isLoadingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  /// Updates the address for the selected location
  Future<void> _updateSelectedAddress() async {
    if (_selectedLocation == null) return;

    try {
      final address = await _locationService.getAddressFromLatLng(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      );
      setState(() {
        _selectedAddress = address;
      });
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
  }

  /// Handles map tap to select location
  void _onMapTap(LatLng position) {
    setState(() {
      _selectedLocation = position;
    });
    _updateSelectedAddress();
  }

  /// Submits the unsafe zone report
  Future<void> _submitReport() async {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location on the map')),
      );
      return;
    }

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for reporting this zone')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _databaseService.reportUnsafeZone(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
        reason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Unsafe zone reported successfully! Thank you for keeping the community safe.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reporting unsafe zone: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Unsafe Zone'),
        centerTitle: true,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'Go to current location',
          ),
        ],
      ),
      body: Column(
        children: [
          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade50,
            child: Column(
              children: [
                Icon(Icons.warning, color: Colors.orange.shade700, size: 32),
                const SizedBox(height: 8),
                Text(
                  'Tap on the map to select the unsafe location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Be precise to help others avoid dangerous areas',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange.shade600,
                  ),
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            flex: 2,
            child: _isLoadingLocation
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Getting your location...'),
                      ],
                    ),
                  )
                : GoogleMap(
                    initialCameraPosition: _initialPosition,
                    onMapCreated: (GoogleMapController controller) {
                      _mapController = controller;
                      if (_selectedLocation != null) {
                        controller.animateCamera(
                          CameraUpdate.newLatLng(_selectedLocation!),
                        );
                      }
                    },
                    onTap: _onMapTap,
                    markers: _buildMarkers(),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    mapType: MapType.normal,
                    zoomControlsEnabled: true,
                  ),
          ),

          // Selected Location Info
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      'Selected Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_selectedLocation != null) ...[
                  Text(
                    _selectedAddress ?? 'Getting address...',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Tap on the map to select a location',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),

          // Reason Input
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why is this area unsafe?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TextField(
                      controller: _reasonController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        hintText: 'Describe what makes this area unsafe (e.g., poor lighting, recent incidents, dangerous traffic, etc.)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submitReport,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.report),
                      label: Text(
                        _isLoading ? 'Reporting...' : 'Report Unsafe Zone',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds markers for the map
  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // Selected location marker
    if (_selectedLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: _selectedLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Selected Unsafe Location',
            snippet: _selectedAddress ?? 'Tap to select',
          ),
        ),
      );
    }

    return markers;
  }
}
