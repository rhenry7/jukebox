
String formatDateTimeDifference(String isoDateTime) {
  DateTime dateTime = DateTime.parse(isoDateTime);
  Duration difference = DateTime.now().difference(dateTime);

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
  if (dateTime == null) return '';
  
  final now = DateTime.now();
  final difference = now.difference(dateTime);
  
  if (difference.inDays >= 365) {
    final years = (difference.inDays / 365).floor();
    return years == 1 ? '1 year ago' : '$years years ago';
  } else if (difference.inDays >= 30) {
    final months = (difference.inDays / 30).floor();
    return months == 1 ? '1 month ago' : '$months months ago';
  } else if (difference.inDays >= 1) {
    final days = difference.inDays;
    return days == 1 ? '1 day ago' : '$days days ago';
  } else if (difference.inHours >= 1) {
    final hours = difference.inHours;
    return hours == 1 ? '1 hour ago' : '$hours hours ago';
  } else if (difference.inMinutes >= 1) {
    final minutes = difference.inMinutes;
    return minutes == 1 ? '1 minute ago' : '$minutes minutes ago';
  } else {
    return 'just now';
  }
}

String getCurrentDate() {
  final date = DateTime.now().toString();
  final dateParse = DateTime.parse(date);
  return "${dateParse.day}-${dateParse.month}-${dateParse.year}";
}
