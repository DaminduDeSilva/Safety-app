import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/emergency_invitation.dart';
import '../models/user_model.dart';
import 'database_service.dart';

/// Service for managing emergency contact invitations
///
/// Handles in-app invitations, managing invitation status,
/// and processing invitation responses.
class InvitationService {
  static final InvitationService _instance = InvitationService._internal();
  factory InvitationService() => _instance;
  InvitationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseService _databaseService = DatabaseService();

  /// Searches for users by username
  Future<List<UserModel>> searchUserByUsername(String query) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      final normalizedQuery = query.toLowerCase().trim();

      final snapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: normalizedQuery)
          .where('username', isLessThan: '${normalizedQuery}z')
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error searching users by username: $e');
      return [];
    }
  }

  /// Sends an emergency contact invitation using username
  Future<String> sendInvitationByUsername({
    required String recipientUsername,
    required String relationship,
    String? personalMessage,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Get current user's profile
      final currentUserProfile = await _databaseService.getUserProfile(
        currentUser.uid,
      );
      if (currentUserProfile == null) {
        throw Exception('Current user profile not found');
      }

      // Find recipient by username
      final normalizedUsername = recipientUsername.toLowerCase().trim();
      final recipientQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: normalizedUsername)
          .limit(1)
          .get();

      if (recipientQuery.docs.isEmpty) {
        throw Exception('User with username "$recipientUsername" not found');
      }

      final recipientDoc = recipientQuery.docs.first;
      final recipient = UserModel.fromMap(recipientDoc.data(), recipientDoc.id);

      // Check if trying to invite self
      if (recipient.uid == currentUser.uid) {
        throw Exception('You cannot invite yourself');
      }

      // Check if invitation already exists
      final existingInvitation = await _checkExistingInvitationByUsername(
        currentUser.uid,
        recipient.uid,
      );
      if (existingInvitation != null) {
        throw Exception('An invitation has already been sent to this user');
      }

      // Generate unique invitation code
      final inviteCode = _generateInviteCode();
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(days: 7)); // 7 days expiry

      // Create invitation object with username-based fields
      final invitationData = {
        'senderUserId': currentUser.uid,
        'senderUsername': currentUserProfile.username,
        'senderName': currentUserProfile.displayName,
        'senderEmail': currentUserProfile.email,
        'recipientUserId': recipient.uid,
        'recipientUsername': recipient.username,
        'recipientName': recipient.displayName,
        'recipientEmail': recipient.email,
        'relationship': relationship,
        'sentAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'message': personalMessage?.trim(),
        'inviteCode': inviteCode,
        'status': 'pending',
      };

      // Store invitation in Firestore
      final docRef = await _firestore
          .collection('invitations')
          .add(invitationData);

      debugPrint('Invitation sent successfully: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('Error sending invitation: $e');
      rethrow;
    }
  }

  /// Gets all invitations sent by the current user
  Future<List<EmergencyInvitation>> getSentInvitations() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      final querySnapshot = await _firestore
          .collection('invitations')
          .where('senderUserId', isEqualTo: currentUser.uid)
          .orderBy('sentAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => EmergencyInvitation.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error getting sent invitations: $e');
      return [];
    }
  }

  /// Gets all invitations received by the current user
  Future<List<EmergencyInvitation>> getReceivedInvitations() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.email == null) return [];

      final querySnapshot = await _firestore
          .collection('invitations')
          .where('recipientEmail', isEqualTo: currentUser.email!.toLowerCase())
          .where('status', isEqualTo: 'pending')
          .orderBy('sentAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => EmergencyInvitation.fromMap(doc.data(), doc.id))
          .where((invitation) => !invitation.isExpired)
          .toList();
    } catch (e) {
      debugPrint('Error getting received invitations: $e');
      return [];
    }
  }

  /// Accepts an invitation by invite code
  Future<void> acceptInvitation(String inviteCode) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Find invitation by code
      final querySnapshot = await _firestore
          .collection('invitations')
          .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Invalid or expired invitation code');
      }

      final doc = querySnapshot.docs.first;
      final invitation = EmergencyInvitation.fromMap(doc.data(), doc.id);

      // Verify invitation is still valid
      if (invitation.isExpired) {
        throw Exception('This invitation has expired');
      }

      // Verify recipient email matches current user
      if (invitation.recipientEmail.toLowerCase() !=
          currentUser.email?.toLowerCase()) {
        throw Exception('This invitation is not for your account');
      }

      // Get recipient's name
      final recipientName =
          currentUser.displayName ??
          currentUser.email?.split('@').first ??
          'User';

      // Validate sender still exists
      final senderExists = await _validateSender(invitation.senderUserId);
      if (!senderExists) {
        throw Exception('The user who sent this invitation no longer exists');
      }

      // Update invitation status
      await doc.reference.update({
        'status': 'accepted',
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // Add mutual emergency contact relationship
      await _addMutualEmergencyContact(invitation, recipientName);

      debugPrint('Invitation accepted successfully');
    } catch (e) {
      debugPrint('Error accepting invitation: $e');
      rethrow;
    }
  }

  /// Declines an invitation
  Future<void> declineInvitation(String invitationId) async {
    try {
      await _firestore.collection('invitations').doc(invitationId).update({
        'status': 'declined',
        'respondedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Invitation declined successfully');
    } catch (e) {
      debugPrint('Error declining invitation: $e');
      rethrow;
    }
  }

  /// Cancels an invitation (sender only)
  Future<void> cancelInvitation(String invitationId) async {
    try {
      await _firestore.collection('invitations').doc(invitationId).update({
        'status': 'cancelled',
        'respondedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Invitation cancelled successfully');
    } catch (e) {
      debugPrint('Error cancelling invitation: $e');
      rethrow;
    }
  }

  /// Generates a unique 8-character invitation code
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        8,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  /// Validates that a sender user still exists
  Future<bool> _validateSender(String senderUserId) async {
    try {
      final doc = await _firestore.collection('users').doc(senderUserId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error validating sender: $e');
      return false;
    }
  }

  /// Adds mutual emergency contact relationship
  Future<void> _addMutualEmergencyContact(
    EmergencyInvitation invitation,
    String recipientName,
  ) async {
    final batch = _firestore.batch();

    try {
      // Get current user (recipient)
      final currentUser = _auth.currentUser!;

      // Add sender as emergency contact for recipient
      final recipientContactData = {
        'userId': currentUser.uid,
        'contactId': invitation.senderUserId,
        'name': invitation.senderName,
        'email': invitation.senderEmail,
        'phoneNumber': '', // Will be populated when user updates profile
        'relationship': invitation.relationship,
        'isEmergencyContact': true,
        'addedAt': FieldValue.serverTimestamp(),
        'addedBy': 'invitation',
        'invitationId': invitation.id,
      };

      // Add recipient as emergency contact for sender
      final senderContactData = {
        'userId': invitation.senderUserId,
        'contactId': currentUser.uid,
        'name': recipientName,
        'email': currentUser.email,
        'phoneNumber': '', // Will be populated when user updates profile
        'relationship': _getReciprocalRelationship(invitation.relationship),
        'isEmergencyContact': true,
        'addedAt': FieldValue.serverTimestamp(),
        'addedBy': 'invitation',
        'invitationId': invitation.id,
      };

      // Use batch write for atomicity
      batch.set(
        _firestore.collection('emergencyContacts').doc(),
        recipientContactData,
      );
      batch.set(
        _firestore.collection('emergencyContacts').doc(),
        senderContactData,
      );

      await batch.commit();
      debugPrint('Mutual emergency contact relationship created');
    } catch (e) {
      debugPrint('Error creating mutual emergency contact: $e');
      rethrow;
    }
  }

  /// Gets the reciprocal relationship type
  String _getReciprocalRelationship(String relationship) {
    final reciprocalMap = {
      'Parent': 'Child',
      'Child': 'Parent',
      'Spouse': 'Spouse',
      'Partner': 'Partner',
      'Sibling': 'Sibling',
      'Friend': 'Friend',
      'Colleague': 'Colleague',
      'Neighbor': 'Neighbor',
      'Family': 'Family',
      'Contact': 'Contact',
      'Other': 'Other',
    };
    return reciprocalMap[relationship] ?? 'Contact';
  }

  /// Checks if an invitation already exists between two users
  Future<EmergencyInvitation?> _checkExistingInvitationByUsername(
    String senderUserId,
    String recipientUserId,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection('invitations')
          .where('senderUserId', isEqualTo: senderUserId)
          .where('recipientUserId', isEqualTo: recipientUserId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return EmergencyInvitation.fromMap(doc.data(), doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error checking existing invitation: $e');
      return null;
    }
  }
}
