import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../widgets/user_avatar.dart';
import '../../providers/auth_provider.dart';
import '../../services/claim_service.dart';
import '../../services/item_service.dart';
import '../../services/community_service.dart';
import '../community/alerts_screen.dart';
import '../community/saved_searches_screen.dart';
import '../community/moderation_screen.dart';
import '../community/campus_offices_screen.dart';

/// Campus Hub / User Profile screen displaying user account details,
/// activity summary counters, BSU Alangilan lost & found guidelines,
/// and logout.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Your campus space',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Log out',
            onPressed: () => _confirmLogout(context, authProvider),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── User Header Card ──────────────────────────────────────
            _buildUserHeader(user, colorScheme, theme),
            const SizedBox(height: 16),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_none_rounded),
                    title: const Text('Alerts & match updates'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AlertsScreen(),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.bookmarks_outlined),
                    title: const Text('Saved searches'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SavedSearchesScreen(),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: const Text('Campus pickup offices'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CampusOfficesScreen(),
                      ),
                    ),
                  ),
                  FutureBuilder<bool>(
                    future: CommunityService().canModerate(),
                    builder: (context, snapshot) => snapshot.data == true
                        ? ListTile(
                            leading: const Icon(Icons.shield_outlined),
                            title: const Text('Campus moderation'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ModerationScreen(),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── Activity Summary Stats ────────────────────────────────
            _buildStatsCard(user.id, colorScheme, theme),
            const SizedBox(height: 16),

            // ── Campus Lost & Found Guidelines Card ───────────────────
            _buildCampusGuideCard(colorScheme, theme),
            const SizedBox(height: 16),

            // ── Logout Button ─────────────────────────────────────────
            OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, authProvider),
              icon: Icon(Icons.logout_rounded, color: colorScheme.error),
              label: Text(
                'Log Out',
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: colorScheme.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeader(
    UserModel user,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final roleLabel = user.role.toUpperCase();

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
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            UserAvatar(name: user.name, photoUrl: user.photoUrl),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'BSU $roleLabel',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(
    String userId,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final itemService = ItemService();
    final claimService = ClaimService();

    return StreamBuilder<List>(
      stream: itemService.getItemsByUserStream(userId),
      builder: (context, itemsSnapshot) {
        final reports = itemsSnapshot.data ?? [];
        final reportsCount = reports.length;
        final resolvedCount = reports
            .where((i) => i.status == 'returned')
            .length;

        return StreamBuilder<List>(
          stream: claimService.getClaimsByClaimantStream(userId),
          builder: (context, claimsSnapshot) {
            final claimsCount = (claimsSnapshot.data ?? []).length;

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
                child: Row(
                  children: [
                    _buildStatItem(
                      'Reports',
                      reportsCount.toString(),
                      Icons.assignment_outlined,
                      colorScheme,
                    ),
                    _buildDivider(colorScheme),
                    _buildStatItem(
                      'Resolved',
                      resolvedCount.toString(),
                      Icons.check_circle_outline,
                      colorScheme,
                    ),
                    _buildDivider(colorScheme),
                    _buildStatItem(
                      'Claims',
                      claimsCount.toString(),
                      Icons.verified_user_outlined,
                      colorScheme,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    ColorScheme colorScheme,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 22, color: colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Container(
      height: 36,
      width: 1,
      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }

  Widget _buildCampusGuideCard(ColorScheme colorScheme, ThemeData theme) {
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
            Row(
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'BSU Alangilan Campus Info',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildGuideBullet(
              Icons.location_city_rounded,
              'Security Office',
              'Physical items (IDs, gadgets, keys) can be surrendered or claimed at Gate 1 Main Security Office.',
              colorScheme,
            ),
            const SizedBox(height: 10),
            _buildGuideBullet(
              Icons.verified_user_rounded,
              'Proof of Ownership',
              'When retrieving items, bring your Student/Employee ID or match the secret verification proof reported.',
              colorScheme,
            ),
            const SizedBox(height: 10),
            _buildGuideBullet(
              Icons.headset_mic_rounded,
              'Campus Support',
              'For assistance, reach out to student.affairs@g.batstate-u.edu.ph',
              colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideBullet(
    IconData icon,
    String title,
    String desc,
    ColorScheme colorScheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of FindIt BSU?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              authProvider.logout();
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}
