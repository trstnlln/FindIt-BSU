import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/device_alerts.dart';

import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/item_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/campus_report_feed.dart';
import '../../widgets/campus_header.dart';
import '../../widgets/alerts_bell.dart';
import '../../services/community_service.dart';
import '../../models/user_model.dart';
import '../activity/my_activity_screen.dart';
import '../profile/profile_screen.dart';
import '../report/report_item_screen.dart';

/// Main screen with Bottom Navigation Bar:
/// 0: Explore Feed (Lost & Found Tabs, Search, Category/Location/Date/Status filters)
/// 1: My Activity (My Reports & My Claims tabs)
/// 2: Campus Hub (User Profile, Stats, BSU Guidelines, Role Switcher)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // 0 = Explore, 1 = My Activity, 2 = Campus Hub

  final ItemService _itemService = ItemService();
  late Stream<List<ItemModel>> _lostItems = _itemService.getItemsStream(
    type: 'lost',
  );
  late Stream<List<ItemModel>> _foundItems = _itemService.getItemsStream(
    type: 'found',
  );
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedLocation;
  String? _selectedStatus; // null = All, 'open', 'claimed', 'returned'
  DateTime? _selectedDate;

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedCategory != null ||
      _selectedLocation != null ||
      _selectedStatus != null ||
      _selectedDate != null;

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategory != null) count++;
    if (_selectedLocation != null) count++;
    if (_selectedStatus != null) count++;
    if (_selectedDate != null) count++;
    return count;
  }

  @override
  void initState() {
    super.initState();
    unawaited(DeviceAlerts.restore());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _retryFeed() {
    setState(() {
      _lostItems = _itemService.getItemsStream(type: 'lost');
      _foundItems = _itemService.getItemsStream(type: 'found');
    });
  }

  void _resetFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategory = null;
      _selectedLocation = null;
      _selectedStatus = null;
      _selectedDate = null;
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      helpText: 'Filter items by date',
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Filter by Category',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.clear_all_rounded),
                title: const Text('All Categories'),
                trailing: _selectedCategory == null
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  setState(() => _selectedCategory = null);
                  Navigator.of(ctx).pop();
                },
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: itemCategories.length,
                  itemBuilder: (context, index) {
                    final cat = itemCategories[index];
                    final isSelected = _selectedCategory == cat;
                    return ListTile(
                      title: Text(cat),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        setState(() => _selectedCategory = cat);
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Filter by Campus Location',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.clear_all_rounded),
                title: const Text('All Locations'),
                trailing: _selectedLocation == null
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  setState(() => _selectedLocation = null);
                  Navigator.of(ctx).pop();
                },
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: campusLocations.length,
                  itemBuilder: (context, index) {
                    final loc = campusLocations[index];
                    final isSelected = _selectedLocation == loc;
                    return ListTile(
                      title: Text(loc),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        setState(() => _selectedLocation = loc);
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatusPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Filter by Item Status',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.clear_all_rounded),
                title: const Text('All Statuses (Open, Claimed, Returned)'),
                trailing: _selectedStatus == null
                    ? Icon(
                        Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  setState(() => _selectedStatus = null);
                  Navigator.of(ctx).pop();
                },
              ),
              const Divider(height: 1),
              ...itemStatuses.map((s) {
                final isSelected = _selectedStatus == s['value'];
                return ListTile(
                  title: Text(s['label']!),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    setState(() => _selectedStatus = s['value']);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildExploreFeedScreen(colorScheme, user),
          const MyActivityScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFECE7E9))),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.search_rounded),
              selectedIcon: Icon(Icons.search_rounded),
              label: 'Explore',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment_rounded),
              label: 'My Activity',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                final user = context.read<AuthProvider>().currentUser;
                if (user == null ||
                    !AuthProvider.isBatStateUEmail(user.email)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Domain Restricted: Only users with a valid @g.batstate-u.edu.ph email address can post items.',
                      ),
                      backgroundColor: colorScheme.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReportItemScreen()),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Report item'),
            )
          : null,
    );
  }

  // ─── Tab 0: Explore Feed Screen ─────────────────────────────────────────

  Widget _buildExploreFeedScreen(ColorScheme colorScheme, UserModel? user) {
    return DefaultTabController(
      length: 2,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            toolbarHeight:
                72 + (MediaQuery.textScalerOf(context).scale(18) - 18) * 2,
            title: CampusAppBarTitle(name: user?.name),
            actions: const [AlertsBell(), SizedBox(width: 12)],
          ),
          const SliverToBoxAdapter(child: CampusWelcome()),
          SliverToBoxAdapter(child: _buildSearchAndFilterHeader(colorScheme)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _FeedTabs(
              height: 56 + (MediaQuery.textScalerOf(context).scale(14) - 14),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: TabBar(
                  dividerHeight: 0,
                  indicator: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  labelColor: colorScheme.onPrimary,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                  tabs: const [
                    Tab(text: 'Lost Items'),
                    Tab(text: 'Found Items'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          children: [
            for (final type in ['lost', 'found'])
              CampusReportFeed(
                key: ValueKey(type),
                itemsStream: type == 'lost' ? _lostItems : _foundItems,
                type: type,
                searchQuery: _searchQuery,
                selectedCategory: _selectedCategory,
                selectedLocation: _selectedLocation,
                selectedStatus: _selectedStatus,
                selectedDate: _selectedDate,
                onResetFilters: _resetFilters,
                onRetry: _retryFeed,
              ),
          ],
        ),
      ),
    );
  }

  /// Search input field and horizontally scrollable filter chips.
  Widget _buildSearchAndFilterHeader(ColorScheme colorScheme) {
    final dateLabel = _selectedDate != null
        ? '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}'
        : null;

    final statusLabel = _selectedStatus != null
        ? itemStatuses.firstWhere((s) => s['value'] == _selectedStatus)['label']
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        children: [
          // ── Search TextField ────────────────────────────────────────
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: 'Search items or places',
              labelText: 'Search campus reports',
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              hintStyle: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.45,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Filter Chips Bar ────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: const Text('Save search'),
                  onPressed: () async {
                    try {
                      await CommunityService().saveSearch(
                        query: _searchQuery,
                        category: _selectedCategory,
                        location: _selectedLocation,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Search saved. Open it from Profile → Saved searches.',
                            ),
                          ),
                        );
                      }
                    } catch (_) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Enter a keyword or choose a category/location, then try saving again.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(width: 8),
                // Category Filter Chip
                FilterChip(
                  avatar: Icon(
                    Icons.category_outlined,
                    size: 15,
                    color: _selectedCategory != null
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  label: Text(
                    _selectedCategory != null
                        ? 'Cat: $_selectedCategory'
                        : 'Category',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _selectedCategory != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  selected: _selectedCategory != null,
                  onSelected: (_) => _showCategoryPicker(),
                  showCheckmark: false,
                  deleteIcon: _selectedCategory != null
                      ? const Icon(Icons.close_rounded, size: 14)
                      : null,
                  onDeleted: _selectedCategory != null
                      ? () => setState(() => _selectedCategory = null)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(width: 8),

                // Location Filter Chip
                FilterChip(
                  avatar: Icon(
                    Icons.location_on_outlined,
                    size: 15,
                    color: _selectedLocation != null
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  label: Text(
                    _selectedLocation != null
                        ? 'Loc: $_selectedLocation'
                        : 'Location',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _selectedLocation != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  selected: _selectedLocation != null,
                  onSelected: (_) => _showLocationPicker(),
                  showCheckmark: false,
                  deleteIcon: _selectedLocation != null
                      ? const Icon(Icons.close_rounded, size: 14)
                      : null,
                  onDeleted: _selectedLocation != null
                      ? () => setState(() => _selectedLocation = null)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(width: 8),

                // Status Filter Chip
                FilterChip(
                  avatar: Icon(
                    Icons.flag_outlined,
                    size: 15,
                    color: _selectedStatus != null
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  label: Text(
                    statusLabel != null ? 'Status: $statusLabel' : 'Status',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _selectedStatus != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  selected: _selectedStatus != null,
                  onSelected: (_) => _showStatusPicker(),
                  showCheckmark: false,
                  deleteIcon: _selectedStatus != null
                      ? const Icon(Icons.close_rounded, size: 14)
                      : null,
                  onDeleted: _selectedStatus != null
                      ? () => setState(() => _selectedStatus = null)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(width: 8),

                // Date Filter Chip
                FilterChip(
                  avatar: Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: _selectedDate != null
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  label: Text(
                    dateLabel != null ? 'Date: $dateLabel' : 'Date',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _selectedDate != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  selected: _selectedDate != null,
                  onSelected: (_) => _pickDate(),
                  showCheckmark: false,
                  deleteIcon: _selectedDate != null
                      ? const Icon(Icons.close_rounded, size: 14)
                      : null,
                  onDeleted: _selectedDate != null
                      ? () => setState(() => _selectedDate = null)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                // Clear All Filters Chip (if active)
                if (_hasActiveFilters) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: Icon(
                      Icons.restart_alt_rounded,
                      size: 16,
                      color: colorScheme.error,
                    ),
                    label: Text(
                      'Clear (${_activeFilterCount + (_searchQuery.isNotEmpty ? 1 : 0)})',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _resetFilters,
                    backgroundColor: colorScheme.errorContainer.withValues(
                      alpha: 0.3,
                    ),
                    side: BorderSide(
                      color: colorScheme.error.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedTabs extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  const _FeedTabs({required this.child, required this.height});
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(color: Theme.of(context).scaffoldBackgroundColor, child: child);
  @override
  bool shouldRebuild(covariant _FeedTabs oldDelegate) =>
      height != oldDelegate.height || child != oldDelegate.child;
}
