import 'package:flutter/material.dart';
import '../screens/contacts_screen.dart';
import '../services/invitation_service.dart';

/// Widget that provides a prominent "Add Guardian" button with multiple invitation options.
///
/// Implements the streamlined invitation flow by providing quick access to:
/// - Send invitation by username
/// - Browse contacts to invite
/// - QR code scanning (future feature)
class AddGuardianButton extends StatelessWidget {
  final InvitationService _invitationService = InvitationService();

  AddGuardianButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.person_add, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  'Add Guardian',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Invite someone to be your emergency contact and share live locations.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),

            // Primary Add Guardian Button
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _showAddGuardianDialog(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text(
                  'Add Guardian',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Secondary Actions Row
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ContactsScreen(),
                      ),
                    ),
                    icon: Icon(Icons.contacts, color: Colors.blue[700]),
                    label: Text(
                      'Manage Contacts',
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                  ),
                ),
                Container(height: 20, width: 1, color: Colors.grey[300]),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showQRCodeInfo(context),
                    icon: Icon(Icons.qr_code, color: Colors.orange[700]),
                    label: Text(
                      'QR Code',
                      style: TextStyle(color: Colors.orange[700]),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Shows the Add Guardian dialog with username input.
  void _showAddGuardianDialog(BuildContext context) {
    final usernameController = TextEditingController();
    final relationshipController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Guardian'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter their username',
                  prefixIcon: Icon(Icons.person),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: relationshipController,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  hintText: 'e.g., Parent, Friend, Spouse',
                  prefixIcon: Icon(Icons.family_restroom),
                ),
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final username = usernameController.text.trim();
                      final relationship = relationshipController.text.trim();

                      if (username.isEmpty || relationship.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill in all fields'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      try {
                        await _invitationService.sendInvitationByUsername(
                          recipientUsername: username,
                          relationship: relationship,
                        );

                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Invitation sent to $username!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to send invitation: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Send Invitation'),
            ),
          ],
        ),
      ),
    );
  }

  /// Shows information about QR code feature (placeholder).
  void _showQRCodeInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QR Code Feature'),
        content: const Text(
          'QR code scanning for quick guardian addition is coming soon! '
          'For now, you can add guardians using their username.',
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
