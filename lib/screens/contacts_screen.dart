import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/emergency_contact.dart';
import '../services/database_service.dart';

/// Screen for managing emergency contacts.
///
/// Allows users to view, add, and delete their emergency contacts
/// that will be notified during an emergency.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final DatabaseService _databaseService = DatabaseService();

  /// Requests contacts permission and imports contacts from phone
  Future<void> _importContactsFromPhone() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checking contacts permission...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      bool permissionGranted = false;

      // First check current permission status
      try {
        final currentStatus = await Permission.contacts.status;
        print('Current permission status: $currentStatus');

        if (currentStatus == PermissionStatus.granted) {
          permissionGranted = true;
          print('Permission already granted');
        }
      } catch (e) {
        print('Error checking current permission status: $e');
      }

      // If not granted, try to request permission
      if (!permissionGranted) {
        try {
          print('Requesting permission via flutter_contacts...');
          permissionGranted = await FlutterContacts.requestPermission();
          print(
            'FlutterContacts.requestPermission() returned: $permissionGranted',
          );
        } catch (e) {
          print('FlutterContacts.requestPermission() error: $e');
        }

        // Fallback to permission_handler if flutter_contacts failed
        if (!permissionGranted) {
          try {
            print('Requesting permission via permission_handler...');
            final status = await Permission.contacts.request();
            permissionGranted = status == PermissionStatus.granted;
            print('Permission.contacts.request() returned: $status');
          } catch (e) {
            print('Permission.contacts.request() error: $e');
          }
        }
      }

      // Final test: try to actually access contacts to verify permission
      if (!permissionGranted) {
        print('Permission not confirmed, testing by accessing contacts...');
        try {
          final testContacts = await FlutterContacts.getContacts(
            withProperties: false,
          );
          permissionGranted = true;
          print(
            'Permission test successful - can access ${testContacts.length} contacts',
          );
        } catch (e) {
          print('Permission test failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contacts permission denied',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text('To import contacts:'),
                    Text('1. Go to Settings > Apps > Safety App'),
                    Text('2. Enable Contacts permission'),
                    Text('3. Return and try again'),
                  ],
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 8),
                action: SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () async {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    await openAppSettings();
                  },
                ),
              ),
            );
          }
          return;
        }
      }

      print('Permission granted, proceeding to get contacts...');

      // Get contacts from phone
      final List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      if (contacts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No contacts found on your device')),
          );
        }
        return;
      }

      // Filter contacts that have phone numbers
      final List<Contact> contactsWithPhones = contacts
          .where(
            (contact) =>
                contact.phones.isNotEmpty && contact.displayName.isNotEmpty,
          )
          .toList();

      if (contactsWithPhones.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No contacts with phone numbers found'),
            ),
          );
        }
        return;
      }

      // Show contact selection dialog
      if (mounted) {
        _showContactSelectionDialog(contactsWithPhones);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error importing contacts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Shows dialog to select contacts to import
  Future<void> _showContactSelectionDialog(List<Contact> contacts) async {
    final List<Contact> selectedContacts = [];

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Contacts to Import'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    Text(
                      '${selectedContacts.length} contact(s) selected',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: contacts.length,
                        itemBuilder: (context, index) {
                          final contact = contacts[index];
                          final isSelected = selectedContacts.contains(contact);
                          final phoneNumber = contact.phones.first.number;

                          return CheckboxListTile(
                            title: Text(contact.displayName),
                            subtitle: Text(phoneNumber),
                            value: isSelected,
                            onChanged: (bool? selected) {
                              setState(() {
                                if (selected == true) {
                                  selectedContacts.add(contact);
                                } else {
                                  selectedContacts.remove(contact);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedContacts.isEmpty
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          _addSelectedContacts(selectedContacts);
                        },
                  child: const Text('Import Selected'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Adds selected contacts to emergency contacts
  Future<void> _addSelectedContacts(List<Contact> selectedContacts) async {
    int successCount = 0;
    int errorCount = 0;

    for (final contact in selectedContacts) {
      try {
        final phoneNumber = contact.phones.first.number;
        final name = contact.displayName;

        // Clean phone number (remove spaces, dashes, parentheses)
        final cleanedPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

        if (cleanedPhone.isEmpty) {
          errorCount++;
          continue;
        }

        final emergencyContact = EmergencyContact(
          id: '', // Will be auto-generated by Firestore
          name: name,
          phoneNumber: cleanedPhone,
          relationship: 'Imported Contact', // Default relationship
          isPrimary: false, // Imported contacts are not primary by default
        );

        await _databaseService.addEmergencyContact(emergencyContact);
        successCount++;
      } catch (e) {
        errorCount++;
      }
    }

    // Show result
    if (mounted) {
      String message;
      Color backgroundColor;

      if (errorCount == 0) {
        message = 'Successfully imported $successCount contact(s)';
        backgroundColor = Colors.green;
      } else if (successCount == 0) {
        message = 'Failed to import any contacts';
        backgroundColor = Colors.red;
      } else {
        message = 'Imported $successCount contact(s), $errorCount failed';
        backgroundColor = Colors.orange;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: backgroundColor),
      );
    }
  }

  /// Shows the add contact dialog
  Future<void> _showAddContactDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final relationshipController = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withOpacity(0.1), width: 2),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(8, 8),
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 0,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Add Emergency Contact',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                        fontFamily: 'Inter',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    // Name Field
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black.withOpacity(0.1), width: 2),
                        boxShadow: [
                          BoxShadow(
                            offset: const Offset(2, 2),
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: nameController,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          hintText: 'e.g., John Doe',
                          prefixIcon: Icon(
                            Icons.person_rounded,
                            color: Color(0xFF2563EB),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                          labelStyle: TextStyle(
                            color: Color(0xFF6B7280),
                            fontFamily: 'Inter',
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a name';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Phone Field
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black.withOpacity(0.1), width: 2),
                        boxShadow: [
                          BoxShadow(
                            offset: const Offset(2, 2),
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: phoneController,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          hintText: 'e.g., +1 (555) 123-4567',
                          prefixIcon: Icon(
                            Icons.phone_rounded,
                            color: Color(0xFF2563EB),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                          labelStyle: TextStyle(
                            color: Color(0xFF6B7280),
                            fontFamily: 'Inter',
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9+\-\(\)\s]'),
                          ),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a phone number';
                          }
                          // Basic phone number validation
                          final cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');
                          if (cleanPhone.length < 10) {
                            return 'Please enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Relationship Field
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black.withOpacity(0.1), width: 2),
                        boxShadow: [
                          BoxShadow(
                            offset: const Offset(2, 2),
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: TextFormField(
                        controller: relationshipController,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Relationship',
                          hintText: 'e.g., Parent, Friend, Sibling',
                          prefixIcon: Icon(
                            Icons.family_restroom_rounded,
                            color: Color(0xFF2563EB),
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                          labelStyle: TextStyle(
                            color: Color(0xFF6B7280),
                            fontFamily: 'Inter',
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your relationship';
                          }
                          return null;
                        },
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  offset: const Offset(2, 2),
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: Colors.black, width: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Inter',
                                  color: Color(0xFF374151),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  offset: const Offset(4, 4),
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () async {
                                if (formKey.currentState!.validate()) {
                                  try {
                                    final contact = EmergencyContact(
                                      id: '', // Will be set by Firestore
                                      name: nameController.text.trim(),
                                      phoneNumber: phoneController.text.trim(),
                                      relationship: relationshipController.text.trim(),
                                      isPrimary: false, // Can be modified later if needed
                                    );

                                    await _databaseService.addEmergencyContact(contact);

                                    if (mounted) {
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('${contact.name} added successfully!'),
                                          backgroundColor: const Color(0xFF10B981),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Failed to add contact: ${e.toString()}',
                                          ),
                                          backgroundColor: const Color(0xFFDC2626),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: Colors.black, width: 2),
                                ),
                              ),
                              child: const Text(
                                'Save Contact',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Shows confirmation dialog before deleting a contact
  Future<void> _showDeleteConfirmation(EmergencyContact contact) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Contact'),
          content: Text('Are you sure you want to delete ${contact.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _databaseService.deleteEmergencyContact(contact.id);

                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${contact.name} deleted successfully!'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to delete contact: ${e.toString()}',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds a contact list item
  Widget _buildContactTile(EmergencyContact contact) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.1), width: 2),
        boxShadow: [
          BoxShadow(
            offset: const Offset(4, 4),
            color: Colors.black.withOpacity(0.25),
            blurRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(2, 2),
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF111827),
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contact.phoneNumber,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      contact.relationship,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.2)),
              ),
              child: IconButton(
                onPressed: () => _showDeleteConfirmation(contact),
                icon: const Icon(Icons.delete_rounded, color: Color(0xFFDC2626)),
                tooltip: 'Delete Contact',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
        centerTitle: true,
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(2, 2),
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 0,
                ),
              ],
            ),
            child: IconButton(
              onPressed: _importContactsFromPhone,
              icon: const Icon(Icons.contact_phone, color: Color(0xFF10B981)),
              tooltip: 'Import from Phone',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(2, 2),
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 0,
                ),
              ],
            ),
            child: IconButton(
              onPressed: _showAddContactDialog,
              icon: const Icon(Icons.add, color: Color(0xFF2563EB)),
              tooltip: 'Add Contact',
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<EmergencyContact>>(
        stream: _databaseService.getEmergencyContactsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2563EB),
                strokeWidth: 3,
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(6, 6),
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Error Loading Contacts',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Unable to load your emergency contacts. Please try again.',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontFamily: 'Inter',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            offset: const Offset(2, 2),
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => setState(() {}),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.black, width: 2),
                          ),
                        ),
                        child: const Text(
                          'Retry',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final contacts = snapshot.data ?? [];

          if (contacts.isEmpty) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black.withOpacity(0.1), width: 2),
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(8, 8),
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B7280).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.contacts_rounded,
                        size: 64,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'No Emergency Contacts',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Add trusted contacts who will be notified during emergencies. They\'ll receive your location and status updates.',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontFamily: 'Inter',
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            offset: const Offset(4, 4),
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _showAddContactDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.black, width: 2),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text(
                          'Add Your First Contact',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: const Color(0xFF2563EB),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: const Text(
                        'These contacts will receive SMS alerts when you use the SOS button.',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    return _buildContactTile(contacts[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              offset: const Offset(4, 4),
              color: Colors.black.withOpacity(0.25),
              blurRadius: 0,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showAddContactDialog,
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.black, width: 2),
          ),
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }
}
