import 'package:flutter/material.dart';
import '../models/item_model.dart';
import '../screens/details/item_details_screen.dart';
import '../utils/helpers.dart';
import 'cached_image.dart';
import 'status_chip.dart';

/// Card widget presenting a lost or found item in feed lists.
/// Includes thumbnail, status badge, category icon, location details,
/// and campus custody/surrender badges.
class ItemCard extends StatelessWidget {
  final ItemModel item;

  const ItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLost = item.type.toLowerCase() == 'lost';

    // Build compound location text (landmark + optional room/floor)
    final locationText = item.specificLocation != null &&
            item.specificLocation!.trim().isNotEmpty
        ? '${item.location} • ${item.specificLocation!.trim()}'
        : item.location;

    final hasCustody = item.custodyLocation != null &&
        item.custodyLocation!.trim().isNotEmpty &&
        item.custodyLocation != 'With Finder (Not Surrendered)';

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
              // Photo Thumbnail or Category Icon Placeholder (Cached)
              CachedImage(
                imageUrl: item.photoUrl,
                width: 78,
                height: 78,
                borderRadius: 12,
                fallbackWidget: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      getCategoryIcon(item.category),
                      size: 32,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Item Details Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + Type badge + Status Chip
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Lost / Found mini pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          margin: const EdgeInsets.only(right: 6, top: 1),
                          decoration: BoxDecoration(
                            color: isLost
                                ? Colors.red.shade50
                                : Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isLost
                                  ? Colors.red.shade300
                                  : Colors.teal.shade300,
                            ),
                          ),
                          child: Text(
                            item.type.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: isLost
                                  ? Colors.red.shade800
                                  : Colors.teal.shade800,
                            ),
                          ),
                        ),
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
                        StatusChip(status: item.status),
                      ],
                    ),

                    const SizedBox(height: 5),

                    // Category
                    Row(
                      children: [
                        Icon(
                          getCategoryIcon(item.category),
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

                    const SizedBox(height: 3),

                    // Location (Landmark + Specific Room)
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
                            locationText,
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

                    // Campus Custody / Surrendered Badge
                    if (hasCustody) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 13,
                            color: Colors.teal.shade800,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'At: ${item.custodyLocation}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 4),

                    // Date & Relative Time Ago
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${formatDate(item.date)} • ${formatTimeAgo(item.createdAt)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
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
}

