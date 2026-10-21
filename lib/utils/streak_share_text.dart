/// Shareable streak card helpers (feature F1).
///
/// Pure + dependency-free so both the caption and the month label are
/// trivially unit-testable. The caption NEVER asks for a rating or review —
/// incentivised reviews are banned by Google Play policy (see research.md
/// §6); the only reward for sharing is the in-app benefit itself.
library;

const String kDefaultAppUrl =
    'https://play.google.com/store/apps/details?id=com.sajda.dataplus';

const List<String> _kMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "October 2026" — English month stamp printed on the card itself
/// (share cards go out as images, so a stable Latin month name is fine).
String shareCardMonthLabel([DateTime? now]) {
  final d = now ?? DateTime.now();
  return '${_kMonths[d.month - 1]} ${d.year}';
}

/// Text caption attached to the shared PNG.
/// Includes the store link so recipients can install the app.
String buildStreakShareCaption({
  required int currentStreak,
  int bestStreak = 0,
  String appUrl = kDefaultAppUrl,
}) {
  final unit = currentStreak == 1 ? 'day' : 'days';
  final headline = currentStreak > 0
      ? '🔥 My salah streak: $currentStreak $unit and counting'
      : '🤲 Tracking my daily prayers with Sajda';
  final best = bestStreak > 0 ? '\nPersonal best: $bestStreak days' : '';
  final url = appUrl.trim().isEmpty ? kDefaultAppUrl : appUrl.trim();
  return '$headline$best\n\n'
      'Track yours on Sajda — Daily Athan & Qibla\n'
      '$url';
}
