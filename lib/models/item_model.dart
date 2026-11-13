import 'document_dates.dart';

/// Represents a lost or found item report in FindIt BSU.
/// Stored in Firestore under the `items` collection.
class ItemModel {
  final String id; // Firestore document ID
  final String type; // 'lost' or 'found'
  final String title; // Short title of the item (e.g., "Black Wallet")
  final String description; // Detailed description of the item
  final String category; // e.g., 'Electronics', 'Clothing', 'ID / Cards'
  final String location; // Campus landmark / building (e.g., 'CICS')
  final String?
  specificLocation; // Optional floor / room details (e.g., '3rd Flr Rm 304')
  final String?
  custodyLocation; // If found & turned over (e.g., 'Gate 1 Guard Post')
  final String?
  verificationQuestion; // Anti-fraud blind proof prompt for found items
  final DateTime date; // Date the item was lost or found
  final String? photoUrl; // Optional photo URL (Firebase Storage)
  final String status; // 'open', 'claimed', or 'returned'
  final bool archived;
  final bool moderated;
  final String ownerId; // UID of the user who created this report
  final DateTime createdAt; // Timestamp when report was submitted

  const ItemModel({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    this.specificLocation,
    this.custodyLocation,
    this.verificationQuestion,
    required this.date,
    this.photoUrl,
    required this.status,
    this.archived = false,
    this.moderated = false,
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
      specificLocation: map['specificLocation'] as String?,
      custodyLocation: map['custodyLocation'] as String?,
      verificationQuestion: map['verificationQuestion'] as String?,
      date: _parseDateTime(map['date']),
      photoUrl: map['photoUrl'] as String?,
      status: map['status'] as String? ?? 'open',
      archived: map['archived'] == true,
      moderated: map['moderated'] == true,
      ownerId: map['ownerId'] as String? ?? '',
      createdAt: _parseDateTime(map['createdAt']),
    );
  }

  static DateTime _parseDateTime(dynamic value) => parseDocumentDate(value);

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
      'specificLocation': specificLocation,
      'custodyLocation': custodyLocation,
      'verificationQuestion': verificationQuestion,
      'date': date.millisecondsSinceEpoch,
      'photoUrl': photoUrl,
      'status': status,
      'archived': archived,
      'moderated': moderated,
      'ownerId': ownerId,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Returns a copy of this model with updated fields.
  ItemModel copyWith({
    String? type,
    String? title,
    String? description,
    String? category,
    String? location,
    String? specificLocation,
    String? custodyLocation,
    String? verificationQuestion,
    DateTime? date,
    String? photoUrl,
    String? status,
    bool? archived,
    bool? moderated,
  }) {
    return ItemModel(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      location: location ?? this.location,
      specificLocation: specificLocation ?? this.specificLocation,
      custodyLocation: custodyLocation ?? this.custodyLocation,
      verificationQuestion: verificationQuestion ?? this.verificationQuestion,
      date: date ?? this.date,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      archived: archived ?? this.archived,
      moderated: moderated ?? this.moderated,
      ownerId: ownerId,
      createdAt: createdAt,
    );
  }
}
