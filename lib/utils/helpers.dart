String formatDateTimeDifference(String isoDateTime) {
  final DateTime dateTime = DateTime.parse(isoDateTime);
  final Duration difference = DateTime.now().difference(dateTime);

  if (difference.inDays >= 1) {
    return '${difference.inDays}d';
  } else if (difference.inHours >= 1) {
    return '${difference.inHours}h';
  } else if (difference.inMinutes >= 1) {
    return '${difference.inMinutes}m';
  } else {
    return '${difference.inSeconds}s';
  }
}

/// Format relative time in a human-readable way (e.g., "8 minutes ago", "2 days ago")
String formatRelativeTime(DateTime? dateTime) {
  if (dateTime == null) return '—';

  final diff = DateTime.now().difference(dateTime);

  if (diff.inSeconds < 60) return '${diff.inSeconds}s';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo';
  return '${(diff.inDays / 365).floor()}y';
}

String getCurrentDate() {
  final date = DateTime.now().toString();
  final dateParse = DateTime.parse(date);
  return '${dateParse.day}-${dateParse.month}-${dateParse.year}';
}
