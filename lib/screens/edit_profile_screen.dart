import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';

/// Screen for editing user profile information.
///
/// Allows users to update their first name, last name, and phone number.
/// Username and email are read-only for security and consistency reasons.
/// Validates input fields and provides real-time feedback.
class EditProfileScreen extends StatefulWidget {
  final UserModel userProfile;

  const EditProfileScreen({super.key, required this.userProfile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _databaseService = DatabaseService();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneNumberController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with current user data
    _firstNameController = TextEditingController(
      text: widget.userProfile.firstName,
    );
    _lastNameController = TextEditingController(
      text: widget.userProfile.lastName,
    );
    _phoneNumberController = TextEditingController(
      text: widget.userProfile.phoneNumber,
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  /// Validates the profile form
  String? _validateField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validates phone number format
  String? _validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }

    final phoneNumber = value.trim();

    // Basic phone number validation (adjust regex based on requirements)
    if (!RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(phoneNumber)) {
      return 'Please enter a valid phone number';
    }

    if (phoneNumber.replaceAll(RegExp(r'[\s\-\(\)+]'), '').length < 10) {
      return 'Phone number must be at least 10 digits';
    }

    return null;
  }

  /// Saves the updated profile
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create updated user model
      final updatedUser = widget.userProfile.copyWith(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(),
        updatedAt: DateTime.now(),
      );

      // Update in database
      await _databaseService.updateUser(updatedUser);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Return updated user to previous screen
        Navigator.of(context).pop(updatedUser);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Checks if any field has been modified
  bool _hasChanges() {
    return _firstNameController.text.trim() != widget.userProfile.firstName ||
        _lastNameController.text.trim() != widget.userProfile.lastName ||
        _phoneNumberController.text.trim() != widget.userProfile.phoneNumber;
  }

  /// Shows unsaved changes dialog
  Future<bool> _showUnsavedChangesDialog() async {
    if (!_hasChanges()) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave without saving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        final shouldPop = await _showUnsavedChangesDialog();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Edit Profile',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            if (_hasChanges())
              TextButton(
                onPressed: _isLoading ? null : _saveProfile,
                child: Text(
                  'Save',
                  style: TextStyle(
                    color: _isLoading ? Colors.grey : Colors.blue[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Profile Avatar Section
                      _buildProfileAvatarSection(),

                      const SizedBox(height: 24),

                      // Form Fields
                      _buildFormFields(),

                      const SizedBox(height: 32),

                      // Save Button
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// Builds the profile avatar section
  Widget _buildProfileAvatarSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue[100],
                child: Text(
                  _firstNameController.text.isNotEmpty
                      ? _firstNameController.text.substring(0, 1).toUpperCase()
                      : widget.userProfile.firstName
                            .substring(0, 1)
                            .toUpperCase(),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () {
                      // TODO: Implement photo upload
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Photo upload coming soon!'),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tap camera icon to change photo',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  /// Builds the form fields section
  Widget _buildFormFields() {
    return Column(
      children: [
        // Username Field (Read-only)
        _buildReadOnlyField(
          label: 'Username',
          value: widget.userProfile.username,
          icon: Icons.alternate_email,
          subtitle: 'Username cannot be changed',
        ),

        const SizedBox(height: 16),

        // First Name Field
        _buildTextField(
          controller: _firstNameController,
          label: 'First Name',
          icon: Icons.person_outline,
          validator: (value) => _validateField(value, 'First name'),
        ),

        const SizedBox(height: 16),

        // Last Name Field
        _buildTextField(
          controller: _lastNameController,
          label: 'Last Name',
          icon: Icons.person_outline,
          validator: (value) => _validateField(value, 'Last name'),
        ),

        const SizedBox(height: 16),

        // Phone Number Field
        _buildTextField(
          controller: _phoneNumberController,
          label: 'Phone Number',
          icon: Icons.phone_outlined,
          validator: _validatePhoneNumber,
          keyboardType: TextInputType.phone,
        ),

        const SizedBox(height: 16),

        // Email Field (Read-only)
        _buildReadOnlyField(
          label: 'Email',
          value: widget.userProfile.email,
          icon: Icons.email_outlined,
          subtitle: 'Email cannot be changed',
        ),
      ],
    );
  }

  /// Builds a standard text field
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: validator,
      keyboardType: keyboardType,
    );
  }

  /// Builds a read-only field
  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
    String? subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: value,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey[100],
          ),
          readOnly: true,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ],
    );
  }

  /// Builds the save button
  Widget _buildSaveButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: (_isLoading || !_hasChanges()) ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[600],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save),
        label: Text(
          _isLoading ? 'Saving...' : 'Save Changes',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}
