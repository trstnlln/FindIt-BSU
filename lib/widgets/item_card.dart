import 'package:flutter/material.dart';

import '../models/item_model.dart';
import '../screens/details/item_details_screen.dart';
import '../theme/app_theme.dart';
import '../utils/helpers.dart';
import 'cached_image.dart';
import 'status_chip.dart';

class ItemCard extends StatelessWidget {
  final ItemModel item;
  const ItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lost = item.type == 'lost';
    final accent = lost ? AppTheme.burgundy : AppTheme.teal;
    final location = [
      item.location,
      if (item.specificLocation?.trim().isNotEmpty == true)
        item.specificLocation!,
    ].join(' · ');
    final custody = item.custodyLocation;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ItemDetailsScreen(item: item),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      lost ? 'LOST' : 'FOUND',
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      formatTimeAgo(item.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  StatusChip(status: item.status),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CachedImage(
                    imageUrl: item.photoUrl,
                    width: 84,
                    height: 92,
                    borderRadius: 14,
                    fallbackWidget: Container(
                      width: 84,
                      height: 92,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        getCategoryIcon(item.category),
                        size: 34,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      formatDate(item.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    'View details',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                ],
              ),
              if (!lost &&
                  custody != null &&
                  custody.trim().isNotEmpty &&
                  custody != 'With Finder (Not Surrendered)') ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 14,
                      color: AppTheme.teal,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Safe at $custody',
                        style: const TextStyle(
                          color: AppTheme.teal,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
