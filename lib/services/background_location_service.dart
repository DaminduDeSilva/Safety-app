import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database_service.dart';
import 'location_service.dart';
import '../models/enhanced_emergency_contact.dart';

/// Background location tracking service for continuous monitoring
/// 
/// This service tracks user location even when the app is in background
/// for emergency preparedness and intelligent contact selection.
class BackgroundLocationService {
  static const String _isolateName = 'background_location_isolate';
  static const String _portName = 'background_location_port';
  
  static final BackgroundLocationService _instance = BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final LocationService _locationService = LocationService();
  
  Timer? _trackingTimer;
  StreamSubscription<Position>? _positionStream;
  ReceivePort? _receivePort;
  bool _isTracking = false;
  
  /// Starts background location tracking
  Future<void> startBackgroundTracking() async {
    if (_isTracking) return;

    // Request necessary permissions
    final hasPermissions = await _requestPermissions();
    if (!hasPermissions) {
      debugPrint('Background location permissions not granted');
      return;
    }

    try {
      _isTracking = true;
      
      // Setup foreground tracking
      await _startForegroundTracking();
      
      // Setup background isolate for when app is backgrounded
      await _setupBackgroundIsolate();
      
      debugPrint('Background location tracking started successfully');
    } catch (e) {
      debugPrint('Error starting background tracking: $e');
      _isTracking = false;
    }
  }

  /// Stops background location tracking
  Future<void> stopBackgroundTracking() async {
    if (!_isTracking) return;

    _trackingTimer?.cancel();
    _positionStream?.cancel();
    _receivePort?.close();
    
    // Remove background callback
    IsolateNameServer.removePortNameMapping(_portName);
    
    _isTracking = false;
    debugPrint('Background location tracking stopped');
  }

  /// Request necessary permissions for background tracking
  Future<bool> _requestPermissions() async {
    final permissions = [
      Permission.location,
      Permission.locationWhenInUse,
      Permission.locationAlways,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();
    
    // Check if we have at least basic location permission
    return statuses[Permission.location]?.isGranted == true ||
           statuses[Permission.locationWhenInUse]?.isGranted == true;
  }

  /// Setup foreground location tracking
  Future<void> _startForegroundTracking() async {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onLocationUpdate,
      onError: (error) {
        debugPrint('Location stream error: $error');
      },
    );

    // Also setup periodic updates every 5 minutes for stationary users
    _trackingTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _periodicLocationUpdate(),
    );
  }

  /// Setup background isolate for location tracking
  Future<void> _setupBackgroundIsolate() async {
    _receivePort = ReceivePort();
    
    // Register the port with a known name
    IsolateNameServer.registerPortWithName(
      _receivePort!.sendPort,
      _portName,
    );

    // Listen for messages from background isolate
    _receivePort!.listen((dynamic data) {
      if (data is Map<String, dynamic>) {
        _handleBackgroundLocationUpdate(data);
      }
    });
  }

  /// Handle location updates from foreground tracking
  void _onLocationUpdate(Position position) {
    _processLocationUpdate({
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'timestamp': position.timestamp?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
      'source': 'foreground',
    });
  }

  /// Periodic location update for stationary users
  Future<void> _periodicLocationUpdate() async {
    try {
      final position = await _locationService.getCurrentLocation();
      _onLocationUpdate(position);
    } catch (e) {
      debugPrint('Periodic location update failed: $e');
    }
  }

  /// Handle location updates from background isolate
  void _handleBackgroundLocationUpdate(Map<String, dynamic> data) {
    _processLocationUpdate(data);
  }

  /// Process location update and store in database
  Future<void> _processLocationUpdate(Map<String, dynamic> locationData) async {
    try {
      final latitude = locationData['latitude'] as double;
      final longitude = locationData['longitude'] as double;
      final accuracy = locationData['accuracy'] as double;
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        locationData['timestamp'] as int,
      );
      final source = locationData['source'] as String;

      // Get address for the location
      String? address;
      try {
        address = await _locationService.getAddressFromLatLng(latitude, longitude);
      } catch (e) {
        debugPrint('Failed to get address: $e');
      }

      // Create location data
      final locationUpdate = LocationData(
        latitude: latitude,
        longitude: longitude,
        address: address,
        timestamp: timestamp,
        placeType: await _inferPlaceType(latitude, longitude),
      );

      // Store in database
      await _databaseService.addLocationUpdate(locationUpdate);

      // Update user's current location
      await _databaseService.updateUserLocation(
        ContactLocation(
          latitude: latitude,
          longitude: longitude,
          address: address,
          timestamp: timestamp,
          accuracy: accuracy,
        ),
      );

      // Analyze and update contact scores
      await _updateContactScores(locationUpdate);

      debugPrint('Location update processed from $source: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}');
    } catch (e) {
      debugPrint('Error processing location update: $e');
    }
  }

  /// Infer place type based on location and time
  Future<String?> _inferPlaceType(double latitude, double longitude) async {
    try {
      // Get user's recent locations to identify patterns
      final recentLocations = await _databaseService.getRecentUserLocations(limit: 50);
      
      // Simple heuristic: if user spends more than 6 hours in a location, it's likely home/work
      final currentTime = DateTime.now();
      final hour = currentTime.hour;
      
      // Night time (10PM - 6AM) + familiar location = likely home
      if ((hour >= 22 || hour <= 6)) {
        if (_isLocationFamiliar(latitude, longitude, recentLocations)) {
          return 'home';
        }
      }
      
      // Work hours (9AM - 5PM) + familiar location = likely work
      if (hour >= 9 && hour <= 17 && currentTime.weekday <= 5) {
        if (_isLocationFamiliar(latitude, longitude, recentLocations)) {
          return 'work';
        }
      }
      
      return 'other';
    } catch (e) {
      debugPrint('Error inferring place type: $e');
      return null;
    }
  }

  /// Check if location is familiar based on recent visits
  bool _isLocationFamiliar(double lat, double lng, List<LocationData> recentLocations) {
    const double familiarRadius = 100; // meters
    
    int visits = 0;
    for (final location in recentLocations) {
      final distance = Geolocator.distanceBetween(
        lat, lng,
        location.latitude, location.longitude,
      );
      
      if (distance <= familiarRadius) {
        visits++;
        if (visits >= 3) return true; // Visited 3+ times = familiar
      }
    }
    
    return false;
  }

  /// Update contact scores based on new location data
  Future<void> _updateContactScores(LocationData userLocation) async {
    try {
      final contacts = await _databaseService.getEnhancedEmergencyContacts();
      
      for (final contact in contacts) {
        // Calculate new scores
        final proximityScore = await _calculateProximityScore(userLocation, contact);
        final virtualClosenessScore = await _calculateVirtualClosenessScore(userLocation, contact);
        final activityScore = await _calculateActivityScore(contact);
        
        // Calculate overall priority score
        final priorityScore = _calculatePriorityScore(
          proximityScore,
          virtualClosenessScore,
          activityScore,
          contact.isPrimary,
        );

        // Update contact with new scores
        final updatedContact = contact.copyWith(
          proximityScore: proximityScore,
          virtualClosenessScore: virtualClosenessScore,
          activityScore: activityScore,
          priorityScore: priorityScore,
        );

        await _databaseService.updateEnhancedEmergencyContact(updatedContact);
      }
    } catch (e) {
      debugPrint('Error updating contact scores: $e');
    }
  }

  /// Calculate proximity score based on distance to contact
  Future<double> _calculateProximityScore(LocationData userLocation, EnhancedEmergencyContact contact) async {
    if (contact.lastKnownLocation == null) return 0.0;

    final distance = Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      contact.lastKnownLocation!.latitude,
      contact.lastKnownLocation!.longitude,
    );

    // Score: 1.0 for <1km, 0.5 for <5km, 0.2 for <20km, 0.0 for >20km
    if (distance < 1000) return 1.0;
    if (distance < 5000) return 0.8;
    if (distance < 10000) return 0.6;
    if (distance < 20000) return 0.3;
    return 0.0;
  }

  /// Calculate virtual closeness based on time spent in similar locations
  Future<double> _calculateVirtualClosenessScore(LocationData userLocation, EnhancedEmergencyContact contact) async {
    try {
      final userRecentLocations = await _databaseService.getRecentUserLocations(limit: 100);
      final contactRecentLocations = contact.recentLocations;

      if (contactRecentLocations.isEmpty) return 0.0;

      int sharedLocationCount = 0;
      Duration sharedTime = Duration.zero;

      // Find shared locations (within 500m radius)
      for (final userLoc in userRecentLocations) {
        for (final contactLoc in contactRecentLocations) {
          final distance = Geolocator.distanceBetween(
            userLoc.latitude,
            userLoc.longitude,
            contactLoc.latitude,
            contactLoc.longitude,
          );

          if (distance < 500) { // Within 500m
            sharedLocationCount++;
            sharedTime += userLoc.timeSpent + contactLoc.timeSpent;
          }
        }
      }

      // Score based on shared locations and time
      final locationScore = (sharedLocationCount / 10).clamp(0.0, 1.0);
      final timeScore = (sharedTime.inHours / 24).clamp(0.0, 1.0);
      
      return (locationScore + timeScore) / 2;
    } catch (e) {
      debugPrint('Error calculating virtual closeness: $e');
      return 0.0;
    }
  }

  /// Calculate activity score based on recent app usage and responsiveness
  Future<double> _calculateActivityScore(EnhancedEmergencyContact contact) async {
    if (contact.lastActiveTime == null) return 0.0;

    final now = DateTime.now();
    final timeSinceActive = now.difference(contact.lastActiveTime!);

    // Score based on recency of activity
    if (timeSinceActive.inMinutes < 30) return 1.0;
    if (timeSinceActive.inHours < 2) return 0.8;
    if (timeSinceActive.inHours < 12) return 0.6;
    if (timeSinceActive.inDays < 1) return 0.4;
    if (timeSinceActive.inDays < 7) return 0.2;
    
    return 0.0;
  }

  /// Calculate overall priority score
  double _calculatePriorityScore(
    double proximityScore,
    double virtualClosenessScore,
    double activityScore,
    bool isPrimary,
  ) {
    // Weighted average with primary contact bonus
    final baseScore = (proximityScore * 0.4) + 
                     (virtualClosenessScore * 0.3) + 
                     (activityScore * 0.3);
    
    // Primary contacts get 20% bonus
    final primaryBonus = isPrimary ? 0.2 : 0.0;
    
    return (baseScore + primaryBonus).clamp(0.0, 1.0);
  }

  /// Get current tracking status
  bool get isTracking => _isTracking;
}

/// Background isolate entry point for location tracking
@pragma('vm:entry-point')
void backgroundLocationIsolate() {
  // This would be implemented for true background processing
  // For now, we'll rely on foreground service and periodic updates
  debugPrint('Background location isolate started');
}
