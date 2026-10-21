import '../models/streak_v2.dart';

/// Pure weekly-challenge calculations shared by the UI and unit tests.
class WeekDayResult {
  final DateTime date;
  final String state; // complete | today | missed | future | pending
  final int completedCount;

  const WeekDayResult({
    required this.date,
    required this.state,
    this.completedCount = 0,
  });

  bool get isComplete => state == 'complete';
  bool get isToday => state == 'today';
  bool get isMissed => state == 'missed';
  bool get isFuture => state == 'future';
}

class WeekChallenge {
  final DateTime start;
  final List<WeekDayResult> days;

  const WeekChallenge({required this.start, required this.days});

  int get completedDays => days.where((d) => d.isComplete).length;
  int get target => 7;
  double get progress => (completedDays / target).clamp(0.0, 1.0);
  bool get perfect => completedDays >= target;
}

DateTime startOfWeek(DateTime now) {
  final day = DateTime(now.year, now.month, now.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

String _key(DateTime day) {
  final m = day.month.toString().padLeft(2, '0');
  final d = day.day.toString().padLeft(2, '0');
  return '${day.year.toString().padLeft(4, '0')}-$m-$d';
}

/// Merges month histories (newest first) into one calendar. Duplicate
/// dateKeys keep the first occurrence; summary fields come from the first.
HistoryData mergeMonthHistories(List<HistoryData> months) {
  final first = months.first;
  final seen = <String>{};
  final calendar = <MonthDay>[];
  for (final month in months) {
    for (final day in month.calendar) {
      if (seen.add(day.dateKey)) calendar.add(day);
    }
  }
  return HistoryData(
    year: first.year,
    month: first.month,
    calendar: calendar,
    currentStreak: first.currentStreak,
    bestStreak: first.bestStreak,
  );
}

/// Builds Monday→Sunday status for the week containing [now] from the group
/// month history. Days already complete count regardless of the server's
/// `today` label.
WeekChallenge buildWeekChallenge(HistoryData? history, DateTime now) {
  final start = startOfWeek(now);
  final todayKey = _key(now);
  final byKey = <String, MonthDay>{
    for (final d in history?.calendar ?? const <MonthDay>[]) d.dateKey: d,
  };
  final days = <WeekDayResult>[];
  for (var i = 0; i < 7; i++) {
    final date = start.add(Duration(days: i));
    final key = _key(date);
    final day = byKey[key];
    final isToday = key == todayKey;
    var state = day?.state ?? '';
    final count = day?.completedCount ?? 0;
    if (state == 'complete' || count >= 5) {
      state = 'complete';
    } else if (isToday) {
      state = 'today';
    } else if (state.isEmpty || state == 'none') {
      state = date.isAfter(now) ? 'future' : 'missed';
    } else if (state == 'today' && !isToday) {
      state = 'missed';
    } else if (state == 'future' && !date.isAfter(now)) {
      state = 'pending';
    }
    days.add(WeekDayResult(date: date, state: state, completedCount: count));
  }
  return WeekChallenge(start: start, days: days);
}

/// Ranks members by today's completed prayers, then day completion, then name.
List<MemberProgress> rankMembers(List<MemberProgress> members) {
  final sorted = List<MemberProgress>.of(members)
    ..sort((a, b) {
      if (a.isDayComplete != b.isDayComplete) {
        return a.isDayComplete ? -1 : 1;
      }
      final byCount = b.completedCount.compareTo(a.completedCount);
      if (byCount != 0) return byCount;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
  return sorted;
}
