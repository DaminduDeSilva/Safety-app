/// Data model representing a user in the application.
///
/// This model corresponds to user documents stored in Firestore and contains
/// essential user information for the safety app.
class UserModel {
  /// Unique identifier for the user (matches Firebase Auth UID)
  final String uid;

  /// User's email address
  final String email;

  /// Optional display name for the user
  final String? displayName;

  /// Optional phone number for the user
  final String? phoneNumber;

  /// Optional profile photo URL
  final String? photoURL;

  /// Timestamp when the user account was created
  final DateTime createdAt;

  /// Creates a new [UserModel] instance.
  const UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.phoneNumber,
    this.photoURL,
    required this.createdAt,
  });

  /// Creates a [UserModel] from a Firestore document map.
  ///
  /// The [map] parameter should contain the document data from Firestore.
  /// The [uid] parameter is typically the document ID from Firestore.
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] as String,
      displayName: map['displayName'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      photoURL: map['photoURL'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  /// Converts the [UserModel] to a map suitable for Firestore storage.
  ///
  /// Note: The UID is not included in the map as it serves as the document ID.
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'photoURL': photoURL,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Creates a copy of this [UserModel] with the given fields replaced.
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? photoURL,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, displayName: $displayName, phoneNumber: $phoneNumber, photoURL: $photoURL, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.uid == uid &&
        other.email == email &&
        other.displayName == displayName &&
        other.phoneNumber == phoneNumber &&
        other.photoURL == photoURL &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        email.hashCode ^
        displayName.hashCode ^
        phoneNumber.hashCode ^
        photoURL.hashCode ^
        createdAt.hashCode;
  }
}
