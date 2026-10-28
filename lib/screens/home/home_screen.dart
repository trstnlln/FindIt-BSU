import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/item_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/item_service.dart';
import '../details/item_details_screen.dart';
import '../report/report_item_screen.dart';

/// Home screen with two tabs: "Lost" and "Found".
///
/// Features:
/// - Real-time Firestore synchronization via StreamBuilder
/// - Search by keyword (title, description, category, location)
/// - Filters for Category, Campus Location, and Date
/// - Tab switching between Lost Items and Found Items
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ItemService _itemService = ItemService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedLocation;
  DateTime? _selectedDate;

  static const List<String> _categories = [
    'Electronics',
    'Clothing',
    'ID / Cards',
    'Books / Notes',
    'Bags / Wallets',
    'Keys',
    'Accessories',
    'Documents',
    'Water Bottle / Tumbler',
    'Other',
  ];

  static const List<String> _campusLocations = [
    'Main Academic Building',
    'College of Engineering',
    'College of Arts & Sciences',
    'College of Informatics & Computing Sciences',
    'College of Industrial Technology',
    'College of Nursing',
    'Library',
    'Gymnasium',
    'Canteen / Food Court',
    'Student Center',
    'Parking Area',
    'Covered Court',
    'Gate 1 Entrance',
    'Gate 2 Entrance',
    'Other',
  ];

  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedCategory != null ||
      _selectedLocation != null ||
      _selectedDate != null;

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategory != null) count++;
    if (_selectedLocation != null) count++;
    if (_selectedDate != null) count++;
    return count;
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
    if (picked != null) {
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.clear_all_rounded),
                title: const Text('All Categories'),
                trailing: _selectedCategory == null
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary)
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
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory == cat;
                    return ListTile(
                      title: Text(cat),
                      trailing: isSelected
                          ? Icon(Icons.check_rounded,
                              color: Theme.of(context).colorScheme.primary)
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.clear_all_rounded),
                title: const Text('All Locations'),
                trailing: _selectedLocation == null
                    ? Icon(Icons.check_rounded,
                        color: Theme.of(context).colorScheme.primary)
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
                  itemCount: _campusLocations.length,
                  itemBuilder: (context, index) {
                    final loc = _campusLocations[index];
                    final isSelected = _selectedLocation == loc;
                    return ListTile(
                      title: Text(loc),
                      trailing: isSelected
                          ? Icon(Icons.check_rounded,
                              color: Theme.of(context).colorScheme.primary)
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = context.watch<AuthProvider>().currentUser;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FindIt BSU',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
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
              Tab(
                icon: Icon(Icons.search_rounded),
                text: 'Lost Items',
              ),
              Tab(
                icon: Icon(Icons.inventory_2_outlined),
                text: 'Found Items',
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // ── Search & Filter Controls ─────────────────────────────
            _buildSearchAndFilterHeader(colorScheme),

            // ── Tab View Feed ────────────────────────────────────────
            Expanded(
              child: TabBarView(
                children: [
                  _ItemStreamList(
                    itemService: _itemService,
                    type: 'lost',
                    searchQuery: _searchQuery,
                    selectedCategory: _selectedCategory,
                    selectedLocation: _selectedLocation,
                    selectedDate: _selectedDate,
                    onResetFilters: _resetFilters,
                  ),
                  _ItemStreamList(
                    itemService: _itemService,
                    type: 'found',
                    searchQuery: _searchQuery,
                    selectedCategory: _selectedCategory,
                    selectedLocation: _selectedLocation,
                    selectedDate: _selectedDate,
                    onResetFilters: _resetFilters,
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReportItemScreen()),
            );
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Report Item'),
        ),
      ),
    );
  }

  /// Search input field and horizontally scrollable filter chips.
  Widget _buildSearchAndFilterHeader(ColorScheme colorScheme) {
    final dateLabel = _selectedDate != null
        ? '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}'
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
              hintText: 'Search by keyword (title, desc, item)...',
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
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
                    backgroundColor: colorScheme.errorContainer.withValues(alpha: 0.3),
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
/// with keyword search and category/location/date filters applied.
class _ItemStreamList extends StatelessWidget {
  final ItemService itemService;
  final String type;
  final String searchQuery;
  final String? selectedCategory;
  final String? selectedLocation;
  final DateTime? selectedDate;
  final VoidCallback onResetFilters;

  const _ItemStreamList({
    required this.itemService,
    required this.type,
    required this.searchQuery,
    required this.selectedCategory,
    required this.selectedLocation,
    required this.selectedDate,
    required this.onResetFilters,
  });

  bool get _isFiltering =>
      searchQuery.isNotEmpty ||
      selectedCategory != null ||
      selectedLocation != null ||
      selectedDate != null;

  @override
  Widget build(BuildContext context) {
    final isLost = type == 'lost';

    return StreamBuilder<List<ItemModel>>(
      stream: itemService.getItemsStream(type: type),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isLost
                          ? Icons.search_off_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 38,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isLost ? 'No Lost Items Reported' : 'No Found Items Reported',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isLost
                        ? 'Items reported as lost will appear here in real time.'
                        : 'Items reported as found will appear here in real time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Apply Search & Filters
        final filteredItems = allItems.where((item) {
          // 1. Keyword search (matches title, description, category, or location)
          if (searchQuery.isNotEmpty) {
            final q = searchQuery.toLowerCase();
            final matchesTitle = item.title.toLowerCase().contains(q);
            final matchesDesc = item.description.toLowerCase().contains(q);
            final matchesCat = item.category.toLowerCase().contains(q);
            final matchesLoc = item.location.toLowerCase().contains(q);
            if (!matchesTitle && !matchesDesc && !matchesCat && !matchesLoc) {
              return false;
            }
          }

          // 2. Category filter
          if (selectedCategory != null && selectedCategory != 'All') {
            if (item.category.toLowerCase() != selectedCategory!.toLowerCase()) {
              return false;
            }
          }

          // 3. Location filter
          if (selectedLocation != null && selectedLocation != 'All') {
            if (item.location.toLowerCase() != selectedLocation!.toLowerCase()) {
              return false;
            }
          }

          // 4. Date filter (exact day match)
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.filter_alt_off_rounded,
                      size: 34,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'No Matching Items Found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Try adjusting your search query, category, location, or date filter.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: onResetFilters,
                    icon: const Icon(Icons.restart_alt_rounded, size: 16),
                    label: const Text('Reset Search & Filters'),
                  ),
                ],
              ),
            ),
          );
        }

        // Populated List
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          itemCount: filteredItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            return _ItemCard(item: item);
          },
        );
      },
    );
  }
}

/// A card representing a single item in the feed.
class _ItemCard extends StatelessWidget {
  final ItemModel item;

  const _ItemCard({required this.item});

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = _getStatusColor(item.status, colorScheme);
    final hasPhoto = item.photoUrl != null && item.photoUrl!.isNotEmpty;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Thumbnail or Category Icon Placeholder
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: hasPhoto
                    ? Image.network(
                        item.photoUrl!,
                        width: 78,
                        height: 78,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            width: 78,
                            height: 78,
                            color: colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            _buildCategoryAvatar(colorScheme),
                      )
                    : _buildCategoryAvatar(colorScheme),
              ),

              const SizedBox(width: 12),

              // Item Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + Status Chip
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
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
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Category
                    Row(
                      children: [
                        Icon(
                          _getCategoryIcon(item.category),
                          size: 14,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.category,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Location
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
                            item.location,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Date
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(item.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color:
                              colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryAvatar(ColorScheme colorScheme) {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          _getCategoryIcon(item.category),
          size: 32,
          color: colorScheme.primary,
        ),
      ),
    );
  }
}
