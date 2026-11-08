import 'package:flutter/material.dart';

import '../../services/community_service.dart';
import '../../services/item_service.dart';
import '../details/item_details_screen.dart';
import '../../widgets/empty_state_view.dart';
import '../../services/device_alerts.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final service = CommunityService();
  late final _alerts = service.notifications();
  bool _enabling = false;
  Future<void> _enable() async {
    setState(() => _enabling = true);
    try {
      await DeviceAlerts.enable();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Device alerts enabled.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Device alerts could not be enabled. Check notification permissions or use this inbox.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enabling = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your alerts')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton.icon(
            onPressed: _enabling ? null : _enable,
            icon: const Icon(Icons.notifications_active_outlined),
            label: Text(_enabling ? 'Enabling…' : 'Enable device alerts'),
          ),
        ),
        Expanded(
          child: StreamBuilder(
            stream: _alerts,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const EmptyStateView(
                  icon: Icons.cloud_off_outlined,
                  title: 'Couldn’t load alerts',
                  subtitle:
                      'Check your connection and try opening this inbox again.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const EmptyStateView(
                  icon: Icons.notifications_none_rounded,
                  title: 'You’re all caught up',
                  subtitle: 'Match alerts, saved-search results, claim updates, and report reminders appear here.',
                );
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  return ListTile(
                    isThreeLine: true,
                    leading: Icon(
                      data['read'] == true
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(data['title'] as String? ?? 'FindIt update'),
                    subtitle: Text(data['body'] as String? ?? ''),
                    onTap: () async {
                      try {
                        await doc.reference.update({'read': true});
                        final id = data['itemId'] as String?;
                        if (id == null) return;
                        final item = await ItemService().getItem(id);
                        if (context.mounted && item != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ItemDetailsScreen(item: item),
                            ),
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not open this alert. Please try again.',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
