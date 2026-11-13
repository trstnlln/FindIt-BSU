import 'package:flutter/material.dart';

import '../models/item_model.dart';
import 'empty_state_view.dart';
import 'item_card.dart';

/// Builds the real-time list of items for a specific [type] ('lost' or 'found')
/// with keyword search and category/location/status/date filters applied.
class CampusReportFeed extends StatelessWidget {
  final Stream<List<ItemModel>> itemsStream;
  final String type;
  final String searchQuery;
  final String? selectedCategory;
  final String? selectedLocation;
  final String? selectedStatus;
  final DateTime? selectedDate;
  final VoidCallback onResetFilters;
  final VoidCallback onRetry;

  const CampusReportFeed({
    super.key,
    required this.itemsStream,
    required this.type,
    required this.searchQuery,
    required this.selectedCategory,
    required this.selectedLocation,
    required this.selectedStatus,
    required this.selectedDate,
    required this.onResetFilters,
    required this.onRetry,
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

        if (snapshot.hasError) {
          return EmptyStateView(
            bottomInset: 88,
            icon: Icons.cloud_off_outlined,
            title: 'Couldn’t load campus reports',
            subtitle: 'Check your connection and try again. You may need to verify your university email and sign in again.',
            actionButton: OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          );
        }

        final allItems = (snapshot.data ?? [])
            .where((item) => !item.archived)
            .toList();

        // Base empty state (no items reported at all in this tab)
        if (allItems.isEmpty) {
          return EmptyStateView(
            bottomInset: 88,
            icon: isLost
                ? Icons.search_off_rounded
                : Icons.check_circle_outline_rounded,
            title: isLost
                ? 'Nothing lost here yet'
                : 'Ready for a happy reunion',
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
            bottomInset: 88,
            icon: Icons.filter_alt_off_rounded,
            title: 'No matches just yet',
            subtitle: 'Try adjusting your search query, category, location, status, or date filter.',
            actionButton: OutlinedButton.icon(
              onPressed: onResetFilters,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('Reset Search & Filters'),
            ),
          );
        }

        // Populated List using extracted modular ItemCard
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _isFiltering
                        ? '${filteredItems.length} of ${allItems.length} reports'
                        : '${filteredItems.length} ${isLost ? 'lost' : 'found'} ${filteredItems.length == 1 ? 'report' : 'reports'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                key: PageStorageKey('feed-$type'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 104),
                itemCount: filteredItems.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return ItemCard(item: item);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
