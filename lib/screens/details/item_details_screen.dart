import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/claim_model.dart';
import '../../models/item_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/claim_service.dart';
import '../../services/item_service.dart';
import '../claims/item_claims_screen.dart';

/// Screen displaying the complete details of a lost or found item,
/// with options to submit an ownership claim, view incoming claims,
/// see possible opposite-type matches, and mark items as returned.
class ItemDetailsScreen extends StatelessWidget {
  final ItemModel item;

  const ItemDetailsScreen({
    super.key,
    required this.item,
  });

  String _formatDate(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'electronics':
        return Icons.devices_rounded;
      case 'clothing':
        return Icons.checkroom_rounded;
      case 'id / cards':
        return Icons.badge_outlined;
      case 'books / notes':
        return Icons.menu_book_rounded;
      case 'bags / wallets':
        return Icons.wallet_rounded;
      case 'keys':
        return Icons.key_rounded;
      case 'accessories':
        return Icons.watch_outlined;
      case 'documents':
        return Icons.description_outlined;
      case 'water bottle / tumbler':
        return Icons.local_drink_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Color _getStatusColor(String status, ColorScheme colorScheme) {
    switch (status.toLowerCase()) {
      case 'open':
        return colorScheme.primary;
      case 'claimed':
        return Colors.orange.shade800;
      case 'returned':
        return Colors.green.shade700;
      default:
        return colorScheme.outline;
    }
  }

  void _showFullscreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              clipBehavior: Clip.none,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.7),
                ),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openClaimForm(BuildContext context, ItemModel item, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _ClaimFormBottomSheet(
        item: item,
        currentUser: user,
      ),
    );
  }

  Future<void> _confirmMarkAsReturned(
    BuildContext context,
    ItemModel item,
    ItemService itemService,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Item as Returned?'),
        content: Text(
          'Confirm that "${item.title}" has been successfully returned to its rightful owner.\n\n'
          'This will update the item status to "Returned" and mark this case as resolved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Returned'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await itemService.updateItemStatus(item.id, 'returned');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${item.title}" marked as Returned!'),
            backgroundColor: Colors.green.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final itemService = ItemService();
    final claimService = ClaimService();
    final currentUser = context.watch<AuthProvider>().currentUser;

    // Listen to real-time updates for this specific item if it changes in Firestore
    return StreamBuilder<ItemModel?>(
      stream: itemService.getItemStream(item.id),
      initialData: item,
      builder: (context, snapshot) {
        final currentItem = snapshot.data ?? item;
        final isLost = currentItem.type.toLowerCase() == 'lost';
        final statusColor = _getStatusColor(currentItem.status, colorScheme);
        final hasPhoto = currentItem.photoUrl != null &&
            currentItem.photoUrl!.isNotEmpty;
        final isOwner = currentUser != null && currentUser.id == currentItem.ownerId;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isLost ? 'Lost Item Details' : 'Found Item Details',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Hero Header Card ───────────────────────────────────────
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badges Row (Type + Status)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isLost
                                    ? Colors.red.shade50
                                    : Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isLost
                                      ? Colors.red.shade200
                                      : Colors.teal.shade200,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isLost
                                        ? Icons.search_rounded
                                        : Icons.inventory_2_outlined,
                                    size: 16,
                                    color: isLost
                                        ? Colors.red.shade800
                                        : Colors.teal.shade800,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isLost ? 'LOST ITEM' : 'FOUND ITEM',
                                    style: TextStyle(
                                      color: isLost
                                          ? Colors.red.shade800
                                          : Colors.teal.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                currentItem.status.toUpperCase(),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Text(
                          currentItem.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Item Photo Card (if photo uploaded) ────────────────────
                if (hasPhoto) ...[
                  Card(
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: InkWell(
                      onTap: () =>
                          _showFullscreenImage(context, currentItem.photoUrl!),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Image.network(
                            currentItem.photoUrl!,
                            height: 240,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 240,
                                color: colorScheme.surfaceContainerHighest,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              height: 160,
                              color: colorScheme.surfaceContainerHighest,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image_rounded,
                                      size: 40,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Failed to load photo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.all(12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.fullscreen_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Tap to enlarge',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Information Key Details Card ───────────────────────────
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        _buildDetailTile(
                          icon: _getCategoryIcon(currentItem.category),
                          label: 'Category',
                          value: currentItem.category,
                          colorScheme: colorScheme,
                        ),
                        const Divider(height: 24),
                        _buildDetailTile(
                          icon: Icons.location_on_rounded,
                          label: 'Campus Location',
                          value: currentItem.location,
                          colorScheme: colorScheme,
                        ),
                        const Divider(height: 24),
                        _buildDetailTile(
                          icon: Icons.calendar_today_rounded,
                          label: isLost ? 'Date Lost' : 'Date Found',
                          value: _formatDate(currentItem.date),
                          colorScheme: colorScheme,
                        ),
                        const Divider(height: 24),
                        _buildDetailTile(
                          icon: Icons.access_time_rounded,
                          label: 'Reported Date',
                          value: _formatDate(currentItem.createdAt),
                          colorScheme: colorScheme,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Description Card ───────────────────────────────────────
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Description',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          currentItem.description.isNotEmpty
                              ? currentItem.description
                              : 'No additional description provided.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Possible Matches Section ───────────────────────────────
                _buildPossibleMatchesSection(
                  context: context,
                  currentItem: currentItem,
                  itemService: itemService,
                  colorScheme: colorScheme,
                  theme: theme,
                ),

                const SizedBox(height: 20),

                // ── Claim & Owner Action Section ───────────────────────────
                if (isOwner) ...[
                  // Current user is the owner — show Incoming Claims & Mark as Returned controls
                  _buildOwnerClaimsSection(
                    context: context,
                    item: currentItem,
                    claimService: claimService,
                    itemService: itemService,
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                ] else if (currentUser != null) ...[
                  // Current user is a potential claimant
                  _buildClaimantSection(
                    context: context,
                    item: currentItem,
                    user: currentUser,
                    claimService: claimService,
                    colorScheme: colorScheme,
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme colorScheme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 22,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// "Possible Matches" section: queries opposite-type items and displays
  /// items matching the same category and similar title keywords or location.
  Widget _buildPossibleMatchesSection({
    required BuildContext context,
    required ItemModel currentItem,
    required ItemService itemService,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    final oppositeType =
        currentItem.type.toLowerCase() == 'lost' ? 'found' : 'lost';

    return StreamBuilder<List<ItemModel>>(
      stream: itemService.getItemsStream(type: oppositeType),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final oppositeItems = snapshot.data ?? [];
        final scoredMatches = _findScoredMatches(currentItem, oppositeItems);

        return Card(
          elevation: 0,
          color: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Possible Matches',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '${oppositeType.toUpperCase()} reports with matching category & keywords/location',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (scoredMatches.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${scoredMatches.length} Match${scoredMatches.length == 1 ? '' : 'es'}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                if (scoredMatches.isEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 22,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No matching $oppositeType items found yet with similar title keywords or location.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // List of matching items
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: scoredMatches.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final match = scoredMatches[index];
                      return _PossibleMatchTile(
                        item: match.item,
                        reason: match.reason,
                        colorScheme: colorScheme,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Owner section showing incoming claim counts, review button, and "Mark as Returned".
  Widget _buildOwnerClaimsSection({
    required BuildContext context,
    required ItemModel item,
    required ClaimService claimService,
    required ItemService itemService,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    final isReturned = item.status.toLowerCase() == 'returned';

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Your Report (Owner Controls)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Manage incoming claims for this item and mark it as returned once the exchange is complete.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),

            // Claims Review Button
            StreamBuilder<List<ClaimModel>>(
              stream: claimService.getClaimsForItemStream(item.id),
              builder: (context, snapshot) {
                final claims = snapshot.data ?? [];
                final pendingCount =
                    claims.where((c) => c.status == 'pending').length;

                return FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ItemClaimsScreen(item: item),
                      ),
                    );
                  },
                  icon: const Icon(Icons.inbox_rounded),
                  label: Text(
                    pendingCount > 0
                        ? 'Review Claims ($pendingCount Pending)'
                        : 'View Claims (${claims.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 10),

            // Mark as Returned Action or Resolved Banner
            if (isReturned) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This item has been marked as RETURNED and resolved.',
                        style: TextStyle(
                          color: Colors.green.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              OutlinedButton.icon(
                onPressed: () =>
                    _confirmMarkAsReturned(context, item, itemService),
                icon: const Icon(Icons.assignment_turned_in_rounded, size: 18),
                label: const Text('Mark as Returned'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade800,
                  side: BorderSide(color: Colors.green.shade700),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Claimant section: shows "Claim This Item" button or existing claim status.
  Widget _buildClaimantSection({
    required BuildContext context,
    required ItemModel item,
    required UserModel user,
    required ClaimService claimService,
    required ColorScheme colorScheme,
  }) {
    return StreamBuilder<ClaimModel?>(
      stream: claimService.getClaimByClaimantStream(
        itemId: item.id,
        claimantId: user.id,
      ),
      builder: (context, snapshot) {
        final existingClaim = snapshot.data;

        // If user has already submitted a claim for this item
        if (existingClaim != null) {
          Color claimBadgeColor;
          IconData claimIcon;
          String statusMsg;

          switch (existingClaim.status.toLowerCase()) {
            case 'approved':
              claimBadgeColor = Colors.green.shade700;
              claimIcon = Icons.check_circle_rounded;
              statusMsg =
                  'Your claim has been APPROVED by the poster! Coordinate with them to retrieve the item.';
              break;
            case 'rejected':
              claimBadgeColor = colorScheme.error;
              claimIcon = Icons.cancel_rounded;
              statusMsg =
                  'Your claim was reviewed and was not approved by the poster.';
              break;
            default:
              claimBadgeColor = Colors.orange.shade800;
              claimIcon = Icons.hourglass_top_rounded;
              statusMsg =
                  'Your claim has been submitted. The poster is reviewing your secret verification proof.';
          }

          return Card(
            elevation: 0,
            color: claimBadgeColor.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: claimBadgeColor.withValues(alpha: 0.3),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(claimIcon, color: claimBadgeColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Your Claim Status: ${existingClaim.status.toUpperCase()}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: claimBadgeColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    statusMsg,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Item is already claimed or returned by someone else
        if (item.status.toLowerCase() != 'open') {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This item is marked as ${item.status.toUpperCase()} and cannot be claimed.',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Item is open and current user hasn't claimed yet — Show "Claim This Item"
        return FilledButton.icon(
          onPressed: () => _openClaimForm(context, item, user),
          icon: const Icon(Icons.verified_user_rounded),
          label: const Text(
            'Claim This Item',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      },
    );
  }
}

/// Helper model for ranked possible matches.
class _ScoredMatch {
  final ItemModel item;
  final String reason;
  final int score;

  const _ScoredMatch({
    required this.item,
    required this.reason,
    required this.score,
  });
}

const Set<String> _commonMatchStopWords = {
  'the', 'and', 'for', 'with', 'from', 'this', 'that', 'lost', 'found',
  'item', 'have', 'has', 'near', 'around', 'area', 'bsu', 'color',
  'black', 'white', 'blue', 'red', 'large', 'small', 'old', 'new',
};

List<_ScoredMatch> _findScoredMatches(
  ItemModel currentItem,
  List<ItemModel> oppositeItems,
) {
  final currentTitleTokens = currentItem.title
      .toLowerCase()
      .split(RegExp(r'[^a-zA-Z0-9]+'))
      .where((w) => w.length >= 3 && !_commonMatchStopWords.contains(w))
      .toSet();

  final results = <_ScoredMatch>[];

  for (final other in oppositeItems) {
    if (other.id == currentItem.id) continue;

    // 1. Same category requirement
    if (other.category.toLowerCase() != currentItem.category.toLowerCase()) {
      continue;
    }

    // 2. Title keywords similarity
    final otherTitleTokens = other.title
        .toLowerCase()
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .where((w) => w.length >= 3 && !_commonMatchStopWords.contains(w))
        .toSet();

    final sharedWords = currentTitleTokens.intersection(otherTitleTokens);
    final hasKeywordMatch = sharedWords.isNotEmpty;

    // 3. Location match
    final hasLocationMatch =
        other.location.toLowerCase() == currentItem.location.toLowerCase();

    // Match if category matches AND (similar keywords OR same location)
    if (hasKeywordMatch || hasLocationMatch) {
      int score = 0;
      String reason;

      if (hasKeywordMatch && hasLocationMatch) {
        score = 3;
        reason = 'Same Location & Keyword "${sharedWords.first}"';
      } else if (hasKeywordMatch) {
        score = 2;
        reason = 'Matching Keyword "${sharedWords.join(', ')}"';
      } else {
        score = 1;
        reason = 'Matching Campus Location';
      }

      results.add(_ScoredMatch(item: other, reason: reason, score: score));
    }
  }

  // Sort by highest score first, then newest
  results.sort((a, b) {
    if (b.score != a.score) return b.score.compareTo(a.score);
    return b.item.createdAt.compareTo(a.item.createdAt);
  });

  return results;
}

/// A compact card for displaying a possible opposite-type match.
class _PossibleMatchTile extends StatelessWidget {
  final ItemModel item;
  final String reason;
  final ColorScheme colorScheme;

  const _PossibleMatchTile({
    required this.item,
    required this.reason,
    required this.colorScheme,
  });

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isLost = item.type.toLowerCase() == 'lost';

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ItemDetailsScreen(item: item),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Match badge row
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 12,
                          color: Colors.amber.shade900,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          reason,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isLost ? Colors.red.shade50 : Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            isLost ? Colors.red.shade200 : Colors.teal.shade200,
                      ),
                    ),
                    child: Text(
                      item.type.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color:
                            isLost ? Colors.red.shade800 : Colors.teal.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo Thumbnail or Category Icon
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: item.photoUrl != null && item.photoUrl!.isNotEmpty
                        ? Image.network(
                            item.photoUrl!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              width: 56,
                              height: 56,
                              color: colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.category_outlined,
                                color: colorScheme.primary,
                                size: 24,
                              ),
                            ),
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            color: colorScheme.primary.withValues(alpha: 0.08),
                            child: Icon(
                              Icons.category_outlined,
                              color: colorScheme.primary,
                              size: 24,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                item.location,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _formatDate(item.date),
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 14,
                                  color: colorScheme.primary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet containing the claim form: message and "something only the owner would know".
class _ClaimFormBottomSheet extends StatefulWidget {
  final ItemModel item;
  final UserModel currentUser;

  const _ClaimFormBottomSheet({
    required this.item,
    required this.currentUser,
  });

  @override
  State<_ClaimFormBottomSheet> createState() => _ClaimFormBottomSheetState();
}

class _ClaimFormBottomSheetState extends State<_ClaimFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _proofController = TextEditingController();
  final ClaimService _claimService = ClaimService();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _messageController.dispose();
    _proofController.dispose();
    super.dispose();
  }

  Future<void> _submitClaim() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      await _claimService.submitClaim(
        itemId: widget.item.id,
        itemTitle: widget.item.title,
        ownerId: widget.item.ownerId,
        claimantId: widget.currentUser.id,
        claimantName: widget.currentUser.name,
        claimantEmail: widget.currentUser.email,
        message: _messageController.text.trim(),
        proof: _proofController.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Claim submitted for "${widget.item.title}"! The owner will review your verification.',
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to submit claim: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sheet handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified_user_rounded,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Claim This Item',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.item.title,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Info note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'To prevent false claims, provide a message and specific details that only the true owner would know.',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 1. Message Field
              TextFormField(
                controller: _messageController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Message to Finder / Poster',
                  hintText:
                      'e.g. When and where you lost it, or your contact preference...',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.chat_bubble_outline_rounded),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a brief message.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 2. Secret Proof Field ("Something only the owner would know")
              TextFormField(
                controller: _proofController,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Something only the owner would know',
                  hintText:
                      'e.g. Lock screen photo, specific sticker, item contents, serial number, unique mark...',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.vpn_key_rounded),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please describe something only the true owner would know.';
                  }
                  if (val.trim().length < 5) {
                    return 'Please provide more details (at least 5 characters).';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Error banner
              if (_errorMessage != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Submit Button
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submitClaim,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isSubmitting ? 'Submitting Claim…' : 'Submit Claim',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
