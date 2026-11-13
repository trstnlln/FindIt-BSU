import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/claim_model.dart';
import '../models/item_model.dart';
import 'claim_service.dart';
import 'item_service.dart';

class ActivityService {
  FirebaseFirestore get db => FirebaseFirestore.instance;
  Stream<List<ItemModel>> reports(String uid) =>
      ItemService().getItemsByUserStream(uid);
  Stream<List<ClaimModel>> incoming(String uid) =>
      ClaimService().getClaimsByOwnerStream(uid);
  Stream<List<ClaimModel>> submitted(String uid) =>
      ClaimService().getClaimsByClaimantStream(uid);
  Stream<Map<String, Map<String, dynamic>>> conversations(
    String uid,
    String field,
  ) => db
      .collection('conversations')
      .where(field, isEqualTo: uid)
      .snapshots()
      .map((snap) => {for (final doc in snap.docs) doc.id: doc.data()});
  Stream<Map<String, String>> reads(String uid) => db
      .collection('users')
      .doc(uid)
      .collection('activityReads')
      .snapshots()
      .map(
        (snap) => {
          for (final doc in snap.docs)
            if (doc.data()['version'] is String)
              doc.id: doc.data()['version'] as String,
        },
      );
  Future<void> markRead(String uid, String id, String version) => db
      .collection('users')
      .doc(uid)
      .collection('activityReads')
      .doc(id)
      .set({'version': version, 'seenAt': FieldValue.serverTimestamp()});
}
