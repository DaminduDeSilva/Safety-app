/// Data model for real-time notifications sent to live guardians
///
/// This model represents notifications stored in Firebase Realtime Database
/// under the path: notifications/<guardian_id>/<sender_id>
class RealtimeNotification {
  final String id;
  final String senderId;
  final String senderName;
  final String guardianId;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String type; // 'emergency', 'location_share', 'general'
  final Map<String, dynamic>? metadata;

  const RealtimeNotification({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.guardianId,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.type = 'emergency',
    this.metadata,
  });

  /// Creates a RealtimeNotification from Firebase Realtime Database data
  factory RealtimeNotification.fromMap(Map<dynamic, dynamic> map, String id) {
    return RealtimeNotification(
      id: id,
      senderId: map['senderId']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? '',
      guardianId: map['guardianId']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : DateTime.now(),
      isRead: map['isRead'] == true,
      type: map['type']?.toString() ?? 'emergency',
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'])
          : null,
    );
  }

  /// Converts the RealtimeNotification to a Map for Firebase Realtime Database
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'guardianId': guardianId,
      'message': message,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isRead': isRead,
      'type': type,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Creates a copy of this notification with updated fields
  RealtimeNotification copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? guardianId,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? type,
    Map<String, dynamic>? metadata,
  }) {
    return RealtimeNotification(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      guardianId: guardianId ?? this.guardianId,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
    );
  }
}
