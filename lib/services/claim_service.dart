import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/claim_model.dart';

/// Handles Firestore CRUD operations for the `claims` collection.
class ClaimService {
  final CollectionReference _claimsRef =
      FirebaseFirestore.instance.collection('claims');
  final CollectionReference _itemsRef =
      FirebaseFirestore.instance.collection('items');

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
  }) async {
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
      status: 'pending',
      createdAt: now,
    );

    final docRef = await _claimsRef.add(claim.toMap());
    return ClaimModel.fromMap(claim.toMap(), docRef.id);
  }

  // ─── Streams ──────────────────────────────────────────────────────────────

  /// Real-time stream of all claims submitted for a specific [itemId].
  Stream<List<ClaimModel>> getClaimsForItemStream(String itemId) {
    return _claimsRef
        .where('itemId', isEqualTo: itemId)
        .snapshots()
        .map((snapshot) {
      final claims = snapshot.docs
          .map((doc) =>
              ClaimModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id))
          .toList();
      // Client-side sort to avoid requiring composite indexes
      claims.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return claims;
    });
  }

  /// Real-time stream of all incoming claims across all items owned by [ownerId].
  Stream<List<ClaimModel>> getClaimsByOwnerStream(String ownerId) {
    return _claimsRef
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) {
      final claims = snapshot.docs
          .map((doc) =>
              ClaimModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id))
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

  // ─── Approval & Rejection ─────────────────────────────────────────────────

  /// Approves a claim:
  /// 1. Updates claim status to 'approved'.
  /// 2. Updates the item status to 'claimed' in the `items` collection.
  /// 3. Rejects any other pending claims for this item.
  Future<void> approveClaim({
    required String claimId,
    required String itemId,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Mark this claim as approved
    batch.update(_claimsRef.doc(claimId), {
      'status': 'approved',
      'updatedAt': now,
    });

    // 2. Mark item as claimed
    batch.update(_itemsRef.doc(itemId), {
      'status': 'claimed',
    });

    // 3. Mark other pending claims for this item as rejected
    final otherClaims = await _claimsRef
        .where('itemId', isEqualTo: itemId)
        .where('status', isEqualTo: 'pending')
        .get();

    for (final doc in otherClaims.docs) {
      if (doc.id != claimId) {
        batch.update(doc.reference, {
          'status': 'rejected',
          'updatedAt': now,
        });
      }
    }

    await batch.commit();
  }

  /// Rejects a specific claim request.
  Future<void> rejectClaim(String claimId) async {
    await _claimsRef.doc(claimId).update({
      'status': 'rejected',
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }
}

