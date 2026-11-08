import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../screens/community/alerts_screen.dart';

class AlertsBell extends StatefulWidget {
  const AlertsBell({super.key});
  @override
  State<AlertsBell> createState() => _AlertsBellState();
}

class _AlertsBellState extends State<AlertsBell> {
  late final _unread = FirebaseFirestore.instance
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser!.uid)
      .collection('notifications')
      .where('read', isEqualTo: false)
      .limit(99)
      .snapshots();
  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: _unread,
    builder: (context, snapshot) {
      final count = snapshot.data?.size ?? 0;
      return IconButton(
        tooltip: count == 0 ? 'Your alerts' : 'Your alerts: $count unread',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const AlertsScreen()),
        ),
        icon: Badge(
          isLabelVisible: count > 0,
          label: Text('$count'),
          child: const Icon(Icons.notifications_none_rounded),
        ),
      );
    },
  );
}
