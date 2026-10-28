/// Represents a registered user of the FindIt BSU app.
/// Stored in Firestore under the `users` collection.
class UserModel {
  final String id;          // Firestore document ID (same as Firebase Auth UID)
  final String name;        // Display name
  final String email;       // Email address used for login
  final String role;        // 'student', 'teacher', or 'staff'
  final String? photoUrl;   // Optional profile photo URL (Firebase Storage)
  final DateTime createdAt; // Account creation timestamp

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.photoUrl,
    required this.createdAt,
  });

  // ---------------------------------------------------------------------------
  // Factory constructor — builds a UserModel from a Firestore document map.
  // ---------------------------------------------------------------------------
  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      id: docId,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: map['role'] as String? ?? 'student',
      photoUrl: map['photoUrl'] as String?,
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    if (value is DateTime) return value;
    try {
      return (value as dynamic).toDate() as DateTime;
    } catch (_) {}
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  // ---------------------------------------------------------------------------
  // Converts this UserModel to a map suitable for writing to Firestore.
  // Note: `id` is the document ID and is NOT stored inside the document body.
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'photoUrl': photoUrl,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Returns a copy of this model with updated fields.
  UserModel copyWith({
    String? name,
    String? email,
    String? role,
    String? photoUrl,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
    );
  }
}
