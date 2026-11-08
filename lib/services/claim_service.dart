import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/auth_provider.dart';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

import '../models/claim_model.dart';

/// Handles Firestore CRUD operations for the `claims` collection.
class ClaimService {
  final CollectionReference _claimsRef = FirebaseFirestore.instance.collection(
    'claims',
  );
  final CollectionReference _itemsRef = FirebaseFirestore.instance.collection(
    'items',
  );

  // ─── Create ───────────────────────────────────────────────────────────────

  /// Submits a new ownership claim for an item.
  Future<ClaimModel> submitClaim({
    required String itemId,
    required String itemTitle,
    required String ownerId,
    required String claimantId,
    required String claimantName,
    required String claimantEmail,
    required String message,
    required String proof,
    List<String> verificationAnswers = const [],
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null ||
        !user.emailVerified ||
        user.uid != claimantId ||
        !AuthProvider.isBatStateUEmail(user.email ?? '') ||
        claimantEmail != user.email) {
      throw Exception(
        'Domain Restricted: Only users with a valid @g.batstate-u.edu.ph email address can submit claims.',
      );
    }
    final now = DateTime.now();
    final claim = ClaimModel(
      id: '',
      itemId: itemId,
      itemTitle: itemTitle,
      ownerId: ownerId,
      claimantId: claimantId,
      claimantName: claimantName,
      claimantEmail: claimantEmail,
      message: message,
      proof: proof,
      verificationAnswers: verificationAnswers,
      status: 'pending',
      createdAt: now,
    );

    final existing = await _claimsRef
        .where('itemId', isEqualTo: itemId)
        .where('claimantId', isEqualTo: claimantId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw Exception('You already submitted a claim for this item.');
    }
    final id = base64Url
        .encode(utf8.encode(jsonEncode([itemId, claimantId])))
        .replaceAll('=', '');
    final docRef = _claimsRef.doc(id);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final item = await transaction.get(_itemsRef.doc(itemId));
      final duplicate = await transaction.get(docRef);
      final data = item.data() as Map<String, dynamic>?;
      if (duplicate.exists) {
        throw Exception('You already submitted a claim for this item.');
      }
      if (data == null || data['status'] != 'open') {
        throw Exception('This item is no longer open for claims.');
      }
      if (data['ownerId'] != ownerId || ownerId == claimantId) {
        throw Exception('You cannot claim your own report.');
      }
      transaction.set(docRef, claim.toMap());
    });
    return ClaimModel.fromMap(claim.toMap(), docRef.id);
  }

  // ─── Streams ──────────────────────────────────────────────────────────────

  /// Real-time stream of all claims submitted for a specific [itemId].
  /// Optionally constrained by [ownerId] to ensure matching Firestore read security rules.
  Stream<List<ClaimModel>> getClaimsForItemStream(
    String itemId, {
    String? ownerId,
  }) {
    final uid = ownerId ?? FirebaseAuth.instance.currentUser?.uid;
    Query query = _claimsRef.where('itemId', isEqualTo: itemId);
    if (uid != null) {
      query = query.where('ownerId', isEqualTo: uid);
    }
    return query.snapshots().map((snapshot) {
      final claims = snapshot.docs
          .map(
            (doc) =>
                ClaimModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id),
          )
          .toList();
      // Client-side sort to avoid requiring composite indexes
      claims.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return claims;
    });
  }

  /// Real-time stream of all incoming claims across all items owned by [ownerId].
  Stream<List<ClaimModel>> getClaimsByOwnerStream(String ownerId) {
    return _claimsRef.where('ownerId', isEqualTo: ownerId).snapshots().map((
      snapshot,
    ) {
      final claims = snapshot.docs
          .map(
            (doc) =>
                ClaimModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id),
          )
          .toList();
      claims.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return claims;
    });
  }

  /// Check if [claimantId] has already claimed [itemId].
  Stream<ClaimModel?> getClaimByClaimantStream({
    required String itemId,
    required String claimantId,
  }) {
    return _claimsRef
        .where('itemId', isEqualTo: itemId)
        .where('claimantId', isEqualTo: claimantId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return ClaimModel.fromMap(
            snapshot.docs.first.data()! as Map<String, dynamic>,
            snapshot.docs.first.id,
          );
        });
  }

  /// Real-time stream of all claims submitted by a claimant across all items.
  Stream<List<ClaimModel>> getClaimsByClaimantStream(String claimantId) {
    return _claimsRef
        .where('claimantId', isEqualTo: claimantId)
        .snapshots()
        .map((snapshot) {
          final claims = snapshot.docs
              .map(
                (doc) => ClaimModel.fromMap(
                  doc.data()! as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList();
          claims.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return claims;
        });
  }

  // ─── Approval & Rejection ─────────────────────────────────────────────────

  /// Approves a claim:
  /// 1. Updates claim status to 'approved'.
  /// 2. Updates the item status to 'claimed' in the `items` collection.
  /// 3. Rejects any other pending claims for this item.
  Future<void> approveClaim({
    required String claimId,
    required String itemId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('You must be logged in.');
    final otherClaims = await _claimsRef
        .where('itemId', isEqualTo: itemId)
        .where('ownerId', isEqualTo: uid)
        .get();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final item = await transaction.get(_itemsRef.doc(itemId));
      final selected = await transaction.get(_claimsRef.doc(claimId));
      final itemData = item.data() as Map<String, dynamic>?;
      final claimData = selected.data() as Map<String, dynamic>?;
      if (itemData == null ||
          itemData['ownerId'] != uid ||
          itemData['status'] != 'open' ||
          claimData == null ||
          claimData['ownerId'] != uid ||
          claimData['itemId'] != itemId ||
          !['pending', 'reviewing'].contains(claimData['status'])) {
        throw Exception(
          'This claim or item has already changed. Refresh and try again.',
        );
      }
      // Read before writing; the item lock prevents two concurrent approvals.
      final others = <DocumentSnapshot>[];
      for (final doc in otherClaims.docs) {
        if (doc.id != claimId) others.add(await transaction.get(doc.reference));
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      transaction.update(selected.reference, {
        'status': 'approved',
        'updatedAt': now,
      });
      transaction.update(item.reference, {'status': 'claimed'});
      for (final doc in others) {
        final data = doc.data() as Map<String, dynamic>?;
        if (['pending', 'reviewing'].contains(data?['status'])) {
          transaction.update(doc.reference, {
            'status': 'rejected',
            'updatedAt': now,
          });
        }
      }
    });
  }

  Future<void> updateStage(String claimId, String stage) async {
    if (!['reviewing', 'ready'].contains(stage)) {
      throw ArgumentError('Invalid claim stage');
    }
    await _claimsRef.doc(claimId).update({
      'status': stage,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Rejects a specific claim request.
  Future<void> rejectClaim(String claimId) async {
    await _claimsRef.doc(claimId).update({
      'status': 'rejected',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }
}
