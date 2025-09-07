import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';
import '../widgets/modern_app_bar.dart';
import 'edit_profile_screen.dart';

/// Screen for user profile management and app settings.
///
/// Displays user information, account settings, app preferences,
/// and provides access to help, support, and logout functionality.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _databaseService = DatabaseService();
  UserModel? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  /// Loads the current user's profile information
  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = await _databaseService.getUserProfile(user.uid);
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Navigates to the edit profile screen
  Future<void> _navigateToEditProfile() async {
    if (_userProfile == null) return;

    final updatedUser = await Navigator.of(context).push<UserModel>(
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(userProfile: _userProfile!),
      ),
    );

    // If user was updated, reload the profile
    if (updatedUser != null) {
      setState(() {
        _userProfile = updatedUser;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(title: 'Profile'),
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // User Profile Card
                  _buildProfileCard(),

                  const SizedBox(height: 20),

                  // Account Settings Section
                  _buildAccountSettingsSection(),

                  const SizedBox(height: 20),

                  // App Preferences Section
                  _buildAppPreferencesSection(),

                  const SizedBox(height: 20),

                  // Help & Support Section
                  _buildHelpSupportSection(),

                  const SizedBox(height: 20),

                  // Logout Button
                  _buildLogoutButton(),
                ],
              ),
            ),
    );
  }

  /// Builds the user profile information card
  Widget _buildProfileCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // User Avatar
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue[100],
              child: Text(
                _userProfile?.username.substring(0, 1).toUpperCase() ?? 'U',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Username
            Text(
              _userProfile?.username ?? 'Loading...',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            // Email
            Text(
              _userProfile?.email ??
                  FirebaseAuth.instance.currentUser?.email ??
                  '',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),

            const SizedBox(height: 16),

            // Member Since
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Text(
                'Member since ${_userProfile?.createdAt.year ?? DateTime.now().year}',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the account settings section
  Widget _buildAccountSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account Settings',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 12),

            _buildSettingItem(
              Icons.edit,
              'Edit Profile',
              'Update your username and personal information',
              () => _navigateToEditProfile(),
            ),

            _buildSettingItem(
              Icons.lock_outline,
              'Change Password',
              'Update your account password',
              () => _showComingSoonDialog('Change Password'),
            ),

            _buildSettingItem(
              Icons.security,
              'Privacy Settings',
              'Manage your privacy and data sharing preferences',
              () => _showComingSoonDialog('Privacy Settings'),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the app preferences section
  Widget _buildAppPreferencesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Preferences',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 12),

            _buildSettingItem(
              Icons.notifications_outlined,
              'Notifications',
              'Customize your notification preferences',
              () => _showComingSoonDialog('Notifications'),
            ),

            _buildSettingItem(
              Icons.location_on_outlined,
              'Location Settings',
              'Manage location sharing and accuracy',
              () => _showComingSoonDialog('Location Settings'),
            ),

            _buildSettingItem(
              Icons.dark_mode_outlined,
              'Theme',
              'Choose your preferred app theme',
              () => _showComingSoonDialog('Theme Settings'),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the help and support section
  Widget _buildHelpSupportSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help & Support',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 12),

            _buildSettingItem(
              Icons.help_outline,
              'Help Center',
              'Get answers to frequently asked questions',
              () => _showComingSoonDialog('Help Center'),
            ),

            _buildSettingItem(
              Icons.bug_report_outlined,
              'Report a Bug',
              'Report issues or provide feedback',
              () => _showComingSoonDialog('Bug Report'),
            ),

            _buildSettingItem(
              Icons.info_outline,
              'About',
              'App version and legal information',
              () => _showAboutDialog(),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a setting item with icon, title, subtitle, and tap handler
  Widget _buildSettingItem(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[600]),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  /// Builds the logout button
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _handleLogout,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[50],
          foregroundColor: Colors.red[700],
          side: BorderSide(color: Colors.red[200]!),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.logout),
        label: const Text(
          'Sign Out',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// Handles user logout
  Future<void> _handleLogout() async {
    final bool? confirm = await _showLogoutConfirmationDialog();
    if (confirm == true) {
      try {
        await AuthService.signOut();
        // Navigation will be handled automatically by AuthWrapper
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Shows logout confirmation dialog
  Future<bool?> _showLogoutConfirmationDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Shows coming soon dialog for features not yet implemented
  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: const Text(
          'This feature is coming soon! Stay tuned for updates.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Shows about dialog with app information
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Syntax Safety'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: 1.0.0'),
            SizedBox(height: 8),
            Text(
              'A comprehensive safety app designed to keep you and your loved ones safe through real-time location sharing and emergency alerts.',
            ),
            SizedBox(height: 12),
            Text('© 2025 Syntax Safety Team'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
