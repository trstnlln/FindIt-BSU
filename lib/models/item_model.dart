/// Represents a lost or found item report in FindIt BSU.
/// Stored in Firestore under the `items` collection.
class ItemModel {
  final String id;           // Firestore document ID
  final String type;         // 'lost' or 'found'
  final String title;        // Short title of the item (e.g., "Black Wallet")
  final String description;  // Detailed description of the item
  final String category;     // e.g., 'Electronics', 'Clothing', 'ID / Cards'
  final String location;     // Campus location where item was lost/found
  final DateTime date;       // Date the item was lost or found
  final String? photoUrl;    // Optional photo URL (Firebase Storage)
  final String status;       // 'open', 'claimed', or 'returned'
  final String ownerId;      // UID of the user who created this report
  final DateTime createdAt;  // Timestamp when report was submitted

  const ItemModel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.date,
    this.photoUrl,
    required this.status,
    required this.ownerId,
    required this.createdAt,
  });

  // ---------------------------------------------------------------------------
  // Factory constructor — builds an ItemModel from a Firestore document map.
  // ---------------------------------------------------------------------------
  factory ItemModel.fromMap(Map<String, dynamic> map, String docId) {
    return ItemModel(
      id: docId,
      type: map['type'] as String? ?? 'lost',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? 'Other',
      location: map['location'] as String? ?? '',
      date: _parseDateTime(map['date']),
      photoUrl: map['photoUrl'] as String?,
      status: map['status'] as String? ?? 'open',
      ownerId: map['ownerId'] as String? ?? '',
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
  // Converts this ItemModel to a map suitable for writing to Firestore.
  // `id` is the document ID and is NOT stored in the document body.
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'title': title,
      'description': description,
      'category': category,
      'location': location,
      'date': date.millisecondsSinceEpoch,
      'photoUrl': photoUrl,
      'status': status,
      'ownerId': ownerId,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Returns a copy of this model with updated fields.
  /// Useful for updating status or photo URL without mutating the original.
  ItemModel copyWith({
    String? type,
    String? title,
    String? description,
    String? category,
    String? location,
    DateTime? date,
    String? photoUrl,
    String? status,
  }) {
    return ItemModel(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      location: location ?? this.location,
      date: date ?? this.date,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      ownerId: ownerId,
      createdAt: createdAt,
    );
  }
}
