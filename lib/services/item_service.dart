import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../models/item_model.dart';

/// Handles all Firestore CRUD operations for the `items` collection.
class ItemService {
  final CollectionReference _itemsRef =
      FirebaseFirestore.instance.collection('items');

  // ─── Upload Photo ────────────────────────────────────────────────────────

  /// Uploads an item image to Firebase Storage and returns its download URL.
  Future<String> uploadItemPhoto(XFile imageFile) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
    final ref =
        FirebaseStorage.instance.ref().child('item_photos').child(fileName);
    final bytes = await imageFile.readAsBytes();
    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await uploadTask.ref.getDownloadURL();
  }

  // ─── Create ───────────────────────────────────────────────────────────────

  /// Saves a new item report to Firestore.
  /// Returns the created [ItemModel] with its generated document ID.
  Future<ItemModel> createItem({
    required String ownerId,
    required String type,
    required String title,
    required String description,
    required String category,
    required String location,
    required DateTime date,
    String? photoUrl,
  }) async {
    final now = DateTime.now();

    final item = ItemModel(
      id: '',  // placeholder — Firestore will generate the real ID
      ownerId: ownerId,
      type: type,
      title: title,
      description: description,
      category: category,
      location: location,
      date: date,
      photoUrl: photoUrl,
      status: 'open',
      createdAt: now,
    );

    final docRef = await _itemsRef.add(item.toMap());

    // Return the model with the actual Firestore document ID
    return ItemModel.fromMap(item.toMap(), docRef.id);
  }

  // ─── Streams (Real-time) ──────────────────────────────────────────────────

  /// Real-time stream of items, optionally filtered by `type` ('lost' or 'found').
  /// Results are sorted newest first by `createdAt`.
  Stream<List<ItemModel>> getItemsStream({String? type}) {
    Query query = _itemsRef;
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    return query.snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) =>
              ItemModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id))
          .toList();
      // Sort client-side by createdAt descending to avoid composite index requirements in Firestore
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  /// Real-time stream of a single item document by ID.
  Stream<ItemModel?> getItemStream(String itemId) {
    return _itemsRef.doc(itemId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return ItemModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id);
    });
  }

  // ─── Read ─────────────────────────────────────────────────────────────────

  /// Returns a single item by document ID, or null if not found.
  Future<ItemModel?> getItem(String itemId) async {
    final doc = await _itemsRef.doc(itemId).get();
    if (!doc.exists) return null;
    return ItemModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id);
  }

  /// Returns all items, newest first.
  Future<List<ItemModel>> getAllItems() async {
    final snapshot =
        await _itemsRef.orderBy('createdAt', descending: true).get();
    return snapshot.docs
        .map((doc) =>
            ItemModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id))
        .toList();
  }

  /// Returns items filed by a specific user, newest first.
  Future<List<ItemModel>> getItemsByUser(String userId) async {
    final snapshot = await _itemsRef
        .where('ownerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) =>
            ItemModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id))
        .toList();
  }

  // ─── Update ───────────────────────────────────────────────────────────────

  /// Updates the status of an item ('open', 'claimed', or 'returned').
  Future<void> updateItemStatus(String itemId, String status) async {
    await _itemsRef.doc(itemId).update({'status': status});
  }
}

