import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';

/// Service for handling all location-related operations.
///
/// This service provides a clean interface for location services,
/// including permission handling, position retrieval, and geocoding.
class LocationService {
  // Singleton pattern implementation
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Gets the current device location with proper permission handling.
  ///
  /// This method handles the complete flow of location permissions:
  /// 1. Checks if location services are enabled
  /// 2. Checks current app permission status
  /// 3. Requests permission if needed
  /// 4. Handles all possible permission outcomes
  ///
  /// Throws [LocationServiceException] with specific error messages for UI display.
  Future<Position> getCurrentLocation() async {
    try {
      // Step 1: Check if location services are enabled on the device
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw LocationServiceException(
          'Location services are disabled. Please enable GPS in your device settings.',
        );
      }

      // Step 2: Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();

      // Step 3: Handle permission requests
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw LocationServiceException(
            'Location permission denied. Please grant location access to use this feature.',
          );
        }
      }

      // Step 4: Handle permanently denied permissions
      if (permission == LocationPermission.deniedForever) {
        throw LocationServiceException(
          'Location permission permanently denied. Please enable location access in your device settings.',
        );
      }

      // Step 5: Get the current position
      debugPrint('LocationService: Getting current position...');
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15), // Prevent hanging
      );

      debugPrint(
        'LocationService: Position obtained - Lat: ${position.latitude}, Lng: ${position.longitude}',
      );
      return position;
    } on LocationServiceException {
      // Re-throw our custom exceptions without modification
      rethrow;
    } catch (e) {
      debugPrint('LocationService: Unexpected error getting location: $e');
      // Handle other potential errors (network timeout, etc.)
      throw LocationServiceException(
        'Failed to get current location. Please check your GPS settings and try again.',
      );
    }
  }

  /// Converts latitude and longitude coordinates to a human-readable address.
  ///
  /// Uses reverse geocoding to get address information from coordinates.
  /// Returns a formatted address string or a fallback coordinate string.
  ///
  /// [lat] - Latitude coordinate
  /// [lng] - Longitude coordinate
  ///
  /// Returns a formatted address string or "Unknown location" if geocoding fails.
  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      debugPrint('LocationService: Getting address for Lat: $lat, Lng: $lng');

      final List<Placemark> placemarks = await placemarkFromCoordinates(
        lat,
        lng,
        localeIdentifier: 'en', // Use English locale for consistency
      );

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;

        // Build address from available components
        final List<String> addressParts = [];

        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          addressParts.add(place.postalCode!);
        }
        if (place.country != null && place.country!.isNotEmpty) {
          addressParts.add(place.country!);
        }

        if (addressParts.isNotEmpty) {
          final String address = addressParts.join(', ');
          debugPrint('LocationService: Address found: $address');
          return address;
        }
      }

      // Fallback to coordinates if no address components available
      final String coordinateString =
          'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}';
      debugPrint(
        'LocationService: No address found, using coordinates: $coordinateString',
      );
      return coordinateString;
    } catch (e) {
      debugPrint('LocationService: Geocoding error: $e');

      // Return coordinates as fallback
      final String coordinateString =
          'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}';
      debugPrint(
        'LocationService: Geocoding failed, using coordinates: $coordinateString',
      );
      return coordinateString;
    }
  }

  /// Checks if location permissions are granted.
  ///
  /// Returns true if location permissions are granted, false otherwise.
  /// This is a utility method for UI components to check permission status.
  Future<bool> hasLocationPermission() async {
    try {
      final LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('LocationService: Error checking permission: $e');
      return false;
    }
  }

  /// Checks if location services are enabled on the device.
  ///
  /// Returns true if GPS/location services are enabled, false otherwise.
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('LocationService: Error checking location service: $e');
      return false;
    }
  }

  /// Opens the device's location settings.
  ///
  /// This is useful when users need to manually enable location services
  /// or grant permissions from the device settings.
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('LocationService: Error opening location settings: $e');
      return false;
    }
  }

  /// Opens the app's permission settings.
  ///
  /// This is useful when location permission is permanently denied
  /// and users need to grant it manually from app settings.
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      debugPrint('LocationService: Error opening app settings: $e');
      return false;
    }
  }
}

/// Custom exception for location service errors.
///
/// This provides clear error messages that can be displayed to users.
class LocationServiceException implements Exception {
  final String message;

  const LocationServiceException(this.message);

  @override
  String toString() => 'LocationServiceException: $message';
}
