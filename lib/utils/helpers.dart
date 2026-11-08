import 'package:flutter/material.dart';

/// Shared utility helpers used throughout the FindIt BSU app.

// ─── Date Formatting ─────────────────────────────────────────────────────────

/// Formats a DateTime as 'Mon DD, YYYY' (e.g., 'Jan 5, 2026').
String formatDate(DateTime dt) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

/// Formats a DateTime as 'Month DD, YYYY' (e.g., 'January 5, 2026').
String formatDateFull(DateTime dt) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

/// Returns a human-readable relative time string (e.g., 'Just now', '5m ago').
String formatTimeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.month}/${dt.day}/${dt.year}';
}

// ─── Category Icons ──────────────────────────────────────────────────────────

/// Returns the Material icon associated with an item category.
IconData getCategoryIcon(String category) {
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

// ─── Status Colors ───────────────────────────────────────────────────────────

/// Returns the color associated with an item status ('open', 'claimed', 'returned').
Color getStatusColor(String status, ColorScheme colorScheme) {
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

// ─── Campus Data ─────────────────────────────────────────────────────────────

/// Standard item categories used across the app.
const List<String> itemCategories = [
  'Electronics',
  'Clothing',
  'ID / Cards',
  'Books / Notes',
  'Bags / Wallets',
  'Money',
  'Keys',
  'Accessories',
  'Documents',
  'Water Bottle / Tumbler',
  'Other',
];

/// Campus locations for the BSU Alangilan campus.
const List<String> campusLocations = [
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

/// Custody/surrender locations where found items can be turned in.
const List<String> custodyLocations = [
  'With Finder (Not Surrendered)',
  'Gate 1 Guard Post',
  'Gate 2 Guard Post',
  'SSC Office (Student Services)',
  'Dean\'s Office',
  'Library Front Desk',
  'Gymnasium Office',
  'Campus Security Office',
  'Other Office / Department',
];

/// Status filter options.
const List<Map<String, String>> itemStatuses = [
  {'value': 'open', 'label': 'Open Only'},
  {'value': 'claimed', 'label': 'Claimed'},
  {'value': 'returned', 'label': 'Returned'},
];
