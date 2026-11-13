import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/activity_entry.dart';
import '../../models/claim_model.dart';
import '../../models/item_model.dart';
import '../../providers/activity_provider.dart';
import '../../services/item_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/claim_journey.dart';
import '../../widgets/empty_state_view.dart';
import '../claims/conversation_screen.dart';
import '../claims/item_claims_screen.dart';
import '../details/item_details_screen.dart';
import '../report/report_item_screen.dart';

class MyActivityScreen extends StatefulWidget {
  const MyActivityScreen({super.key});
  @override
  State<MyActivityScreen> createState() => _MyActivityScreenState();
}

class _MyActivityScreenState extends State<MyActivityScreen> {
  bool _attentionOnly = false;
  int _reportRank(ItemModel item, ActivityProvider activity) {
    if (activity.hasUnreadMessage(item.id)) return 0;
    if (item.archived) return 4;
    final claims = activity.incoming.where((claim) => claim.itemId == item.id);
    if (claims.any(
      (claim) => ['pending', 'reviewing'].contains(claim.status),
    )) {
      return 0;
    }
    if (claims.any((claim) => ['approved', 'ready'].contains(claim.status))) {
      return 1;
    }
    return item.status == 'open' ? 2 : 3;
  }

  Future<void> _seen(ActivityProvider activity, String itemId) async {
    for (final entry in activity.entries.where(
      (entry) => entry.itemId == itemId && !entry.message,
    )) {
      try {
        await activity.markRead(entry);
      } catch (_) {
        /* Reading history stays available if the receipt fails. */
      }
    }
  }

  Future<void> _reply(ActivityProvider activity, ClaimModel claim) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ConversationScreen(claim: claim)),
    );
  }

  Future<void> _view(ActivityProvider activity, String id) async {
    try {
      final item = await ItemService().getItem(id);
      if (!mounted) return;
      if (item == null) throw StateError('Missing report');
      await _seen(activity, id);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => ItemDetailsScreen(item: item)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this report. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<ActivityProvider>();
    final reports = [...activity.reports]
      ..sort((a, b) {
        final rank = _reportRank(
          a,
          activity,
        ).compareTo(_reportRank(b, activity));
        return rank != 0 ? rank : b.createdAt.compareTo(a.createdAt);
      });
    final claims = [...activity.submitted]
      ..sort((a, b) {
        final ar = activity.hasUnreadMessage(a.itemId)
            ? -1
            : claimAttentionRank(a);
        final br = activity.hasUnreadMessage(b.itemId)
            ? -1
            : claimAttentionRank(b);
        return ar != br
            ? ar.compareTo(br)
            : (b.updatedAt ?? b.createdAt).compareTo(
                a.updatedAt ?? a.createdAt,
              );
      });
    final visibleReports = reports
        .where((item) => !_attentionOnly || _reportRank(item, activity) < 2)
        .toList();
    final visibleClaims = claims
        .where(
          (claim) =>
              !_attentionOnly ||
              activity.hasUnreadMessage(claim.itemId) ||
              ['approved', 'ready'].contains(claim.status),
        )
        .toList();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Activity'),
          actions: [
            IconButton(
              tooltip: 'Refresh activity',
              onPressed: activity.retry,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Reports'),
              Tab(text: 'My Claims'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Items needing your attention appear first.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  FilterChip(
                    label: const Text('Needs attention'),
                    selected: _attentionOnly,
                    onSelected: (value) =>
                        setState(() => _attentionOnly = value),
                  ),
                ],
              ),
            ),
            if (activity.hasError)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Some activity could not load. Tap Refresh to reconnect.',
                ),
              ),
            Expanded(
              child: activity.isLoading && reports.isEmpty && claims.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        visibleReports.isEmpty
                            ? EmptyStateView(
                                icon: Icons.assignment_outlined,
                                title: _attentionOnly
                                    ? 'No reports need attention'
                                    : 'No reports yet',
                                subtitle: _attentionOnly
                                    ? 'You can view your full history by clearing Needs attention.'
                                    : 'Your lost and found reports will appear here.',
                                actionButton: _attentionOnly
                                    ? null
                                    : FilledButton.icon(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const ReportItemScreen(),
                                          ),
                                        ),
                                        icon: const Icon(Icons.add),
                                        label: const Text('Report an item'),
                                      ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: visibleReports.length,
                                separatorBuilder: (_, i) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, i) =>
                                    _report(visibleReports[i], activity),
                              ),
                        visibleClaims.isEmpty
                            ? EmptyStateView(
                                icon: Icons.verified_user_outlined,
                                title: _attentionOnly
                                    ? 'No claims need attention'
                                    : 'No claims yet',
                                subtitle: 'Your ownership requests and their next steps appear here.',
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: visibleClaims.length,
                                separatorBuilder: (_, i) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, i) =>
                                    _claim(visibleClaims[i], activity),
                              ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _report(ItemModel item, ActivityProvider activity) {
    final incoming = activity.incoming
        .where((claim) => claim.itemId == item.id)
        .toList();
    final review = incoming
        .where((claim) => ['pending', 'reviewing'].contains(claim.status))
        .length;
    final pickup = incoming.any(
      (claim) => ['approved', 'ready'].contains(claim.status),
    );
    final message = activity.messageFor(item.id);
    final chatClaim = activity.claim(message?.claimId);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  item.type.toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                Text(
                  item.archived ? 'ARCHIVED' : item.status.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              item.archived
                  ? 'Hidden from Explore. Your history stays linked.'
                  : review > 0
                  ? '$review ownership ${review == 1 ? 'claim needs' : 'claims need'} review.'
                  : pickup
                  ? 'Coordinate pickup and confirm the return after handover.'
                  : '${item.location} • ${formatDate(item.date)}',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (chatClaim != null)
                  FilledButton.icon(
                    onPressed: () => _reply(activity, chatClaim),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Reply'),
                  ),
                if (!item.archived && (review > 0 || pickup))
                  FilledButton.icon(
                    onPressed: () async {
                      await _seen(activity, item.id);
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ItemClaimsScreen(item: item),
                        ),
                      );
                    },
                    icon: const Icon(Icons.assignment_outlined),
                    label: Text(
                      review > 0 ? 'Review claims ($review)' : 'Arrange pickup',
                    ),
                  ),
                OutlinedButton(
                  onPressed: () => _view(activity, item.id),
                  child: Text(item.archived ? 'View history' : 'View report'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _claim(ClaimModel claim, ActivityProvider activity) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            claim.itemTitle.isEmpty ? 'Ownership claim' : claim.itemTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ClaimJourney(status: claim.status),
          const SizedBox(height: 12),
          Text(claimGuidance(claim.status)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _reply(activity, claim),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: Text(
                  activity.hasUnreadMessage(claim.itemId)
                      ? 'Reply'
                      : ['approved', 'ready'].contains(claim.status)
                      ? 'Arrange pickup'
                      : 'Message reporter',
                ),
              ),
              OutlinedButton(
                onPressed: () => _view(activity, claim.itemId),
                child: const Text('View report'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
