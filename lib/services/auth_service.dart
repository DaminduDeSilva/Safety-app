import 'package:firebase_auth/firebase_auth.dart';
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
