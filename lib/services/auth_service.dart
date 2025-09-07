import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static Stream<User?> get userStream =>
      FirebaseAuth.instance.authStateChanges();

  static Future<User?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      if (credential.user != null) {
        debugPrint('Sign in successful for user: ${credential.user!.email}');
        
        // Ensure user document exists and update last login
        await _createUserDocument(credential.user!);
      }

      return credential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Firebase Auth Exception during sign in: ${e.code} - ${e.message}',
      );
      // Re-throw the exception so the UI can handle error messages
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error during sign in: $e');
      // Re-throw the exception so the UI can handle error messages
      rethrow;
    }
  }

  static Future<User?> registerWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password.trim(),
          );

      if (credential.user != null) {
        debugPrint(
          'Registration successful for user: ${credential.user!.email}',
        );

        // Create user document in Firestore
        await _createUserDocument(credential.user!);
      }

      return credential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Firebase Auth Exception during registration: ${e.code} - ${e.message}',
      );
      // Re-throw the exception so the UI can handle error messages
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error during registration: $e');
      // Re-throw the exception so the UI can handle error messages
      rethrow;
    }
  }

  /// Creates a user document in Firestore
  static Future<void> _createUserDocument(User user) async {
    try {
      final firestore = FirebaseFirestore.instance;
      
      // Check if document already exists
      final userDoc = await firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        await firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email,
          'name': user.displayName ?? user.email?.split('@').first ?? 'Unknown User',
          'phoneNumber': user.phoneNumber ?? '',
          'photoURL': user.photoURL ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        
        debugPrint('User document created in Firestore');
      } else {
        // Update last login time
        await firestore.collection('users').doc(user.uid).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        
        debugPrint('User document updated with last login time');
      }
    } catch (e) {
      debugPrint('Error creating/updating user document: $e');
      // Don't throw here as the auth was successful
    }
  }

  static Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      debugPrint('User signed out successfully');
    } catch (e) {
      debugPrint('Error during sign out: $e');
      rethrow;
    }
  }

  // Helper method to get error message for UI display
  static String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}
