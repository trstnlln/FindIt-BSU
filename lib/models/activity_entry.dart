import 'claim_model.dart';
import 'document_dates.dart';

class ActivityEntry {
  final String id, version, itemId, title, body;
  final String? claimId;
  final DateTime date;
  final bool message, cloud;
  const ActivityEntry({
    required this.id,
    required this.version,
    required this.itemId,
    required this.title,
    required this.body,
    required this.date,
    this.claimId,
    this.message = false,
    this.cloud = false,
  });
}

String claimGuidance(String status) => switch (status) {
  'reviewing' => 'The reporter is checking your ownership proof.',
  'approved' =>
    'Your claim is approved. Arrange a campus pickup with the reporter.',
  'ready' => 'Ready for pickup. Confirm a safe handover with the reporter.',
  'returned' => 'This item has been marked returned.',
  'rejected' => 'The reporter could not confirm this claim.',
  _ => 'Waiting for the reporter to review your ownership proof.',
};

List<ActivityEntry> deriveActivity({
  required String uid,
  required List<ClaimModel> incoming,
  required List<ClaimModel> submitted,
  required Map<String, Map<String, dynamic>> conversations,
}) {
  final entries = <ActivityEntry>[
    for (final claim in incoming)
      if (['pending', 'reviewing'].contains(claim.status))
        ActivityEntry(
          id: 'incoming-${claim.id}',
          version: '${claim.createdAt.millisecondsSinceEpoch}',
          itemId: claim.itemId,
          claimId: claim.id,
          title: 'A claim needs your review',
          body: claim.itemTitle,
          date: claim.createdAt,
        ),
    for (final claim in submitted)
      if (claim.status != 'pending')
        ActivityEntry(
          id: 'claim-${claim.id}',
          version:
              '${claim.status}:${(claim.updatedAt ?? claim.createdAt).millisecondsSinceEpoch}',
          itemId: claim.itemId,
          claimId: claim.id,
          title: 'Your claim has an update',
          body: claimGuidance(claim.status),
          date: claim.updatedAt ?? claim.createdAt,
        ),
    for (final chat in conversations.entries)
      if (chat.value['lastSenderId'] is String &&
          chat.value['lastSenderId'] != uid &&
          chat.value['lastMessageId'] is String)
        ActivityEntry(
          id: 'message-${chat.key}',
          version: chat.value['lastMessageId'] as String,
          itemId: chat.value['itemId'] as String? ?? '',
          claimId: chat.key,
          message: true,
          title: 'You have a private message',
          body:
              chat.value['itemTitle'] as String? ??
              'Open the conversation to reply.',
          date: parseDocumentDate(chat.value['lastMessageAt']),
        ),
  ];
  entries.sort((a, b) => b.date.compareTo(a.date));
  return entries;
}

int claimAttentionRank(ClaimModel claim) => switch (claim.status) {
  'ready' => 0,
  'approved' => 1,
  'reviewing' => 2,
  'pending' => 3,
  _ => 4,
};
