import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/sign_in_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/permission_request_screen.dart';
import 'services/database_service.dart';
import 'services/user_session_service.dart';
import 'services/permission_manager_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // Continue anyway, but note the error
  }

  runApp(const SafetyApp());
}

class SafetyApp extends StatelessWidget {
  const SafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safety App',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final DatabaseService _databaseService = DatabaseService();
  final UserSessionService _sessionService = UserSessionService();

  @override
  void initState() {
    super.initState();
    _initializeUserSession();
  }

  /// Initialize user session tracking
  void _initializeUserSession() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      _sessionService.updateFromFirebaseUser(user);
    });
  }

  /// Quick check for critical permissions (location)
  Future<bool> _checkCriticalPermissions() async {
    final permissionManager = PermissionManagerService();
    return await permissionManager.isLocationEnabled();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          // User is signed in, check if profile is complete
          return FutureBuilder<bool>(
            future: _databaseService.isProfileComplete(snapshot.data!.uid),
            builder: (context, profileSnapshot) {
              if (profileSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (profileSnapshot.data == true) {
                // Profile is complete, check permissions
                return FutureBuilder<bool>(
                  future: _checkCriticalPermissions(),
                  builder: (context, permissionSnapshot) {
                    if (permissionSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (permissionSnapshot.data == true) {
                      // Permissions OK, show main navigation
                      return const MainNavigationScreen();
                    } else {
                      // Need to request permissions
                      return const PermissionRequestScreen();
                    }
                  },
                );
              } else {
                // Profile is not complete, show profile setup screen
                return const ProfileSetupScreen();
              }
            },
          );
        } else {
          // User is not signed in, show sign in page
          return const SignInPage();
        }
      },
    );
  }
}
