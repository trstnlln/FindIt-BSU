import 'package:flutter/material.dart';

import '../../services/community_service.dart';
import '../../widgets/empty_state_view.dart';
import 'saved_search_results_screen.dart';

class SavedSearchesScreen extends StatefulWidget {
  const SavedSearchesScreen({super.key});
  @override
  State<SavedSearchesScreen> createState() => _SavedSearchesScreenState();
}

class _SavedSearchesScreenState extends State<SavedSearchesScreen> {
  late final _searches = CommunityService().savedSearches();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Saved searches')),
    body: StreamBuilder(
      stream: _searches,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Could not load saved searches. Please try again.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const EmptyStateView(
            icon: Icons.bookmark_border,
            title: 'Keep an eye out',
            subtitle: 'Search in Explore, choose a category or location, then tap Save search to receive alerts for new matching reports.',
          );
        }
        return ListView(
          children: docs.map((doc) {
            final data = doc.data();
            return ListTile(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SavedSearchResultsScreen(search: data),
                ),
              ),
              leading: const Icon(Icons.saved_search),
              title: Text(
                (data['query'] as String? ?? '').isEmpty
                    ? 'Filtered search'
                    : data['query'] as String,
              ),
              subtitle: Text(
                [
                  data['category'],
                  data['location'],
                ].whereType<String>().join(' · '),
              ),
              trailing: IconButton(
                tooltip: 'Remove saved search',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  try {
                    await doc.reference.delete();
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Could not remove this search.'),
                        ),
                      );
                    }
                  }
                },
              ),
            );
          }).toList(),
        );
      },
    ),
  );
}
