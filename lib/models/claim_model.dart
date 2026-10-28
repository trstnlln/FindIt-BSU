/// Represents a claim request submitted by a user for a specific item.
/// Stored in Firestore under the `claims` collection.
class ClaimModel {
  final String id;            // Firestore document ID
  final String itemId;        // ID of the item being claimed
  final String itemTitle;     // Title of the item (for easy display)
  final String ownerId;       // UID of the item's reporter
  final String claimantId;    // UID of the user submitting the claim
  final String claimantName;  // Display name of the claimant
  final String claimantEmail; // Contact email of claimant
  final String message;       // General message from the claimant
  final String proof;         // "Something only the owner would know"
  final String status;        // 'pending', 'approved', or 'rejected'
  final DateTime createdAt;   // Timestamp when the claim was submitted
  final DateTime? updatedAt;  // Timestamp when status was changed (nullable)

  const ClaimModel({
    required this.id,
    required this.itemId,
    this.itemTitle = '',
    this.ownerId = '',
    required this.claimantId,
    this.claimantName = 'BSU User',
    this.claimantEmail = '',
    this.message = '',
    required this.proof,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });

  // ---------------------------------------------------------------------------
  // Factory constructor — builds a ClaimModel from a Firestore document map.
  // ---------------------------------------------------------------------------
  factory ClaimModel.fromMap(Map<String, dynamic> map, String docId) {
    return ClaimModel(
      id: docId,
      itemId: map['itemId'] as String? ?? '',
      itemTitle: map['itemTitle'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      claimantId: map['claimantId'] as String? ?? '',
      claimantName: map['claimantName'] as String? ?? 'BSU User',
      claimantEmail: map['claimantEmail'] as String? ?? '',
      message: map['message'] as String? ?? '',
      proof: map['proof'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? _parseDateTime(map['updatedAt']) : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Converts this ClaimModel to a map suitable for writing to Firestore.
  // `id` is the document ID and is NOT stored in the document body.
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemTitle': itemTitle,
      'ownerId': ownerId,
      'claimantId': claimantId,
      'claimantName': claimantName,
      'claimantEmail': claimantEmail,
      'message': message,
      'proof': proof,
      'status': status,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt?.millisecondsSinceEpoch,
    };
  }

  /// Returns a copy of this model with updated fields.
  ClaimModel copyWith({
    String? status,
    DateTime? updatedAt,
    String? message,
    String? proof,
  }) {
    return ClaimModel(
      id: id,
      itemId: itemId,
      itemTitle: itemTitle,
      ownerId: ownerId,
      claimantId: claimantId,
      claimantName: claimantName,
      claimantEmail: claimantEmail,
      message: message ?? this.message,
      proof: proof ?? this.proof,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
}
