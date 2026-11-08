import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/claim_model.dart';

class ConversationService {
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  Future<void> open(ClaimModel claim) async {
    final ref = _db.collection('conversations').doc(claim.id);
    await _db.runTransaction((tx) async {
      final current = await tx.get(ref);
      if (!current.exists) {
        tx.set(ref, {
          'ownerId': claim.ownerId,
          'claimantId': claim.claimantId,
          'itemId': claim.itemId,
          'itemTitle': claim.itemTitle,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> messages(String claimId) => _db
      .collection('conversations')
      .doc(claimId)
      .collection('messages')
      .orderBy('sentAt', descending: true)
      .limit(100)
      .snapshots();
  Future<void> send(String claimId, String text) async {
    final user = FirebaseAuth.instance.currentUser;
    final body = text.trim();
    if (user == null ||
        !user.emailVerified ||
        body.isEmpty ||
        body.length > 2000) {
      throw StateError('Enter a message under 2,000 characters.');
    }
    await _db
        .collection('conversations')
        .doc(claimId)
        .collection('messages')
        .add({
          'senderId': user.uid,
          'text': body,
          'sentAt': FieldValue.serverTimestamp(),
        });
  }
}
