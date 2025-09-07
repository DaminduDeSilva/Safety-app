/// Data model representing a user in the application.
///
/// This model corresponds to user documents stored in Firestore and contains
/// essential user information for the safety app.
class UserModel {
  /// Unique identifier for the user (matches Firebase Auth UID)
  final String uid;

  /// User's email address
  final String email;

  /// Unique username for the user
  final String username;

  /// User's first name
  final String firstName;

  /// User's last name
  final String lastName;

  /// User's phone number
  final String phoneNumber;

  /// Optional profile photo URL
  final String? photoURL;

  /// Timestamp when the user account was created
  final DateTime createdAt;

  /// Timestamp when the profile was last updated
  final DateTime updatedAt;

  /// Creates a new [UserModel] instance.
  const UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.phoneNumber,
    this.photoURL,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Gets the full display name (first name + last name)
  String get displayName => '$firstName $lastName';

  /// Creates a [UserModel] from a Firestore document map.
  ///
  /// The [map] parameter should contain the document data from Firestore.
  /// The [uid] parameter is typically the document ID from Firestore.
  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] as String,
      username: map['username'] as String,
      firstName: map['firstName'] as String,
      lastName: map['lastName'] as String,
      phoneNumber: map['phoneNumber'] as String,
      photoURL: map['photoURL'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    );
  }

  /// Converts the [UserModel] to a map suitable for Firestore storage.
  ///
  /// Note: The UID is not included in the map as it serves as the document ID.
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'photoURL': photoURL,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Creates a copy of this [UserModel] with the given fields replaced.
  UserModel copyWith({
    String? uid,
    String? email,
    String? username,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? photoURL,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, username: $username, firstName: $firstName, lastName: $lastName, phoneNumber: $phoneNumber, photoURL: $photoURL, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.uid == uid &&
        other.email == email &&
        other.username == username &&
        other.firstName == firstName &&
        other.lastName == lastName &&
        other.phoneNumber == phoneNumber &&
        other.photoURL == photoURL &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        email.hashCode ^
        username.hashCode ^
        firstName.hashCode ^
        lastName.hashCode ^
        phoneNumber.hashCode ^
        photoURL.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
