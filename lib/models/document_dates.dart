/// Handles current millisecond values and legacy Firestore/ISO dates. Unknown
/// or malformed dates use an epoch sentinel, never today's date or an exception.
DateTime parseDocumentDate(dynamic value) {
  final unknown = DateTime.fromMillisecondsSinceEpoch(0);
  if (value is DateTime) return value;
  try {
    if (value is num && value.isFinite) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) return DateTime.tryParse(value) ?? unknown;
    final date = (value as dynamic)?.toDate();
    if (date is DateTime) return date;
  } catch (_) {
    /* Legacy or invalid data must not break the entire feed. */
  }
  return unknown;
}
