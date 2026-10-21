import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sajda_dataplus/models/streak_v2.dart';
import 'package:sajda_dataplus/services/sajda_stats_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final stats = SajdaStatsService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await stats.reload();
  });

  group('SajdaStatsService', () {
    test('day key is zero padded and locale independent', () {
      expect(SajdaStatsService.dayKeyOf(DateTime(2026, 1, 5)), '2026-01-05');
      expect(SajdaStatsService.dayKeyOf(DateTime(2026, 12, 31)), '2026-12-31');
    });

    test('syncToday tracks counts and only counts new prayers', () async {
      await stats.syncToday(
        const DayProgress(
          fajr: true,
          dhuhr: true,
          completedCount: 2,
        ),
      );
      expect(stats.totalPrayers, 2);
      expect(stats.fajrCount, 1);
      expect(stats.completeDays, 0);
      expect(stats.activeDays, 1);
      expect(stats.countOn(DateTime.now()), 2);

      await stats.syncToday(
        const DayProgress(
          fajr: true,
          dhuhr: true,
          asr: true,
          maghrib: true,
          isha: true,
          completedCount: 5,
          isDayComplete: true,
        ),
      );
      expect(stats.totalPrayers, 5);
      expect(stats.fajrCount, 1);
      expect(stats.completeDays, 1);
      expect(stats.countOn(DateTime.now()), 5);

      await stats.syncToday(
        const DayProgress(
          dhuhr: true,
          asr: true,
          maghrib: true,
          isha: true,
          completedCount: 4,
        ),
      );
      expect(stats.totalPrayers, 4);
      expect(stats.fajrCount, 0);
      expect(stats.completeDays, 0);
    });

    test('mergeHistory backfills counts and never downgrades a day', () async {
      await stats.mergeHistory(HistoryData(
        year: 2026,
        month: 10,
        calendar: const [
          MonthDay(
            dateKey: '2026-10-01',
            day: 1,
            state: 'complete',
            completedCount: 0,
          ),
          MonthDay(
            dateKey: '2026-10-02',
            day: 2,
            state: 'none',
            completedCount: 3,
          ),
          MonthDay(
            dateKey: '2026-10-03',
            day: 3,
            state: 'none',
            completedCount: 0,
          ),
        ],
      ));
      expect(stats.countOn(DateTime(2026, 10, 1)), 5);
      expect(stats.countOn(DateTime(2026, 10, 2)), 3);
      expect(stats.countOn(DateTime(2026, 10, 3)), 0);
      expect(stats.totalPrayers, 8);
      expect(stats.completeDays, 1);
      expect(stats.activeDays, 2);

      await stats.mergeHistory(HistoryData(
        year: 2026,
        month: 10,
        calendar: const [
          MonthDay(
            dateKey: '2026-10-01',
            day: 1,
            state: 'none',
            completedCount: 2,
          ),
          MonthDay(
            dateKey: '2026-10-02',
            day: 2,
            state: 'none',
            completedCount: 4,
          ),
        ],
      ));
      expect(stats.countOn(DateTime(2026, 10, 1)), 5);
      expect(stats.countOn(DateTime(2026, 10, 2)), 4);
      expect(stats.totalPrayers, 9);
    });

    test('tasbeeh and quiz counters accumulate and persist', () async {
      await stats.addTasbeehSet();
      await stats.addTasbeehSet();
      await stats.addQuizResult(7);
      await stats.addQuizResult(3);
      expect(stats.tasbeehSets, 2);
      expect(stats.quizCorrect, 10);
      expect(stats.quizDays, 1);

      await stats.reload();
      expect(stats.tasbeehSets, 2);
      expect(stats.quizCorrect, 10);
      expect(stats.quizDays, 1);
    });

    test('snapshot prefers the higher of current and best streak', () async {
      await stats.syncToday(
        const DayProgress(fajr: true, completedCount: 1),
      );
      final snap = stats.snapshot(currentStreak: 4, bestStreak: 9);
      expect(snap.currentStreak, 4);
      expect(snap.bestStreak, 9);
      expect(snap.totalPrayers, 1);
      expect(snap.fajrCount, 1);
      expect(snap.ishaCount, 0);

      final lower = stats.snapshot(currentStreak: 10, bestStreak: 2);
      expect(lower.bestStreak, 10);
    });

    test('corrupt persisted stats start clean instead of crashing', () async {
      SharedPreferences.setMockInitialValues({
        'sajda_stats_v1': '{not json',
      });
      await stats.reload();
      expect(stats.totalPrayers, 0);
      expect(stats.tasbeehSets, 0);
      expect(stats.quizCorrect, 0);
    });
  });
}
