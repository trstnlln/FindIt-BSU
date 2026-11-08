import 'package:flutter/material.dart';
import '../models/item_model.dart';
import '../services/matching_service.dart';
import '../screens/details/item_details_screen.dart';
import '../utils/helpers.dart';
import 'cached_image.dart';

/// Shows potential opposite-type matches for an item (e.g. found items matching a lost report).
/// Renders an interactive banner with horizontally scrollable item cards.
class MatchSuggestionsCard extends StatelessWidget {
  final ItemModel item;

  const MatchSuggestionsCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLost = item.type.toLowerCase() == 'lost';

    return FutureBuilder<List<ItemModel>>(
      future: MatchingService().findMatches(item),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final matches = snapshot.data ?? [];
        if (matches.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isLost ? Colors.teal.shade50 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLost ? Colors.teal.shade200 : Colors.blue.shade200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: isLost ? Colors.teal.shade800 : Colors.blue.shade800,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isLost
                          ? 'Possible Found Matches (${matches.length})'
                          : 'Possible Lost Matches (${matches.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isLost ? Colors.teal.shade900 : Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isLost
                    ? 'These found items closely match your report by category, date, or campus location.'
                    : 'These lost reports closely match what you found.',
                style: TextStyle(
                  fontSize: 12,
                  color: isLost ? Colors.teal.shade800 : Colors.blue.shade800,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: matches.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final match = matches[index];
                    return _MatchThumbnailCard(match: match);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MatchThumbnailCard extends StatelessWidget {
  final ItemModel match;

  const _MatchThumbnailCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ItemDetailsScreen(item: match),
          ),
        );
      },
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            CachedImage(
              imageUrl: match.photoUrl,
              width: 44,
              height: 44,
              borderRadius: 8,
              fallbackWidget: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  getCategoryIcon(match.category),
                  size: 22,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    match.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    match.location,
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatDate(match.date),
                    style: TextStyle(
                      fontSize: 9,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
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
}

