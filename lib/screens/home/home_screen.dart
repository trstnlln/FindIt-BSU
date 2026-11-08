import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/device_alerts.dart';

import 'package:provider/provider.dart';

import '../../models/item_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/item_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/item_card.dart';
import '../../widgets/brand_logo.dart';
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
  late final Stream<List<ItemModel>> _lostItems = _itemService.getItemsStream(
    type: 'lost',
  );
  late final Stream<List<ItemModel>> _foundItems = _itemService.getItemsStream(
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
      bottomNavigationBar: NavigationBar(
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
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const BrandLogo(size: 38),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FindIt BSU',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    user != null ? 'Hi, ${user.name}' : 'BSU Alangilan',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            const AlertsBell(),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Log out',
              onPressed: () => _confirmLogout(context),
            ),
          ],
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
              Tab(icon: Icon(Icons.search_rounded), text: 'Lost Items'),
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Found Items'),
            ],
          ),
        ),
        body: Column(
          children: [
            // ── Search & Filter Controls ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spartans look out for Spartans.',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.6,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lost something? Let’s bring it home.',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildSearchAndFilterHeader(colorScheme),

            // ── Tab View Feed ────────────────────────────────────────
            Expanded(
              child: TabBarView(
                children: [
                  _ItemStreamList(
                    itemsStream: _lostItems,
                    type: 'lost',
                    searchQuery: _searchQuery,
                    selectedCategory: _selectedCategory,
                    selectedLocation: _selectedLocation,
                    selectedStatus: _selectedStatus,
                    selectedDate: _selectedDate,
                    onResetFilters: _resetFilters,
                  ),
                  _ItemStreamList(
                    itemsStream: _foundItems,
                    type: 'found',
                    searchQuery: _searchQuery,
                    selectedCategory: _selectedCategory,
                    selectedLocation: _selectedLocation,
                    selectedStatus: _selectedStatus,
                    selectedDate: _selectedDate,
                    onResetFilters: _resetFilters,
                  ),
                ],
              ),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
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
              hintText: 'Search items, places, or descriptions',
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
                              'Saved. New matching reports will appear in your alerts.',
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

  void _confirmLogout(BuildContext context) {
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
              context.read<AuthProvider>().logout();
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}

/// Builds the real-time list of items for a specific [type] ('lost' or 'found')
/// with keyword search and category/location/status/date filters applied.
class _ItemStreamList extends StatelessWidget {
  final Stream<List<ItemModel>> itemsStream;
  final String type;
  final String searchQuery;
  final String? selectedCategory;
  final String? selectedLocation;
  final String? selectedStatus;
  final DateTime? selectedDate;
  final VoidCallback onResetFilters;

  const _ItemStreamList({
    required this.itemsStream,
    required this.type,
    required this.searchQuery,
    required this.selectedCategory,
    required this.selectedLocation,
    required this.selectedStatus,
    required this.selectedDate,
    required this.onResetFilters,
  });

  bool get _isFiltering =>
      searchQuery.isNotEmpty ||
      selectedCategory != null ||
      selectedLocation != null ||
      selectedStatus != null ||
      selectedDate != null;

  @override
  Widget build(BuildContext context) {
    final isLost = type == 'lost';

    return StreamBuilder<List<ItemModel>>(
      stream: itemsStream,
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 56,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Unable to load items',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final allItems = snapshot.data ?? [];

        // Base empty state (no items reported at all in this tab)
        if (allItems.isEmpty) {
          return EmptyStateView(
            icon: isLost
                ? Icons.search_off_rounded
                : Icons.check_circle_outline_rounded,
            title: isLost
                ? 'No Lost Items Reported'
                : 'No Found Items Reported',
            subtitle: isLost
                ? 'Items reported as lost will appear here in real time.'
                : 'Items reported as found will appear here in real time.',
          );
        }

        // Apply Search & Filters
        final filteredItems = allItems.where((item) {
          // 1. Keyword search (matches title, description, category, location, or room)
          if (searchQuery.isNotEmpty) {
            final q = searchQuery.toLowerCase();
            final matchesTitle = item.title.toLowerCase().contains(q);
            final matchesDesc = item.description.toLowerCase().contains(q);
            final matchesCat = item.category.toLowerCase().contains(q);
            final matchesLoc = item.location.toLowerCase().contains(q);
            final matchesSpecific =
                item.specificLocation?.toLowerCase().contains(q) ?? false;
            final matchesCustody =
                item.custodyLocation?.toLowerCase().contains(q) ?? false;

            if (!matchesTitle &&
                !matchesDesc &&
                !matchesCat &&
                !matchesLoc &&
                !matchesSpecific &&
                !matchesCustody) {
              return false;
            }
          }

          // 2. Category filter
          if (selectedCategory != null && selectedCategory != 'All') {
            if (item.category.toLowerCase() !=
                selectedCategory!.toLowerCase()) {
              return false;
            }
          }

          // 3. Location filter
          if (selectedLocation != null && selectedLocation != 'All') {
            if (item.location.toLowerCase() !=
                selectedLocation!.toLowerCase()) {
              return false;
            }
          }

          // 4. Status filter
          if (selectedStatus != null) {
            if (item.status.toLowerCase() != selectedStatus!.toLowerCase()) {
              return false;
            }
          }

          // 5. Date filter (exact day match)
          if (selectedDate != null) {
            if (item.date.year != selectedDate!.year ||
                item.date.month != selectedDate!.month ||
                item.date.day != selectedDate!.day) {
              return false;
            }
          }

          return true;
        }).toList();

        // Filtered empty state (items exist, but none match criteria)
        if (filteredItems.isEmpty && _isFiltering) {
          return EmptyStateView(
            icon: Icons.filter_alt_off_rounded,
            title: 'No Matching Items Found',
            subtitle: 'Try adjusting your search query, category, location, status, or date filter.',
            actionButton: OutlinedButton.icon(
              onPressed: onResetFilters,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('Reset Search & Filters'),
            ),
          );
        }

        // Populated List using extracted modular ItemCard
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          itemCount: filteredItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            return ItemCard(item: item);
          },
        );
      },
    );
  }
}
