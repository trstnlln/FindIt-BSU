import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/activity_provider.dart';
import '../../models/activity_entry.dart';
import '../../services/backend_features.dart';
import '../../services/item_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/empty_state_view.dart';
import '../claims/conversation_screen.dart';
import '../claims/item_claims_screen.dart';
import '../details/item_details_screen.dart';
import 'cloud_alerts_screen.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});
  Future<void> _open(
    BuildContext context,
    ActivityProvider activity,
    ActivityEntry entry,
  ) async {
    try {
      await activity.markRead(entry);
      final claim = activity.claim(entry.claimId);
      if (!context.mounted) return;
      if (entry.message && claim != null) {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ConversationScreen(claim: claim),
          ),
        );
        return;
      }
      final item = await ItemService().getItem(entry.itemId);
      if (!context.mounted) return;
      if (item == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This report is no longer available.')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => entry.id.startsWith('incoming-')
              ? ItemClaimsScreen(item: item)
              : ItemDetailsScreen(item: item),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this update. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<ActivityProvider>();
    final entries = activity.entries;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your alerts'),
        actions: [
          IconButton(
            tooltip: 'Refresh activity',
            onPressed: activity.retry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Live claim and message updates appear while you use FindIt-BSU.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (BackendFeatures.cloudAlerts)
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Device alerts & server inbox'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const CloudAlertsScreen(),
                ),
              ),
            ),
          if (activity.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Some updates could not load. Check your connection and tap Refresh.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: activity.isLoading && entries.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : entries.isEmpty
                ? EmptyStateView(
                    icon: Icons.notifications_none_rounded,
                    title: activity.hasError
                        ? 'Updates unavailable'
                        : 'You’re all caught up',
                    subtitle: activity.hasError ? 'Tap Refresh to reconnect.' : 'New claims, claim decisions and private messages will appear here.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    separatorBuilder: (_, i) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final unread = activity.isUnread(entry);
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Icon(
                            entry.message
                                ? Icons.chat_bubble_outline_rounded
                                : Icons.assignment_outlined,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(
                            entry.title,
                            style: TextStyle(
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          subtitle: Text(
                            '${entry.body}\n${formatTimeAgo(entry.date)}',
                          ),
                          trailing: unread
                              ? const Badge(label: Text('New'))
                              : null,
                          onTap: () => _open(context, activity, entry),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
