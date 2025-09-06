import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/intelligent_notification_service.dart';
import '../models/enhanced_emergency_contact.dart';

/// Screen for emergency contacts to respond to emergency alerts
class EmergencyResponseScreen extends StatefulWidget {
  final String emergencyId;
  final String contactId;
  final String emergencyMessage;
  final double latitude;
  final double longitude;
  final String? address;

  const EmergencyResponseScreen({
    super.key,
    required this.emergencyId,
    required this.contactId,
    required this.emergencyMessage,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  @override
  State<EmergencyResponseScreen> createState() => _EmergencyResponseScreenState();
}

class _EmergencyResponseScreenState extends State<EmergencyResponseScreen> {
  final IntelligentNotificationService _notificationService = IntelligentNotificationService();
  GoogleMapController? _mapController;
  ContactResponse? _selectedResponse;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Alert'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Prevent back button
      ),
      body: Column(
        children: [
          // Emergency Alert Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red, Colors.red.shade700],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.emergency,
                  size: 60,
                  color: Colors.white,
                ),
                SizedBox(height: 10),
                Text(
                  '🚨 EMERGENCY ALERT 🚨',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Someone needs your immediate help!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emergency Message
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.message, color: Colors.orange),
                              SizedBox(width: 8),
                              Text(
                                'Emergency Message',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.emergencyMessage,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Location Map
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
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
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (widget.address != null) ...[
                            Text(
                              widget.address!,
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            'Coordinates: ${widget.latitude.toStringAsFixed(6)}, ${widget.longitude.toStringAsFixed(6)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 200,
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(widget.latitude, widget.longitude),
                                zoom: 16,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('emergency'),
                                  position: LatLng(widget.latitude, widget.longitude),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueRed,
                                  ),
                                  infoWindow: const InfoWindow(
                                    title: '🚨 Emergency Location',
                                    snippet: 'Help needed here',
                                  ),
                                ),
                              },
                              onMapCreated: (controller) => _mapController = controller,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Response Options
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.help, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Your Response',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Please select your response:',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),

                          // Response Options
                          _buildResponseOption(
                            ContactResponse.willHelp,
                            Icons.check_circle,
                            'I will help',
                            'I can provide assistance',
                            Colors.green,
                          ),
                          const SizedBox(height: 12),
                          _buildResponseOption(
                            ContactResponse.onMyWay,
                            Icons.directions_run,
                            'On my way',
                            'I am coming to help',
                            Colors.blue,
                          ),
                          const SizedBox(height: 12),
                          _buildResponseOption(
                            ContactResponse.calledAuthorities,
                            Icons.local_police,
                            'Called authorities',
                            'I contacted emergency services',
                            Colors.orange,
                          ),
                          const SizedBox(height: 12),
                          _buildResponseOption(
                            ContactResponse.cannotHelp,
                            Icons.cancel,
                            'Cannot help',
                            'I am unable to assist right now',
                            Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _selectedResponse != null && !_isSubmitting
                          ? _submitResponse
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _selectedResponse != null
                                  ? 'Submit Response'
                                  : 'Please select a response',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Emergency Actions
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _callEmergencyServices(),
                          icon: const Icon(Icons.phone, color: Colors.red),
                          label: const Text(
                            'Call 911',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openMapsApp(),
                          icon: const Icon(Icons.directions, color: Colors.blue),
                          label: const Text(
                            'Directions',
                            style: TextStyle(color: Colors.blue),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.blue),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseOption(
    ContactResponse response,
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    final isSelected = _selectedResponse == response;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedResponse = response),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? color.withOpacity(0.1) : null,
        ),
        child: Row(
          children: [
            Radio<ContactResponse>(
              value: response,
              groupValue: _selectedResponse,
              onChanged: (value) => setState(() => _selectedResponse = value),
              activeColor: color,
            ),
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected ? color : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitResponse() async {
    if (_selectedResponse == null) return;

    setState(() => _isSubmitting = true);

    try {
      await _notificationService.handleContactResponse(
        emergencyId: widget.emergencyId,
        contactId: widget.contactId,
        response: _selectedResponse!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Response submitted: ${_getResponseText(_selectedResponse!)}'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back or to a confirmation screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting response: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _getResponseText(ContactResponse response) {
    switch (response) {
      case ContactResponse.willHelp:
        return 'I will help';
      case ContactResponse.onMyWay:
        return 'On my way';
      case ContactResponse.calledAuthorities:
        return 'Called authorities';
      case ContactResponse.cannotHelp:
        return 'Cannot help';
      case ContactResponse.noResponse:
        return 'No response';
    }
  }

  void _callEmergencyServices() async {
    // Implementation to call emergency services
    // This would use url_launcher to make a phone call
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calling emergency services...'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _openMapsApp() async {
    // Implementation to open maps app with directions
    // This would use url_launcher to open maps with directions
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening directions...'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
