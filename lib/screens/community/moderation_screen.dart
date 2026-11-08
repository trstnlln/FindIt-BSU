import 'package:flutter/material.dart';

import '../../services/community_service.dart';
import '../../services/item_service.dart';
import '../details/item_details_screen.dart';

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});
  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  final _service = CommunityService();
  late final _reports = _service.db
      .collection('abuseReports')
      .where('status', isEqualTo: 'open')
      .snapshots();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Campus moderation')),
    body: StreamBuilder(
      stream: _reports,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'This inbox requires campus moderator access. Ask your project administrator if you need access.',
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No open concerns.'));
        }
        return ListView(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data();
            return Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['reason'] as String? ?? 'Concern',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(data['details'] as String? ?? ''),
                    Wrap(
                      spacing: 12,
                      children: [
                        TextButton(
                          onPressed: () async {
                            try {
                              final item = await ItemService().getItem(
                                data['itemId'] as String,
                              );
                              if (context.mounted && item != null) {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        ItemDetailsScreen(item: item),
                                  ),
                                );
                              }
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Could not open the report.'),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Inspect report'),
                        ),
                        TextButton(
                          onPressed: () async {
                            try {
                              await doc.reference.update({
                                'status': 'resolved',
                              });
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not resolve this concern.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Mark reviewed'),
                        ),
                        TextButton(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Remove this report?'),
                                content: const Text(
                                  'Remove the public item after reviewing this concern. This action cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Remove'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true) return;
                            try {
                              await _service.db
                                  .collection('items')
                                  .doc(data['itemId'] as String)
                                  .delete();
                              await doc.reference.update({
                                'status': 'resolved',
                              });
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not complete removal. Check the report and retry.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Remove report'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    ),
  );
}
