import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/emergency_contact.dart';
import '../models/emergency_event.dart';
import '../models/unsafe_zone.dart';
import '../models/live_location.dart';

/// Central database service for handling all Firestore operations.
///
/// This service provides a clean interface for CRUD operations on all
/// data models in the safety app, using a singleton pattern for easy access.
class DatabaseService {
  // Singleton pattern implementation
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Gets the current authenticated user's UID.
  /// Throws an exception if no user is currently authenticated.
  String get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user found');
    }
    return user.uid;
  }

  // ============================================================================
  // USER MANAGEMENT METHODS
  // ============================================================================

  /// Creates a new user document in Firestore.
  ///
  /// Uses the user's UID as the document ID in the 'users' collection.
  Future<void> createUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toMap());
      debugPrint('User created successfully: ${user.uid}');
    } catch (e) {
      debugPrint('Error creating user: $e');
      rethrow;
    }
  }

  /// Retrieves a user document from Firestore by UID.
  ///
  /// Returns null if the user document doesn't exist.
  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!, uid);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user: $e');
      rethrow;
    }
  }

  /// Updates an existing user document in Firestore.
  Future<void> updateUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).update(user.toMap());
      debugPrint('User updated successfully: ${user.uid}');
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    }
  }

  // ============================================================================
  // EMERGENCY CONTACT MANAGEMENT METHODS
  // ============================================================================

  /// Adds a new emergency contact for the current user.
  ///
  /// The contact is stored in a subcollection under the user's document.
  /// A new document ID is automatically generated for the contact.
  Future<void> addEmergencyContact(EmergencyContact contact) async {
    try {
      final userId = _currentUserId;
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .add(contact.toMap());

      // Update the contact with the generated ID
      final updatedContact = contact.copyWith(id: docRef.id);
      await docRef.update(updatedContact.toMap());

      debugPrint('Emergency contact added successfully: ${docRef.id}');
    } catch (e) {
      debugPrint('Error adding emergency contact: $e');
      rethrow;
    }
  }

  /// Retrieves all emergency contacts for the current user.
  ///
  /// Returns an empty list if no contacts are found.
  Future<List<EmergencyContact>> getEmergencyContacts() async {
    try {
      final userId = _currentUserId;
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .get();

      return querySnapshot.docs
          .map((doc) => EmergencyContact.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error getting emergency contacts: $e');
      rethrow;
    }
  }

  /// Updates an existing emergency contact.
  Future<void> updateEmergencyContact(EmergencyContact contact) async {
    try {
      final userId = _currentUserId;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .doc(contact.id)
          .update(contact.toMap());

      debugPrint('Emergency contact updated successfully: ${contact.id}');
    } catch (e) {
      debugPrint('Error updating emergency contact: $e');
      rethrow;
    }
  }

  /// Deletes an emergency contact.
  Future<void> deleteEmergencyContact(String contactId) async {
    try {
      final userId = _currentUserId;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .doc(contactId)
          .delete();

      debugPrint('Emergency contact deleted successfully: $contactId');
    } catch (e) {
      debugPrint('Error deleting emergency contact: $e');
      rethrow;
    }
  }

  /// Gets a real-time stream of emergency contacts for the current user.
  ///
  /// Returns a stream that updates whenever contacts are added, modified, or deleted.
  Stream<List<EmergencyContact>> getEmergencyContactsStream() {
    try {
      final userId = _currentUserId;
      return _firestore
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => EmergencyContact.fromMap(doc.data(), doc.id))
                .toList(),
          );
    } catch (e) {
      debugPrint('Error getting emergency contacts stream: $e');
      rethrow;
    }
  }

  // ============================================================================
  // EMERGENCY EVENT LOGGING METHODS
  // ============================================================================

  /// Logs a new emergency event to Firestore.
  ///
  /// Creates a document in the top-level 'emergencies' collection with
  /// the current user's UID, location data, address, and server timestamp.
  Future<void> logEmergency(double lat, double lng, String address) async {
    try {
      final userId = _currentUserId;
      final docRef = await _firestore.collection('emergencies').add({
        'userId': userId,
        'latitude': lat,
        'longitude': lng,
        'address': address,
        'timestamp': FieldValue.serverTimestamp(),
        'resolved': false,
      });

      debugPrint('Emergency logged successfully: ${docRef.id}');
    } catch (e) {
      debugPrint('Error logging emergency: $e');
      rethrow;
    }
  }

  /// Retrieves emergency events for the current user.
  ///
  /// Orders by timestamp (most recent first).
  Future<List<EmergencyEvent>> getEmergencyEvents() async {
    try {
      final userId = _currentUserId;
      final querySnapshot = await _firestore
          .collection('emergencies')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        // Handle server timestamp
        if (data['timestamp'] is Timestamp) {
          data['timestamp'] =
              (data['timestamp'] as Timestamp).millisecondsSinceEpoch;
        } else {
          // Fallback if timestamp is null (server timestamp not yet written)
          data['timestamp'] = DateTime.now().millisecondsSinceEpoch;
        }
        return EmergencyEvent.fromMap(data, doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Error getting emergency events: $e');
      rethrow;
    }
  }

  /// Updates the resolved status of an emergency event.
  Future<void> resolveEmergency(String emergencyId, bool resolved) async {
    try {
      await _firestore.collection('emergencies').doc(emergencyId).update({
        'resolved': resolved,
      });

      debugPrint(
        'Emergency resolved status updated: $emergencyId -> $resolved',
      );
    } catch (e) {
      debugPrint('Error updating emergency resolved status: $e');
      rethrow;
    }
  }

  // ============================================================================
  // UNSAFE ZONE REPORTING METHODS
  // ============================================================================

  /// Reports a new unsafe zone to Firestore.
  ///
  /// Creates a document in the top-level 'unsafe_zones' collection with
  /// the provided data, current user's UID, and server timestamp.
  Future<void> reportUnsafeZone(double lat, double lng, String reason) async {
    try {
      final userId = _currentUserId;
      final docRef = await _firestore.collection('unsafe_zones').add({
        'userId': userId,
        'latitude': lat,
        'longitude': lng,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'verified': false,
        'verificationCount': 0,
      });

      debugPrint('Unsafe zone reported successfully: ${docRef.id}');
    } catch (e) {
      debugPrint('Error reporting unsafe zone: $e');
      rethrow;
    }
  }

  /// Retrieves unsafe zones within a certain radius of given coordinates.
  ///
  /// Note: This is a simplified version. For production, you'd want to use
  /// geohash queries or Firebase Extensions for more efficient geo queries.
  Future<List<UnsafeZone>> getNearbyUnsafeZones(
    double centerLat,
    double centerLng, {
    double radiusKm = 5.0,
  }) async {
    try {
      // Simple bounding box query (not perfect but functional for prototype)
      const double latDegreePerKm = 0.009; // Approximate
      const double lngDegreePerKm = 0.009; // Approximate (varies by latitude)

      final double latDelta = radiusKm * latDegreePerKm;
      final double lngDelta = radiusKm * lngDegreePerKm;

      final querySnapshot = await _firestore
          .collection('unsafe_zones')
          .where('latitude', isGreaterThan: centerLat - latDelta)
          .where('latitude', isLessThan: centerLat + latDelta)
          .get();

      // Filter by longitude and distance in memory
      final zones = querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            // Handle server timestamp
            if (data['timestamp'] is Timestamp) {
              data['timestamp'] =
                  (data['timestamp'] as Timestamp).millisecondsSinceEpoch;
            } else {
              data['timestamp'] = DateTime.now().millisecondsSinceEpoch;
            }
            return UnsafeZone.fromMap(data, doc.id);
          })
          .where((zone) {
            final lngDiff = (zone.longitude - centerLng).abs();
            return lngDiff <= lngDelta;
          })
          .toList();

      return zones;
    } catch (e) {
      debugPrint('Error getting nearby unsafe zones: $e');
      rethrow;
    }
  }

  /// Verifies an unsafe zone (increments verification count).
  Future<void> verifyUnsafeZone(String zoneId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final zoneRef = _firestore.collection('unsafe_zones').doc(zoneId);
        final snapshot = await transaction.get(zoneRef);

        if (!snapshot.exists) {
          throw Exception('Unsafe zone not found');
        }

        final currentCount = snapshot.data()?['verificationCount'] ?? 0;
        final newCount = currentCount + 1;

        transaction.update(zoneRef, {
          'verificationCount': newCount,
          'verified': newCount >= 3, // Mark as verified after 3 confirmations
        });
      });

      debugPrint('Unsafe zone verified: $zoneId');
    } catch (e) {
      debugPrint('Error verifying unsafe zone: $e');
      rethrow;
    }
  }

  // ============================================================================
  // LIVE LOCATION SHARING METHODS
  // ============================================================================

  /// Starts live location sharing for the current user.
  ///
  /// Creates or updates a document in the 'live_locations' collection.
  Future<void> startLiveSharing(
    double latitude,
    double longitude, {
    String? address,
  }) async {
    try {
      final liveLocation = LiveLocation(
        userId: _currentUserId,
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        status: 'active',
        address: address,
      );

      await _firestore
          .collection('live_locations')
          .doc(_currentUserId)
          .set(liveLocation.toMap());

      debugPrint('Live location sharing started for user: $_currentUserId');
    } catch (e) {
      debugPrint('Error starting live sharing: $e');
      rethrow;
    }
  }

  /// Updates the current user's live location with new coordinates.
  ///
  /// Updates the existing document with new coordinates and timestamp.
  Future<void> updateLiveLocation(
    double latitude,
    double longitude, {
    String? address,
  }) async {
    try {
      await _firestore.collection('live_locations').doc(_currentUserId).update({
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': Timestamp.fromDate(DateTime.now()),
        'status': 'active',
        if (address != null) 'address': address,
      });

      debugPrint('Live location updated for user: $_currentUserId');
    } catch (e) {
      debugPrint('Error updating live location: $e');
      rethrow;
    }
  }

  /// Stops live location sharing for the current user.
  ///
  /// Sets the status to 'finished' instead of deleting to maintain history.
  Future<void> stopLiveSharing() async {
    try {
      await _firestore.collection('live_locations').doc(_currentUserId).update({
        'status': 'finished',
        'timestamp': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('Live location sharing stopped for user: $_currentUserId');
    } catch (e) {
      debugPrint('Error stopping live sharing: $e');
      rethrow;
    }
  }

  /// Gets a stream of live location updates for a specific user.
  ///
  /// Returns a stream that emits LiveLocation objects whenever the document updates.
  Stream<LiveLocation?> getLiveLocationStream(String userId) {
    return _firestore.collection('live_locations').doc(userId).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists) {
        return LiveLocation.fromDocument(snapshot);
      }
      return null;
    });
  }

  /// Checks if a user is currently sharing their live location.
  ///
  /// Returns true if the user has an active live location sharing session.
  Future<bool> isUserSharingLocation(String userId) async {
    try {
      final doc = await _firestore
          .collection('live_locations')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['status'] == 'active';
      }
      return false;
    } catch (e) {
      debugPrint('Error checking live location status: $e');
      return false;
    }
  }

  /// Gets the current user's live location sharing status.
  Future<bool> isCurrentUserSharingLocation() async {
    return isUserSharingLocation(_currentUserId);
  }
}
