import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for emergency contact invitations
class EmergencyInvitation {
  final String id;
  final String senderUserId;
  final String senderName;
  final String senderEmail;
  final String recipientEmail;
  final String recipientName;
  final String relationship;
  final InvitationStatus status;
  final DateTime sentAt;
  final DateTime? respondedAt;
  final DateTime expiresAt;
  final String? message;
  final String inviteCode;

  const EmergencyInvitation({
    required this.id,
    required this.senderUserId,
    required this.senderName,
    required this.senderEmail,
    required this.recipientEmail,
    required this.recipientName,
    required this.relationship,
    this.status = InvitationStatus.pending,
    required this.sentAt,
    this.respondedAt,
    required this.expiresAt,
    this.message,
    required this.inviteCode,
  });

  factory EmergencyInvitation.fromMap(Map<String, dynamic> map, String id) {
    return EmergencyInvitation(
      id: id,
      senderUserId: map['senderUserId'] as String,
      senderName: map['senderName'] as String,
      senderEmail: map['senderEmail'] as String,
      recipientEmail: map['recipientEmail'] as String,
      recipientName: map['recipientName'] as String,
      relationship: map['relationship'] as String,
      status: InvitationStatus.values.firstWhere(
        (e) => e.toString() == 'InvitationStatus.${map['status']}',
        orElse: () => InvitationStatus.pending,
      ),
      sentAt: (map['sentAt'] as Timestamp).toDate(),
      respondedAt: map['respondedAt'] != null
          ? (map['respondedAt'] as Timestamp).toDate()
          : null,
      expiresAt: (map['expiresAt'] as Timestamp).toDate(),
      message: map['message'] as String?,
      inviteCode: map['inviteCode'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderUserId': senderUserId,
      'senderName': senderName,
      'senderEmail': senderEmail,
      'recipientEmail': recipientEmail,
      'recipientName': recipientName,
      'relationship': relationship,
      'status': status.toString().split('.').last,
      'sentAt': Timestamp.fromDate(sentAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'message': message,
      'inviteCode': inviteCode,
    };
  }

  EmergencyInvitation copyWith({
    String? id,
    String? senderUserId,
    String? senderName,
    String? senderEmail,
    String? recipientEmail,
    String? recipientName,
    String? relationship,
    InvitationStatus? status,
    DateTime? sentAt,
    DateTime? respondedAt,
    DateTime? expiresAt,
    String? message,
    String? inviteCode,
  }) {
    return EmergencyInvitation(
      id: id ?? this.id,
      senderUserId: senderUserId ?? this.senderUserId,
      senderName: senderName ?? this.senderName,
      senderEmail: senderEmail ?? this.senderEmail,
      recipientEmail: recipientEmail ?? this.recipientEmail,
      recipientName: recipientName ?? this.recipientName,
      relationship: relationship ?? this.relationship,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      respondedAt: respondedAt ?? this.respondedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      message: message ?? this.message,
      inviteCode: inviteCode ?? this.inviteCode,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isPending => status == InvitationStatus.pending && !isExpired;
}

enum InvitationStatus {
  pending,
  accepted,
  declined,
  ignored,
  expired,
  cancelled,
}

/// Model for invitation email templates
class InvitationEmailTemplate {
  final String subject;
  final String htmlBody;
  final String textBody;

  const InvitationEmailTemplate({
    required this.subject,
    required this.htmlBody,
    required this.textBody,
  });

  static InvitationEmailTemplate createTemplate({
    required String senderName,
    required String relationship,
    required String inviteCode,
    required String acceptUrl,
    String? personalMessage,
  }) {
    final subject = '$senderName invited you to be their emergency contact';
    
    final htmlBody = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Emergency Contact Invitation</title>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #e74c3c; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
        .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 8px 8px; }
        .button { display: inline-block; background: #27ae60; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; margin: 20px 0; }
        .code { background: #ecf0f1; padding: 10px; border-left: 4px solid #3498db; margin: 15px 0; font-family: monospace; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; font-size: 12px; color: #666; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚨 Emergency Contact Invitation</h1>
        </div>
        <div class="content">
            <h2>Hello,</h2>
            
            <p><strong>$senderName</strong> has invited you to be their emergency contact with the relationship: <strong>$relationship</strong>.</p>
            
            ${personalMessage != null ? '<div class="code"><strong>Personal Message:</strong><br>$personalMessage</div>' : ''}
            
            <p>By accepting this invitation, you will:</p>
            <ul>
                <li>📱 Receive emergency notifications if $senderName needs help</li>
                <li>📍 See their location during emergencies</li>
                <li>⚡ Be able to respond quickly to assist them</li>
                <li>📞 Have direct access to emergency communication</li>
            </ul>
            
            <p>To accept this invitation, you can either:</p>
            
            <div style="text-align: center;">
                <a href="$acceptUrl" class="button">Accept Invitation</a>
            </div>
            
            <p>Or use this invitation code in the Safety App:</p>
            <div class="code">
                <strong>Invitation Code:</strong> $inviteCode
            </div>
            
            <p><strong>Important:</strong> This invitation will expire in 7 days. Please respond as soon as possible.</p>
            
            <p>If you don't have the Safety App yet, download it from:</p>
            <ul>
                <li>📱 Google Play Store: [App Link]</li>
                <li>🍎 Apple App Store: [App Link]</li>
            </ul>
            
            <div class="footer">
                <p>This invitation was sent by $senderName through the Safety App.<br>
                If you didn't expect this invitation, you can safely ignore this email.</p>
            </div>
        </div>
    </div>
</body>
</html>
    ''';

    final textBody = '''
Emergency Contact Invitation

Hello,

$senderName has invited you to be their emergency contact with the relationship: $relationship.

${personalMessage != null ? 'Personal Message: $personalMessage\n' : ''}

By accepting this invitation, you will:
- Receive emergency notifications if $senderName needs help
- See their location during emergencies
- Be able to respond quickly to assist them
- Have direct access to emergency communication

To accept this invitation:
1. Download the Safety App from Google Play Store or Apple App Store
2. Create an account or sign in
3. Go to "Emergency Contacts" -> "Accept Invitation"
4. Enter this invitation code: $inviteCode

Or use this direct link: $acceptUrl

Important: This invitation will expire in 7 days. Please respond as soon as possible.

If you didn't expect this invitation, you can safely ignore this email.

---
This invitation was sent by $senderName through the Safety App.
    ''';

    return InvitationEmailTemplate(
      subject: subject,
      htmlBody: htmlBody,
      textBody: textBody,
    );
  }
}
