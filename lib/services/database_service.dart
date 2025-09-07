import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/emergency_contact.dart';
import '../models/enhanced_emergency_contact.dart';
import '../models/emergency_event.dart';
import '../models/unsafe_zone.dart';
import '../models/live_location.dart';
import '../models/live_guardian.dart';

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

  /// Creates a complete user profile in Firestore.
  ///
  /// This method is specifically for the profile setup process and includes
  /// username uniqueness validation.
  Future<void> createUserProfile(UserModel user) async {
    try {
      // Double-check username availability before creating
      final isAvailable = await isUsernameAvailable(user.username);
      if (!isAvailable) {
        throw Exception('Username "${user.username}" is already taken');
      }

      await _firestore.collection('users').doc(user.uid).set(user.toMap());
      debugPrint('User profile created successfully: ${user.uid}');
    } catch (e) {
      debugPrint('Error creating user profile: $e');
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

  /// Gets the current user's profile.
  Future<UserModel?> getUserProfile(String uid) async {
    return await getUser(uid);
  }

  /// Checks if a user has a complete profile in Firestore.
  Future<bool> isProfileComplete(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists || doc.data() == null) {
        return false;
      }

      final data = doc.data()!;
      // Check if all required fields exist
      return data.containsKey('username') &&
          data.containsKey('firstName') &&
          data.containsKey('lastName') &&
          data.containsKey('phoneNumber') &&
          data['username'] != null &&
          data['firstName'] != null &&
          data['lastName'] != null &&
          data['phoneNumber'] != null;
    } catch (e) {
      debugPrint('Error checking profile completeness: $e');
      return false;
    }
  }

  /// Checks if a username is available.
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final normalizedUsername = username.toLowerCase().trim();
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: normalizedUsername)
          .limit(1)
          .get();

      return query.docs.isEmpty;
    } catch (e) {
      debugPrint('Error checking username availability: $e');
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
  Future<String> logEmergency(double lat, double lng, String address) async {
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
      return docRef.id;
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

  // ============================================================================
  // ENHANCED EMERGENCY CONTACT METHODS
  // ============================================================================

  /// Adds a new enhanced emergency contact for the current user.
  Future<void> addEnhancedEmergencyContact(
    EnhancedEmergencyContact contact,
  ) async {
    try {
      final userId = _currentUserId;
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('enhanced_emergency_contacts')
          .add(contact.toMap());

      debugPrint('Enhanced emergency contact added successfully: ${docRef.id}');
    } catch (e) {
      debugPrint('Error adding enhanced emergency contact: $e');
      rethrow;
    }
  }

  /// Gets all enhanced emergency contacts for the current user.
  Future<List<EnhancedEmergencyContact>> getEnhancedEmergencyContacts() async {
    try {
      final userId = _currentUserId;
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('enhanced_emergency_contacts')
          .get();

      return snapshot.docs
          .map((doc) => EnhancedEmergencyContact.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error getting enhanced emergency contacts: $e');
      rethrow;
    }
  }

  /// Updates an enhanced emergency contact.
  Future<void> updateEnhancedEmergencyContact(
    EnhancedEmergencyContact contact,
  ) async {
    try {
      final userId = _currentUserId;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('enhanced_emergency_contacts')
          .doc(contact.id)
          .update(contact.toMap());

      debugPrint(
        'Enhanced emergency contact updated successfully: ${contact.id}',
      );
    } catch (e) {
      debugPrint('Error updating enhanced emergency contact: $e');
      rethrow;
    }
  }

  /// Adds a location update for the current user.
  Future<void> addLocationUpdate(LocationData locationData) async {
    try {
      final userId = _currentUserId;
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('location_history')
          .add(locationData.toMap());

      debugPrint('Location update added successfully');
    } catch (e) {
      debugPrint('Error adding location update: $e');
      rethrow;
    }
  }

  /// Gets recent location updates for the current user.
  Future<List<LocationData>> getRecentUserLocations({int limit = 50}) async {
    try {
      final userId = _currentUserId;
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('location_history')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => LocationData.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error getting recent user locations: $e');
      rethrow;
    }
  }

  /// Updates user's current location.
  Future<void> updateUserLocation(ContactLocation location) async {
    try {
      final userId = _currentUserId;
      await _firestore.collection('users').doc(userId).update({
        'currentLocation': location.toMap(),
        'lastLocationUpdate': Timestamp.fromDate(DateTime.now()),
      });

      debugPrint('User location updated successfully');
    } catch (e) {
      debugPrint('Error updating user location: $e');
      rethrow;
    }
  }

  /// Adds an emergency notification record.
  Future<void> addEmergencyNotification(
    EmergencyNotification notification,
  ) async {
    try {
      await _firestore
          .collection('emergency_notifications')
          .doc(notification.id)
          .set(notification.toMap());

      debugPrint(
        'Emergency notification added successfully: ${notification.id}',
      );
    } catch (e) {
      debugPrint('Error adding emergency notification: $e');
      rethrow;
    }
  }

  /// Gets all notifications for an emergency.
  Future<List<EmergencyNotification>> getEmergencyNotifications(
    String emergencyId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('emergency_notifications')
          .where('emergencyId', isEqualTo: emergencyId)
          .get();

      return snapshot.docs
          .map((doc) => EmergencyNotification.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error getting emergency notifications: $e');
      rethrow;
    }
  }

  /// Gets contacts that have been notified for an emergency.
  Future<List<EmergencyNotification>> getNotifiedContacts(
    String emergencyId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('emergency_notifications')
          .where('emergencyId', isEqualTo: emergencyId)
          .where('status', whereIn: ['sent', 'delivered', 'read', 'responded'])
          .get();

      return snapshot.docs
          .map((doc) => EmergencyNotification.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error getting notified contacts: $e');
      rethrow;
    }
  }

  /// Updates notification response.
  Future<void> updateNotificationResponse(
    String emergencyId,
    String contactId,
    ContactResponse response,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('emergency_notifications')
          .where('emergencyId', isEqualTo: emergencyId)
          .where('contactId', isEqualTo: contactId)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.update({
          'response': response.toString().split('.').last,
          'respondedAt': Timestamp.fromDate(DateTime.now()),
          'status': 'responded',
        });
      }

      debugPrint('Notification response updated successfully');
    } catch (e) {
      debugPrint('Error updating notification response: $e');
      rethrow;
    }
  }

  /// Marks a notification as expired.
  Future<void> markNotificationExpired(
    String emergencyId,
    String contactId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('emergency_notifications')
          .where('emergencyId', isEqualTo: emergencyId)
          .where('contactId', isEqualTo: contactId)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.update({'status': 'expired'});
      }

      debugPrint('Notification marked as expired');
    } catch (e) {
      debugPrint('Error marking notification as expired: $e');
      rethrow;
    }
  }

  /// Gets an emergency event by ID.
  Future<EmergencyEvent?> getEmergencyEvent(String emergencyId) async {
    try {
      final doc = await _firestore
          .collection('emergency_events')
          .doc(emergencyId)
          .get();

      if (doc.exists && doc.data() != null) {
        return EmergencyEvent.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting emergency event: $e');
      rethrow;
    }
  }

  // ============================================================================
  // LIVE GUARDIANS METHODS
  // ============================================================================

  /// Gets a stream of live guardians (emergency contacts with their live location status).
  ///
  /// Returns a stream that combines emergency contacts with their real-time location
  /// sharing status for display in the "Live Guardians" section.
  Stream<List<LiveGuardian>> getLiveGuardiansStream() {
    try {
      final userId = _currentUserId;

      return _firestore
          .collection('users')
          .doc(userId)
          .collection('emergency_contacts')
          .where(
            'contactId',
            isNotEqualTo: null,
          ) // Only include contacts with contactId
          .snapshots()
          .asyncMap((contactsSnapshot) async {
            final List<LiveGuardian> liveGuardians = [];

            for (final contactDoc in contactsSnapshot.docs) {
              try {
                final contact = EmergencyContact.fromMap(
                  contactDoc.data(),
                  contactDoc.id,
                );

                // Skip contacts without contactId (manually added contacts)
                if (contact.contactId == null) continue;

                // Get live location for this contact
                LiveLocation? liveLocation;
                try {
                  final locationDoc = await _firestore
                      .collection('live_locations')
                      .doc(contact.contactId!)
                      .get();

                  if (locationDoc.exists && locationDoc.data() != null) {
                    final data = locationDoc.data()!;
                    final status = data['status'] as String? ?? 'inactive';

                    // Only include active location sharing
                    if (status == 'active') {
                      liveLocation = LiveLocation.fromDocument(locationDoc);
                    }
                  }
                } catch (e) {
                  debugPrint(
                    'Error fetching live location for ${contact.contactId}: $e',
                  );
                  // Continue without location data
                }

                liveGuardians.add(
                  LiveGuardian(contact: contact, liveLocation: liveLocation),
                );
              } catch (e) {
                debugPrint('Error processing contact ${contactDoc.id}: $e');
                // Continue with other contacts
              }
            }

            // Sort by sharing status (sharing first), then by name
            liveGuardians.sort((a, b) {
              if (a.isSharingLocation && !b.isSharingLocation) return -1;
              if (!a.isSharingLocation && b.isSharingLocation) return 1;
              return a.contact.name.compareTo(b.contact.name);
            });

            return liveGuardians;
          });
    } catch (e) {
      debugPrint('Error getting live guardians stream: $e');
      return Stream.value([]);
    }
  }
}
