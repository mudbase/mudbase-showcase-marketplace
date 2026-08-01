import 'package:intl/intl.dart';

/// Relative + absolute timestamp formatting, currency, initials, and the
/// `isObjectId` guard. Ported directly from the reference web app's
/// `src/lib/utils.ts` (same threshold values) so a listing/proposal/message
/// timestamp on the web app and on this app always renders identically.

/// Mirrors `formatRelativeTime` in `web/src/lib/utils.ts` exactly (`"just
/// now"` under 5s, then `"Ns"`/`"Nm"`/`"Nh"`/`"Nd"`, falling back to a plain
/// medium-style date past a week).
String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final diffSeconds = now.difference(dateTime).inSeconds;

  if (diffSeconds < 5) return 'just now';
  if (diffSeconds < 60) return '${diffSeconds}s';
  final diffMinutes = now.difference(dateTime).inMinutes;
  if (diffMinutes < 60) return '${diffMinutes}m';
  final diffHours = now.difference(dateTime).inHours;
  if (diffHours < 24) return '${diffHours}h';
  final diffDays = now.difference(dateTime).inDays;
  if (diffDays < 7) return '${diffDays}d';
  return DateFormat.yMMMd().format(dateTime);
}

/// Mirrors `formatDateTime` in `web/src/lib/utils.ts` (medium date + short
/// time) - used for message timestamps.
String formatDateTime(DateTime dateTime) {
  return '${DateFormat.yMMMd().format(dateTime)}, ${DateFormat.jm().format(dateTime)}';
}

/// Mirrors `formatCurrency` in `web/src/lib/utils.ts` - whole-dollar USD,
/// used for every listing budget / proposed rate.
String formatCurrency(num amount) {
  final formatter = NumberFormat.currency(
    locale: 'en_US',
    symbol: r'$',
    decimalDigits: 0,
  );
  return formatter.format(amount);
}

/// Mirrors `initials` in `web/src/lib/utils.ts` - used for message sender
/// avatar chips.
String initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first.isNotEmpty ? parts.first.substring(0, 1) : '';
  final last = parts.length > 1 && parts.last.isNotEmpty
      ? parts.last.substring(0, 1)
      : '';
  return (first + last).toUpperCase();
}

final RegExp _objectIdPattern = RegExp(r'^[a-f0-9]{24}$', caseSensitive: false);

/// Mirrors `isObjectId` in `web/src/lib/utils.ts` - Mudbase's query
/// sanitizer rejects (and security-alerts on) any top-level filter field
/// ending in "Id" that isn't a real 24-hex-char ObjectId. Every `...Id`
/// query built by this app's repositories is guarded with this check before
/// the query is ever sent.
bool isObjectId(String? value) {
  return value != null && _objectIdPattern.hasMatch(value);
}
