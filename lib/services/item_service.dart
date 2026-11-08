import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/item_model.dart';

/// Handles all Firestore CRUD operations for the `items` collection.
class ItemService {
  final CollectionReference _itemsRef =
      FirebaseFirestore.instance.collection('items');

  // ─── Upload Photo ────────────────────────────────────────────────────────

  /// Uploads an item image to Cloudinary and returns its public URL.
  static const String _cloudName = 'pa77o7a4';
  static const String _uploadPreset = 'finditbsu_unsigned';

  Future<String> uploadItemPhoto(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: imageFile.name.isNotEmpty ? imageFile.name : 'upload.jpg',
      ));

    final streamed = await request.send().timeout(
      const Duration(seconds: 30),
    );
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Upload failed (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['secure_url'] as String;
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
    String? specificLocation,
    String? custodyLocation,
    String? verificationQuestion,
    required DateTime date,
    String? photoUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null &&
        user.email != null &&
        !user.email!.trim().toLowerCase().endsWith('@g.batstate-u.edu.ph')) {
      throw Exception(
        'Domain Restricted: Only users with a valid @g.batstate-u.edu.ph email address can post items.',
      );
    }
    final now = DateTime.now();

    final item = ItemModel(
      id: '',  // placeholder — Firestore will generate the real ID
      ownerId: ownerId,
      type: type,
      title: title,
      description: description,
      category: category,
      location: location,
      specificLocation: specificLocation,
      custodyLocation: custodyLocation,
      verificationQuestion: verificationQuestion,
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

  /// Real-time stream of items filed by a specific user, sorted newest first.
  Stream<List<ItemModel>> getItemsByUserStream(String userId) {
    return _itemsRef
        .where('ownerId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) =>
              ItemModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  /// Returns items filed by a specific user, newest first.
  Future<List<ItemModel>> getItemsByUser(String userId) async {
    final snapshot = await _itemsRef
        .where('ownerId', isEqualTo: userId)
        .get();
    final items = snapshot.docs
        .map((doc) =>
            ItemModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id))
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }
  // ─── Private verification details (for money / wallets) ─────────────────

  /// Saves the verification questions (readable by claimers) and the secret
  /// details + answers (readable only by the item owner).
  Future<void> savePrivateDetails({
    required String itemId,
    required String exactAmount,
    required String foundCondition,
    required List<String> questions,
    required List<String> answers,
  }) async {
    final itemDoc = _itemsRef.doc(itemId);

    await itemDoc.collection('verification').doc('questions').set({
      'questions': questions,
    });

    await itemDoc.collection('private').doc('details').set({
      'exactAmount': exactAmount,
      'foundCondition': foundCondition,
      'answers': answers,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Questions the claimer must answer. Never includes the answers.
  Future<List<String>> getVerificationQuestions(String itemId) async {
    final doc = await _itemsRef
        .doc(itemId)
        .collection('verification')
        .doc('questions')
        .get();
    if (!doc.exists || doc.data() == null) return [];
    return List<String>.from(doc.data()!['questions'] ?? []);
  }

  /// Secret details. Only works for the item owner (blocked by rules otherwise).
  Future<Map<String, dynamic>?> getPrivateDetails(String itemId) async {
    final doc = await _itemsRef
        .doc(itemId)
        .collection('private')
        .doc('details')
        .get();
    return doc.data();
  }
  // ─── Update ───────────────────────────────────────────────────────────────

  /// Updates the status of an item ('open', 'claimed', or 'returned').
  Future<void> updateItemStatus(String itemId, String status) async {
    await _itemsRef.doc(itemId).update({'status': status});
  }

  /// Deletes an item report from Firestore.
  /// Allowed only for the item owner by Firestore security rules.
  Future<void> deleteItem(String itemId) async {
    await _itemsRef.doc(itemId).delete();
  }
}

