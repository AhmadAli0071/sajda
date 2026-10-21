import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/streak_v2.dart';

/// On-device engagement stats used by badges, the prayer heatmap, Sajda
/// Wrapped, the Prayer Garden, and share cards.
///
/// Everything lives in SharedPreferences — no new backend endpoints. When the
/// server's solo state is available it is the source of truth for today and
/// for month history; tasbeeh/quiz counters are local-only.
class SajdaStatsService extends ChangeNotifier {
  SajdaStatsService._();
  static final SajdaStatsService instance = SajdaStatsService._();

  static const _kStats = 'sajda_stats_v1';
  static const _prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

  final Map<String, _DayRecord> _days = {};
  final Map<String, int> _prayerCounts = {
    for (final p in _prayers) p: 0,
  };
  int _tasbeehSets = 0;
  int _quizCorrect = 0;
  int _quizDays = 0;
  String? _lastQuizDay;
  bool _loaded = false;

  bool get loaded => _loaded;
  int get tasbeehSets => _tasbeehSets;
  int get quizCorrect => _quizCorrect;
  int get quizDays => _quizDays;

  Map<String, int> get dayCounts => {
        for (final e in _days.entries)
          if (e.value.count > 0) e.key: e.value.count,
      };

  int get totalPrayers =>
      _days.values.fold(0, (sum, d) => sum + d.count);

  int get completeDays =>
      _days.values.where((d) => d.count >= 5).length;

  int get activeDays => _days.values.where((d) => d.count > 0).length;

  int get fajrCount => _prayerCounts['fajr'] ?? 0;

  Map<String, int> get prayerCounts => Map.unmodifiable(_prayerCounts);

  int countOn(DateTime day) => _days[dayKeyOf(day)]?.count ?? 0;

  SajdaStatsSnapshot snapshot({
    int currentStreak = 0,
    int bestStreak = 0,
  }) {
    final best = bestStreak > currentStreak ? bestStreak : currentStreak;
    return SajdaStatsSnapshot(
      currentStreak: currentStreak,
      bestStreak: best,
      totalPrayers: totalPrayers,
      completeDays: completeDays,
      activeDays: activeDays,
      tasbeehSets: _tasbeehSets,
      quizCorrect: _quizCorrect,
      quizDays: _quizDays,
      fajrCount: fajrCount,
      ishaCount: _prayerCounts['isha'] ?? 0,
    );
  }

  static String dayKeyOf(DateTime day) {
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '${day.year.toString().padLeft(4, '0')}-$m-$d';
  }

  Future<void> load() async {
    if (_loaded) return;
    await reload();
  }

  @visibleForTesting
  Future<void> reload() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStats);
    _days.clear();
    for (final p in _prayers) {
      _prayerCounts[p] = 0;
    }
    _tasbeehSets = 0;
    _quizCorrect = 0;
    _quizDays = 0;
    _lastQuizDay = null;

    if (raw != null && raw.isNotEmpty) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final days = data['days'] as Map<String, dynamic>? ?? {};
        for (final entry in days.entries) {
          final value = entry.value as Map<String, dynamic>? ?? {};
          final flags = (value['flags'] as List?)
              ?.map((e) => e == true)
              .toList(growable: false);
          _days[entry.key] = _DayRecord(
            count: (value['c'] as num?)?.toInt() ?? 0,
            flags: (flags != null && flags.length == 5) ? flags : null,
          );
        }
        _tasbeehSets = (data['tasbeeh'] as num?)?.toInt() ?? 0;
        _quizCorrect = (data['quizCorrect'] as num?)?.toInt() ?? 0;
        _quizDays = (data['quizDays'] as num?)?.toInt() ?? 0;
        _lastQuizDay = data['lastQuizDay']?.toString();
        final prayers = data['prayers'] as Map<String, dynamic>? ?? {};
        for (final p in _prayers) {
          _prayerCounts[p] = (prayers[p] as num?)?.toInt() ?? 0;
        }
      } catch (_) {
        // Corrupt cache — start clean rather than crash stats screens.
      }
    }
    _loaded = true;
    notifyListeners();
  }

  /// Mirrors the authoritative solo "today" into local stats.
  Future<void> syncToday(DayProgress today) async {
    await load();
    await _writeDay(
      dayKeyOf(DateTime.now()),
      count: today.completedCount,
      flags: [
        today.fajr,
        today.dhuhr,
        today.asr,
        today.maghrib,
        today.isha,
      ],
    );
  }

  /// Backfills local stats from a server month history response.
  ///
  /// History only exposes counts (not per-prayer flags), so per-prayer badges
  /// are driven by [syncToday] while streaks/heatmap use these counts.
  Future<void> mergeHistory(HistoryData history) async {
    await load();
    var changed = false;
    for (final d in history.calendar) {
      if (d.dateKey.isEmpty) continue;
      final count = d.state == 'complete'
          ? (d.completedCount >= 5 ? d.completedCount : 5)
          : d.completedCount;
      if (count <= 0) continue;
      final existing = _days[d.dateKey];
      if (existing == null || existing.count < count) {
        _days[d.dateKey] = _DayRecord(
          count: count,
          flags: existing?.flags,
        );
        changed = true;
      }
    }
    if (changed) await _persist();
  }

  Future<void> addTasbeehSet() async {
    await load();
    _tasbeehSets++;
    await _persist();
  }

  Future<void> addQuizResult(int correct) async {
    await load();
    _quizCorrect += correct.clamp(0, 100);
    final today = dayKeyOf(DateTime.now());
    if (_lastQuizDay != today) {
      _lastQuizDay = today;
      _quizDays++;
    }
    await _persist();
  }

  Future<void> _writeDay(
    String key, {
    required int count,
    required List<bool> flags,
  }) async {
    final previous = _days[key];
    final previousFlags = previous?.flags;
    if (previousFlags != null) {
      for (var i = 0; i < _prayers.length; i++) {
        if (flags[i] && !previousFlags[i]) {
          _prayerCounts[_prayers[i]] = (_prayerCounts[_prayers[i]] ?? 0) + 1;
        } else if (!flags[i] && previousFlags[i]) {
          _prayerCounts[_prayers[i]] =
              ((_prayerCounts[_prayers[i]] ?? 0) - 1).clamp(0, 1 << 30);
        }
      }
    } else {
      for (var i = 0; i < _prayers.length; i++) {
        if (flags[i]) {
          _prayerCounts[_prayers[i]] = (_prayerCounts[_prayers[i]] ?? 0) + 1;
        }
      }
    }
    _days[key] = _DayRecord(
      count: count < 0 ? 0 : count,
      flags: flags,
    );
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{
      'days': {
        for (final e in _days.entries)
          e.key: {
            'c': e.value.count,
            'flags': e.value.flags,
          },
      },
      'prayers': _prayerCounts,
      'tasbeeh': _tasbeehSets,
      'quizCorrect': _quizCorrect,
      'quizDays': _quizDays,
      'lastQuizDay': _lastQuizDay,
    };
    await prefs.setString(_kStats, jsonEncode(data));
    notifyListeners();
  }
}

class _DayRecord {
  final int count;
  final List<bool>? flags;

  const _DayRecord({required this.count, this.flags});
}

/// Immutable values badges are evaluated against.
class SajdaStatsSnapshot {
  final int currentStreak;
  final int bestStreak;
  final int totalPrayers;
  final int completeDays;
  final int activeDays;
  final int tasbeehSets;
  final int quizCorrect;
  final int quizDays;
  final int fajrCount;
  final int ishaCount;

  const SajdaStatsSnapshot({
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.totalPrayers = 0,
    this.completeDays = 0,
    this.activeDays = 0,
    this.tasbeehSets = 0,
    this.quizCorrect = 0,
    this.quizDays = 0,
    this.fajrCount = 0,
    this.ishaCount = 0,
  });
}
