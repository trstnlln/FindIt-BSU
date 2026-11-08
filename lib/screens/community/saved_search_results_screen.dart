import 'package:flutter/material.dart';

import '../../models/item_model.dart';
import '../../services/item_service.dart';
import '../../widgets/item_card.dart';
import '../../widgets/empty_state_view.dart';

bool savedSearchMatches(Map<String, dynamic> search, ItemModel item) {
  if (item.status != 'open') return false;
  if (search['category'] != null && search['category'] != item.category) {
    return false;
  }
  if (search['location'] != null && search['location'] != item.location) {
    return false;
  }
  final text =
      '${item.title} ${item.description} ${item.category} ${item.location} ${item.specificLocation ?? ''}'
          .toLowerCase();
  final query = (search['query'] as String? ?? '').trim().toLowerCase();
  if (query.isEmpty) {
    return search['category'] != null || search['location'] != null;
  }
  return query.split(RegExp(r'\s+')).every(text.contains);
}

class SavedSearchResultsScreen extends StatefulWidget {
  final Map<String, dynamic> search;
  const SavedSearchResultsScreen({super.key, required this.search});
  @override
  State<SavedSearchResultsScreen> createState() =>
      _SavedSearchResultsScreenState();
}

class _SavedSearchResultsScreenState extends State<SavedSearchResultsScreen> {
  late final _items = ItemService().getItemsStream();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Saved search results')),
    body: StreamBuilder(
      stream: _items,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Could not load results. Reopen this search to retry.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!
            .where((item) => savedSearchMatches(widget.search, item))
            .toList();
        if (items.isEmpty) {
          return const EmptyStateView(
            icon: Icons.search_off,
            title: 'No open matches yet',
            subtitle:
                'Your search is saved. New matches will appear in your alerts.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) => ItemCard(item: items[index]),
        );
      },
    ),
  );
}
