import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/claim_model.dart';
import '../../models/item_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/claim_service.dart';
import '../../services/item_service.dart';
import '../../widgets/claim_journey.dart';
import '../claims/item_claims_screen.dart';
import '../details/item_details_screen.dart';
import '../report/report_item_screen.dart';

/// Screen displaying user's personal activity:
/// - Tab 1: Items Reported by the current user
/// - Tab 2: Claims Submitted by the current user
class MyActivityScreen extends StatefulWidget {
  const MyActivityScreen({super.key});

  @override
  State<MyActivityScreen> createState() => _MyActivityScreenState();
}

class _MyActivityScreenState extends State<MyActivityScreen> {
  final ItemService _itemService = ItemService();
  final ClaimService _claimService = ClaimService();

  String _formatDate(DateTime dt) {
    if (dt.millisecondsSinceEpoch == 0) return 'Date unavailable';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentUser = context.watch<AuthProvider>().currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view your activity.')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Activity',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            indicatorColor: colorScheme.primary,
            indicatorWeight: 3,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            tabs: const [
              Tab(icon: Icon(Icons.assignment_outlined), text: 'My Reports'),
              Tab(icon: Icon(Icons.verified_user_outlined), text: 'My Claims'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMyReportsTab(currentUser.id, colorScheme, theme),
            _buildMyClaimsTab(currentUser.id, colorScheme, theme),
          ],
        ),
      ),
    );
  }

  // ─── Tab 1: My Reports ───────────────────────────────────────────────────

  Widget _buildMyReportsTab(
    String userId,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return StreamBuilder<List<ItemModel>>(
      stream: _itemService.getItemsByUserStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error loading reports: ${snapshot.error}'),
            ),
          );
        }

        final myItems = snapshot.data ?? [];

        if (myItems.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.note_add_outlined,
                      size: 36,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'No Reports Created Yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Items you report as lost or found will be displayed here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReportItemScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Report an Item'),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: myItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = myItems[index];
            return _buildMyReportCard(item, colorScheme, theme);
          },
        );
      },
    );
  }

  Widget _buildMyReportCard(
    ItemModel item,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final isLost = item.type.toLowerCase() == 'lost';

    Color statusColor;
    switch (item.status.toLowerCase()) {
      case 'open':
        statusColor = colorScheme.primary;
        break;
      case 'claimed':
        statusColor = Colors.orange.shade800;
        break;
      case 'returned':
        statusColor = Colors.green.shade700;
        break;
      default:
        statusColor = colorScheme.outline;
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ItemDetailsScreen(item: item)),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Type pill + Title + Status Pill
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isLost ? Colors.red.shade50 : Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isLost
                            ? Colors.red.shade200
                            : Colors.teal.shade200,
                      ),
                    ),
                    child: Text(
                      item.type.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isLost
                            ? Colors.red.shade800
                            : Colors.teal.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.specificLocation != null &&
                              item.specificLocation!.trim().isNotEmpty
                          ? '${item.location} • ${item.specificLocation}'
                          : item.location,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatTimeAgo(item.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action buttons row (Review Claims)
              StreamBuilder<List<ClaimModel>>(
                stream: _claimService.getClaimsForItemStream(
                  item.id,
                  ownerId: item.ownerId,
                ),
                builder: (context, snapshot) {
                  final claims = snapshot.data ?? [];
                  final pendingCount = claims
                      .where((c) => c.status == 'pending')
                      .length;

                  return Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ItemClaimsScreen(item: item),
                              ),
                            );
                          },
                          icon: Icon(
                            Icons.inbox_rounded,
                            size: 16,
                            color: pendingCount > 0
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          label: Text(
                            pendingCount > 0
                                ? 'Claims ($pendingCount Pending)'
                                : 'Claims (${claims.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: pendingCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: pendingCount > 0
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: pendingCount > 0
                                  ? colorScheme.primary
                                  : colorScheme.outlineVariant,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        tooltip: 'View Details',
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ItemDetailsScreen(item: item),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tab 2: My Claims ───────────────────────────────────────────────────

  Widget _buildMyClaimsTab(
    String userId,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    return StreamBuilder<List<ClaimModel>>(
      stream: _claimService.getClaimsByClaimantStream(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error loading claims: ${snapshot.error}'),
            ),
          );
        }

        final myClaims = snapshot.data ?? [];

        if (myClaims.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified_user_outlined,
                      size: 36,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'No Claims Submitted Yet',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'When you claim an item from the Lost & Found feed, its status will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: myClaims.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final claim = myClaims[index];
            return _buildMyClaimCard(claim, colorScheme, theme);
          },
        );
      },
    );
  }

  Widget _buildMyClaimCard(
    ClaimModel claim,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    Color statusColor;
    IconData statusIcon;
    switch (claim.status.toLowerCase()) {
      case 'approved':
        statusColor = Colors.green.shade700;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        statusColor = colorScheme.error;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = Colors.orange.shade800;
        statusIcon = Icons.hourglass_top_rounded;
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClaimJourney(status: claim.status),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    claim.itemTitle.isNotEmpty
                        ? claim.itemTitle
                        : 'Claim Request',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    claim.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (claim.proof.isNotEmpty) ...[
              Text(
                'Verification Proof Provided:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                claim.proof,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Submitted: ${_formatDate(claim.createdAt)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final item = await ItemService().getItem(claim.itemId);
                    if (!mounted) return;
                    if (item != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ItemDetailsScreen(item: item),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Item is no longer available.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  label: const Text('View Item'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
