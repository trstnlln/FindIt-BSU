import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:image_picker/image_picker.dart';

import 'dart:convert';

import 'photo_upload.dart';

import 'package:http_parser/http_parser.dart';

import 'package:http/http.dart' as http;

import '../models/item_model.dart';
import '../providers/auth_provider.dart';

/// Handles all Firestore CRUD operations for the `items` collection.
class ItemService {
  CollectionReference get _itemsRef =>
      FirebaseFirestore.instance.collection('items');

  // ─── Upload Photo ────────────────────────────────────────────────────────

  /// Uploads an item image to Cloudinary and returns its public URL.
  static const String _cloudName = 'pa77o7a4';
  static const String _uploadPreset = 'finditbsu_unsigned';

  Future<String> uploadItemPhoto(
    XFile imageFile, {
    void Function(double)? onProgress,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) {
      throw Exception('Verify your university email before uploading a photo.');
    }
    if (await imageFile.length() > 5 * 1024 * 1024) {
      throw const FormatException('Choose a photo smaller than 5 MB.');
    }
    final bytes = await imageFile.readAsBytes();
    final format = validateReportPhoto(bytes);
    final client = http.Client();
    try {
      final request =
          ProgressMultipartRequest(
              'POST',
              Uri.parse(
                'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
              ),
              onProgress: onProgress,
            )
            ..fields['upload_preset'] = _uploadPreset
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                bytes,
                filename: 'report.${format.extension}',
                contentType: MediaType.parse(format.mime),
              ),
            );
      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed)
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Photo upload failed. Please try again.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final url = Uri.tryParse(data['secure_url'] as String? ?? '');
      if (url == null ||
          url.scheme != 'https' ||
          url.host != 'res.cloudinary.com') {
        throw Exception(
          'The photo service returned an invalid image. Please try again.',
        );
      }
      onProgress?.call(1);
      return url.toString();
    } finally {
      client.close();
    }
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
    Map<String, dynamic>? secureDetails,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null ||
        !user.emailVerified ||
        user.uid != ownerId ||
        !AuthProvider.isBatStateUEmail(user.email ?? '')) {
      throw Exception(
        'Sign in with your university account to report an item.',
      );
    }
    final now = DateTime.now();

    final item = ItemModel(
      id: '', // placeholder — Firestore will generate the real ID
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

    // Commit the report and its verification details together. A failed
    // private write must not leave a public report that appears to have failed.
    final docRef = _itemsRef.doc();
    // Transactions fail offline instead of silently queuing a report that a
    // user might submit again after reopening their saved draft.
    await FirebaseFirestore.instance.runTransaction((batch) async {
      await batch.get(docRef);
      batch.set(docRef, item.toMap());
      if (secureDetails != null) {
        batch.set(docRef.collection('verification').doc('questions'), {
          'questions': List<String>.from(secureDetails['questions'] as List),
        });
        batch.set(docRef.collection('private').doc('details'), {
          'exactAmount': secureDetails['exactAmount'],
          'foundCondition': secureDetails['foundCondition'],
          'answers': List<String>.from(secureDetails['answers'] as List),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
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
          .map(
            (doc) =>
                ItemModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id),
          )
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
    final snapshot = await _itemsRef
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map(
          (doc) =>
              ItemModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  /// Real-time stream of items filed by a specific user, sorted newest first.
  Stream<List<ItemModel>> getItemsByUserStream(String userId) {
    return _itemsRef.where('ownerId', isEqualTo: userId).snapshots().map((
      snapshot,
    ) {
      final items = snapshot.docs
          .map(
            (doc) =>
                ItemModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id),
          )
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  /// Returns items filed by a specific user, newest first.
  Future<List<ItemModel>> getItemsByUser(String userId) async {
    final snapshot = await _itemsRef.where('ownerId', isEqualTo: userId).get();
    final items = snapshot.docs
        .map(
          (doc) =>
              ItemModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id),
        )
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

    final batch = FirebaseFirestore.instance.batch();
    batch.set(itemDoc.collection('verification').doc('questions'), {
      'questions': questions,
    });
    batch.set(itemDoc.collection('private').doc('details'), {
      'exactAmount': exactAmount,
      'foundCondition': foundCondition,
      'answers': answers,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
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
    if (status != 'returned') {
      await _itemsRef.doc(itemId).update({'status': status});
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sign in first.');
    final claims = await FirebaseFirestore.instance
        .collection('claims')
        .where('itemId', isEqualTo: itemId)
        .where('ownerId', isEqualTo: uid)
        .get();
    if (claims.docs.length > 450) {
      throw StateError('This report needs administrator assistance to close.');
    }
    final batch = FirebaseFirestore.instance.batch();
    batch.update(_itemsRef.doc(itemId), {'status': status});
    for (final doc in claims.docs) {
      final previous = doc.data()['status'];
      if (['approved', 'ready', 'pending', 'reviewing'].contains(previous)) {
        batch.update(doc.reference, {
          'status': ['approved', 'ready'].contains(previous)
              ? 'returned'
              : 'rejected',
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
    }
    await batch.commit();
  }

  Future<void> editItem(
    String itemId, {
    required String title,
    required String description,
    required String location,
    String? custodyLocation,
  }) async {
    if (title.trim().length < 3 || description.trim().length < 10) {
      throw Exception(
        'Add a title and a description of at least 10 characters.',
      );
    }
    await _itemsRef.doc(itemId).update({
      'title': title.trim(),
      'description': description.trim(),
      'location': location,
      'custodyLocation': custodyLocation,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Deletes an item report from Firestore.
  /// Allowed only for the item owner by Firestore security rules.
  Future<void> deleteItem(String itemId) async {
    await _itemsRef.doc(itemId).delete();
  }
}
