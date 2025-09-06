import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a user's live location sharing session.
class LiveLocation {
  final String userId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String status; // 'active', 'paused', 'finished'
  final String? address;

  LiveLocation({
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.status,
    this.address,
  });

  /// Creates a LiveLocation from a Firestore document.
  factory LiveLocation.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LiveLocation(
      userId: doc.id,
      latitude: data['latitude']?.toDouble() ?? 0.0,
      longitude: data['longitude']?.toDouble() ?? 0.0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'active',
      address: data['address'],
    );
  }

  /// Converts a LiveLocation to a map for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
      'address': address,
    };
  }

  /// Creates a copy of this LiveLocation with updated fields.
  LiveLocation copyWith({
    String? userId,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    String? status,
    String? address,
  }) {
    return LiveLocation(
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      address: address ?? this.address,
    );
  }

  @override
  String toString() {
    return 'LiveLocation(userId: $userId, lat: $latitude, lng: $longitude, status: $status, timestamp: $timestamp)';
  }
}
