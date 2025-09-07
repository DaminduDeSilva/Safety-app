import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/emergency_invitation.dart';
import '../services/invitation_service.dart';

/// Screen for managing emergency contact invitations
class InvitationScreen extends StatefulWidget {
  const InvitationScreen({super.key});

  @override
  State<InvitationScreen> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends State<InvitationScreen>
    with SingleTickerProviderStateMixin {
  final InvitationService _invitationService = InvitationService();
  late TabController _tabController;

  List<EmergencyInvitation> _sentInvitations = [];
  List<EmergencyInvitation> _receivedInvitations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInvitations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInvitations() async {
    setState(() => _isLoading = true);
    
    try {
      final sent = await _invitationService.getSentInvitations();
      final received = await _invitationService.getReceivedInvitations();
      
      setState(() {
        _sentInvitations = sent;
        _receivedInvitations = received;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading invitations: $e')),
        );
      }
    }
  }

  Future<void> _debugUserValidation() async {
    // Debug current user
    await _invitationService.debugCurrentUserDetails();
    
    // Test with a known email - replace with the email you're testing
    const testEmail = 'anuradhashanukapanagoda0@gmail.com'; // Replace with actual email
    final result = await _invitationService.testUserValidation(testEmail);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User validation test for $testEmail: $result'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Invitations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug User Validation',
            onPressed: _debugUserValidation,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.send),
              text: 'Send Invite',
            ),
            Tab(
              icon: const Icon(Icons.inbox),
              text: 'Received (${_receivedInvitations.length})',
            ),
            Tab(
              icon: const Icon(Icons.outbox),
              text: 'Sent (${_sentInvitations.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSendInviteTab(),
          _buildReceivedInvitationsTab(),
          _buildSentInvitationsTab(),
        ],
      ),
    );
  }

  Widget _buildSendInviteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('About Emergency Contacts', 
                           style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Invite trusted friends and family to be your emergency contacts. '
                    'They will receive notifications during emergencies and can help assist you.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showSendInviteDialog(),
            icon: const Icon(Icons.person_add),
            label: const Text('Send New Invitation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showAcceptInviteDialog(),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Accept Invitation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceivedInvitationsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_receivedInvitations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No pending invitations', 
                 style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('When someone invites you as their emergency contact,\nit will appear here.',
                 textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInvitations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _receivedInvitations.length,
        itemBuilder: (context, index) {
          final invitation = _receivedInvitations[index];
          return _buildReceivedInvitationCard(invitation);
        },
      ),
    );
  }

  Widget _buildSentInvitationsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_sentInvitations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.outbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No invitations sent', 
                 style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('Send invitations to friends and family\nto add them as emergency contacts.',
                 textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInvitations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sentInvitations.length,
        itemBuilder: (context, index) {
          final invitation = _sentInvitations[index];
          return _buildSentInvitationCard(invitation);
        },
      ),
    );
  }

  Widget _buildReceivedInvitationCard(EmergencyInvitation invitation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(invitation.senderName[0].toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.senderName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'wants to add you as: ${invitation.relationship}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (invitation.message != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(invitation.message!),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Expires: ${_formatDate(invitation.expiresAt)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _ignoreInvitation(invitation),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                    ),
                    child: const Text('Ignore'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptInvitation(invitation),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentInvitationCard(EmergencyInvitation invitation) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (invitation.status) {
      case InvitationStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.access_time;
        statusText = 'Pending';
        break;
      case InvitationStatus.accepted:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Accepted';
        break;
      case InvitationStatus.declined:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Declined';
        break;
      case InvitationStatus.ignored:
        statusColor = Colors.grey;
        statusIcon = Icons.visibility_off;
        statusText = 'Ignored';
        break;
      case InvitationStatus.expired:
        statusColor = Colors.grey;
        statusIcon = Icons.schedule;
        statusText = 'Expired';
        break;
      case InvitationStatus.cancelled:
        statusColor = Colors.grey;
        statusIcon = Icons.block;
        statusText = 'Cancelled';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  child: invitation.recipientEmail.isNotEmpty 
                    ? Text(invitation.recipientEmail[0].toUpperCase())
                    : const Icon(Icons.person),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.recipientEmail,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Relationship: ${invitation.relationship}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 20),
                    Text(statusText, style: TextStyle(color: statusColor, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Code: ${invitation.inviteCode}',
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                IconButton(
                  onPressed: () => _copyInviteCode(invitation.inviteCode),
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: 'Copy code',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Sent: ${_formatDate(invitation.sentAt)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            if (invitation.status == InvitationStatus.pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _resendInvitation(invitation),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Resend'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _cancelInvitation(invitation),
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSendInviteDialog() {
    final formKey = GlobalKey<FormState>();
    final emailController = TextEditingController();
    final messageController = TextEditingController();
    String selectedRelationship = 'Contact';

    final relationships = [
      'Contact', 'Friend', 'Family', 'Spouse', 'Parent', 'Child', 'Sibling',
      'Colleague', 'Neighbor', 'Partner', 'Other'
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Emergency Contact Invitation'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    hintText: 'Enter their email address',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value?.trim().isEmpty ?? true) {
                      return 'Email is required';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedRelationship,
                  decoration: const InputDecoration(
                    labelText: 'Relationship (Optional)',
                    prefixIcon: Icon(Icons.people),
                  ),
                  items: relationships.map((relationship) {
                    return DropdownMenuItem(
                      value: relationship,
                      child: Text(relationship),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedRelationship = value!;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Personal Message (Optional)',
                    hintText: 'Add a personal note...',
                    prefixIcon: Icon(Icons.message),
                  ),
                  maxLines: 3,
                  maxLength: 200,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop();
                await _sendInvitation(
                  emailController.text.trim(),
                  selectedRelationship,
                  messageController.text.trim().isEmpty 
                    ? null 
                    : messageController.text.trim(),
                );
              }
            },
            child: const Text('Send Invitation'),
          ),
        ],
      ),
    );
  }

  void _showAcceptInviteDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Invitation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the invitation code you received:'),
            const SizedBox(height: 16),
            TextFormField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Invitation Code',
                hintText: 'Enter 8-character code',
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.length == 8) {
                Navigator.of(context).pop();
                await _acceptInvitationByCode(code);
              }
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendInvitation(String email, String relationship, String? message) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Sending invitation...'),
            ],
          ),
        ),
      );

      await _invitationService.sendInvitation(
        recipientEmail: email,
        relationship: relationship,
        personalMessage: message,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation sent! The recipient can accept it in their app.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadInvitations();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending invitation: $e')),
        );
      }
    }
  }

  Future<void> _acceptInvitation(EmergencyInvitation invitation) async {
    try {
      await _invitationService.acceptInvitation(invitation.inviteCode);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation accepted! Emergency contact added.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadInvitations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting invitation: $e')),
        );
      }
    }
  }

  Future<void> _acceptInvitationByCode(String code) async {
    try {
      await _invitationService.acceptInvitation(code);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation accepted! Emergency contact added.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadInvitations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _declineInvitation(EmergencyInvitation invitation) async {
    try {
      await _invitationService.declineInvitation(invitation.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation declined')),
        );
        _loadInvitations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error declining invitation: $e')),
        );
      }
    }
  }

  Future<void> _ignoreInvitation(EmergencyInvitation invitation) async {
    try {
      await _invitationService.ignoreInvitation(invitation.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation ignored'),
            backgroundColor: Colors.grey,
          ),
        );
        _loadInvitations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ignoring invitation: $e')),
        );
      }
    }
  }

  Future<void> _resendInvitation(EmergencyInvitation invitation) async {
    try {
      await _invitationService.resendInvitation(invitation.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation refreshed! Extended expiry date.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadInvitations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resending invitation: $e')),
        );
      }
    }
  }

  Future<void> _cancelInvitation(EmergencyInvitation invitation) async {
    try {
      await _invitationService.cancelInvitation(invitation.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation cancelled')),
        );
        _loadInvitations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling invitation: $e')),
        );
      }
    }
  }

  void _copyInviteCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code copied to clipboard')),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
