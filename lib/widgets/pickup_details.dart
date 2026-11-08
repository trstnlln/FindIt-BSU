import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item_model.dart';

/// Office hours come from campus-managed records; do not invent schedules.
class PickupDetails extends StatelessWidget {
  final ItemModel item;
  const PickupDetails({super.key, required this.item});
  @override
  Widget build(BuildContext context) {
    if (item.type != 'found') return const SizedBox.shrink();
    final office = item.custodyLocation;
    final withFinder =
        office == null ||
        office.isEmpty ||
        office == 'With Finder (Not Surrendered)';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plan a safe pickup',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              withFinder
                  ? 'The finder is holding this item. Agree on a staffed campus handover point after your claim is approved.'
                  : 'Reported custody: $office',
            ),
            const SizedBox(height: 8),
            if (!withFinder)
              StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('campusOffices')
                    .where('name', isEqualTo: office)
                    .limit(1)
                    .snapshots(),
                builder: (context, snapshot) {
                  final records = snapshot.data?.docs;
                  if (records == null || records.isEmpty) {
                    return const Text(
                      'Confirm opening hours directly with the office before travelling.',
                    );
                  }
                  final data = records.first.data();
                  return Text(
                    [
                      data['hours'],
                      data['location'],
                      data['instructions'],
                    ].whereType<String>().where((s) => s.isNotEmpty).join('\n'),
                  );
                },
              ),
            const SizedBox(height: 8),
            const Text(
              'Bring your university ID and proof of ownership. Approval does not confirm an item has been returned.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
