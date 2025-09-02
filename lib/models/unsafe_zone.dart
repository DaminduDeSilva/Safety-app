/// Data model representing an unsafe zone reported by users.
///
/// Unsafe zones are locations that users have identified as potentially
/// dangerous or unsafe, helping other users avoid these areas.
class UnsafeZone {
  /// Unique identifier for this unsafe zone
  final String id;

  /// UID of the user who originally reported this unsafe zone
  final String userId;

  /// Latitude coordinate of the unsafe zone
  final double latitude;

  /// Longitude coordinate of the unsafe zone
  final double longitude;

  /// Reason why this zone is considered unsafe
  final String reason;

  /// Timestamp when this unsafe zone was first reported
  final DateTime timestamp;

  /// Whether this unsafe zone has been verified by authorities or multiple users
  final bool verified;

  /// Number of users who have verified this unsafe zone
  final int verificationCount;

  /// Creates a new [UnsafeZone] instance.
  const UnsafeZone({
    required this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.reason,
    required this.timestamp,
    this.verified = false,
    this.verificationCount = 0,
  });

  /// Creates an [UnsafeZone] from a Firestore document map.
  ///
  /// The [map] parameter should contain the document data from Firestore.
  /// The [id] parameter is typically the document ID from Firestore.
  factory UnsafeZone.fromMap(Map<String, dynamic> map, String id) {
    return UnsafeZone(
      id: id,
      userId: map['userId'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      reason: map['reason'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      verified: map['verified'] as bool? ?? false,
      verificationCount: map['verificationCount'] as int? ?? 0,
    );
  }

  /// Converts the [UnsafeZone] to a map suitable for Firestore storage.
  ///
  /// Note: The ID is not included in the map as it serves as the document ID.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'reason': reason,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'verified': verified,
      'verificationCount': verificationCount,
    };
  }

  /// Creates a copy of this [UnsafeZone] with the given fields replaced.
  UnsafeZone copyWith({
    String? id,
    String? userId,
    double? latitude,
    double? longitude,
    String? reason,
    DateTime? timestamp,
    bool? verified,
    int? verificationCount,
  }) {
    return UnsafeZone(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      reason: reason ?? this.reason,
      timestamp: timestamp ?? this.timestamp,
      verified: verified ?? this.verified,
      verificationCount: verificationCount ?? this.verificationCount,
    );
  }

  @override
  String toString() {
    return 'UnsafeZone(id: $id, userId: $userId, latitude: $latitude, longitude: $longitude, reason: $reason, timestamp: $timestamp, verified: $verified, verificationCount: $verificationCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UnsafeZone &&
        other.id == id &&
        other.userId == userId &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.reason == reason &&
        other.timestamp == timestamp &&
        other.verified == verified &&
        other.verificationCount == verificationCount;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        latitude.hashCode ^
        longitude.hashCode ^
        reason.hashCode ^
        timestamp.hashCode ^
        verified.hashCode ^
        verificationCount.hashCode;
  }
}
