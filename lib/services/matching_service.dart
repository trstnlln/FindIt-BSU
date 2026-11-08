import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item_model.dart';

/// Intelligent recommendation service that correlates "Lost" reports with "Found" reports.
///
/// Uses weighted scoring across Category, Campus Location, Date proximity,
/// and Keyword token overlap between titles and descriptions.
class MatchingService {
  final CollectionReference _itemsRef = FirebaseFirestore.instance.collection(
    'items',
  );

  /// Finds opposite-type candidate items that potentially match [item].
  ///
  /// For a 'lost' item, searches 'found' items (and vice versa).
  /// Returns items ranked by similarity score.
  Future<List<ItemModel>> findMatches(ItemModel item, {int limit = 5}) async {
    if (item.status != 'open') return [];
    final oppositeType = item.type.toLowerCase() == 'lost' ? 'found' : 'lost';

    try {
      // Query open reports from other students.
      final snapshot = await _itemsRef
          .where('type', isEqualTo: oppositeType)
          .get();

      final candidates = snapshot.docs
          .map(
            (doc) =>
                ItemModel.fromMap(doc.data()! as Map<String, dynamic>, doc.id),
          )
          .where(
            (c) =>
                c.id != item.id &&
                c.status == 'open' &&
                c.ownerId != item.ownerId,
          )
          .toList();

      final scoredItems = <_ScoredItem>[];

      for (final candidate in candidates) {
        final score = calculateMatchScore(item, candidate);
        if (score > 15) {
          // Minimum threshold for a meaningful match
          scoredItems.add(_ScoredItem(candidate, score));
        }
      }

      scoredItems.sort((a, b) => b.score.compareTo(a.score));

      return scoredItems.take(limit).map((scored) => scored.item).toList();
    } catch (_) {
      return [];
    }
  }

  /// Calculates a numerical similarity score (0 to 100) between two items.
  static int calculateMatchScore(ItemModel a, ItemModel b) {
    int score = 0;

    // 1. Category Match (40 pts)
    if (a.category.isNotEmpty &&
        a.category.toLowerCase() == b.category.toLowerCase()) {
      score += 40;
    }

    // 2. Location Match (25 pts)
    if (a.location.isNotEmpty &&
        a.location.toLowerCase() == b.location.toLowerCase()) {
      score += 25;
    }

    // 3. Date Proximity (up to 20 pts)
    final diffDays = a.date.difference(b.date).inDays.abs();
    if (diffDays <= 2) {
      score += 20;
    } else if (diffDays <= 5) {
      score += 15;
    } else if (diffDays <= 10) {
      score += 10;
    }

    // 4. Keyword Overlap in Title & Description (up to 15 pts)
    final wordsA = _extractKeywords('${a.title} ${a.description}');
    final wordsB = _extractKeywords('${b.title} ${b.description}');

    int overlapCount = 0;
    for (final word in wordsA) {
      if (wordsB.contains(word)) {
        overlapCount++;
      }
    }
    score += (overlapCount * 5).clamp(0, 15);

    return score;
  }

  static Set<String> _extractKeywords(String text) {
    const stopWords = {
      'the',
      'and',
      'with',
      'for',
      'this',
      'that',
      'from',
      'have',
      'lost',
      'found',
      'item',
      'please',
      'help',
      'near',
      'inside',
      'outside',
      'around',
    };

    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 3 && !stopWords.contains(w))
        .toSet();
  }
}

class _ScoredItem {
  final ItemModel item;
  final int score;

  _ScoredItem(this.item, this.score);
}
