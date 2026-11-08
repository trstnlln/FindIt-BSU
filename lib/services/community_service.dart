import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommunityService {
  FirebaseFirestore get db => FirebaseFirestore.instance;
  String get uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) {
      throw StateError('Verify your university account first.');
    }
    return user.uid;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> notifications() => db
      .collection('users')
      .doc(uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots();
  Stream<QuerySnapshot<Map<String, dynamic>>> savedSearches() =>
      db.collection('users').doc(uid).collection('savedSearches').snapshots();
  Future<void> saveSearch({
    required String query,
    String? category,
    String? location,
  }) async {
    final text = query.trim().toLowerCase();
    if (text.isEmpty && category == null && location == null) {
      throw StateError('Enter a keyword or select a filter first.');
    }
    if (text.length > 100) {
      throw StateError('Keep your saved search under 100 characters.');
    }
    final id = base64Url
        .encode(utf8.encode(jsonEncode([text, category, location])))
        .replaceAll('=', '');
    await db
        .collection('users')
        .doc(uid)
        .collection('savedSearches')
        .doc(id)
        .set({
          'query': text,
          'category': category,
          'location': location,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> flagItem(String itemId, String reason, String details) async {
    if (![
      'False report',
      'Suspicious claim or scam',
      'Inappropriate photo',
      'Spam',
      'Other',
    ].contains(reason)) {
      throw StateError('Choose a reason.');
    }
    await db.collection('abuseReports').add({
      'reporterId': uid,
      'itemId': itemId,
      'reason': reason,
      'details': details.trim(),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> canModerate() async =>
      (await FirebaseAuth.instance.currentUser?.getIdTokenResult())
          ?.claims?['moderator'] ==
      true;
}
