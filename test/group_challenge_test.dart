import 'package:flutter_test/flutter_test.dart';

import 'package:sajda_dataplus/models/streak_v2.dart';
import 'package:sajda_dataplus/utils/group_challenge.dart';

void main() {
  group('group weekly challenge', () {
    test('start of week is Monday at midnight', () {
      expect(
        startOfWeek(DateTime(2026, 10, 19, 23, 59)),
        DateTime(2026, 10, 19),
      );
      expect(
        startOfWeek(DateTime(2026, 10, 25, 12)),
        DateTime(2026, 10, 19),
      );
    });

    test('labels complete, today, future and missed days', () {
      final now = DateTime(2026, 10, 19, 12);
      final history = HistoryData(
        year: 2026,
        month: 10,
        calendar: const [
          MonthDay(
            dateKey: '2026-10-14',
            day: 14,
            state: 'none',
            completedCount: 0,
          ),
          MonthDay(
            dateKey: '2026-10-19',
            day: 19,
            state: 'today',
            completedCount: 2,
          ),
          MonthDay(
            dateKey: '2026-10-20',
            day: 20,
            state: 'future',
            completedCount: 0,
          ),
          MonthDay(
            dateKey: '2026-10-15',
            day: 15,
            state: 'complete',
            completedCount: 5,
          ),
        ],
      );

      final week = buildWeekChallenge(history, now);
      expect(week.days, hasLength(7));
      expect(week.start, DateTime(2026, 10, 19));
      expect(week.days[0].state, 'today');
      expect(week.days[0].completedCount, 2);
      expect(week.days[1].state, 'future');
      expect(week.days[6].state, 'future');

      final previousWeek = buildWeekChallenge(history, DateTime(2026, 10, 16));
      expect(previousWeek.days[0].state, 'missed');
      expect(previousWeek.days[2].state, 'missed');
      expect(previousWeek.days[3].state, 'complete');
      expect(previousWeek.days[4].state, 'today');
      expect(previousWeek.days[5].state, 'future');
      expect(previousWeek.completedDays, 1);
      expect(previousWeek.progress, closeTo(1 / 7, 0.0001));
      expect(previousWeek.perfect, isFalse);
    });

    test('a completed count of five is complete even without a state', () {
      final now = DateTime(2026, 10, 19);
      final week = buildWeekChallenge(
        HistoryData(
          year: 2026,
          month: 10,
          calendar: const [
            MonthDay(
              dateKey: '2026-10-19',
              day: 19,
              state: 'none',
              completedCount: 5,
            ),
          ],
        ),
        now,
      );
      expect(week.days.first.isComplete, isTrue);
      expect(week.perfect, isFalse);
    });

    test('past days with no history are missed, future days are future', () {
      final now = DateTime(2026, 10, 21, 9);
      final week = buildWeekChallenge(null, now);
      expect(week.days[0].state, 'missed');
      expect(week.days[1].state, 'missed');
      expect(week.days[2].state, 'today');
      expect(week.days[3].state, 'future');
    });

    test('ranks complete days first, then count, then name', () {
      final members = [
        const MemberProgress(userId: '1', displayName: 'Zed', completedCount: 1),
        const MemberProgress(
          userId: '2',
          displayName: 'amy',
          completedCount: 5,
        ),
        const MemberProgress(
          userId: '3',
          displayName: 'Bob',
          completedCount: 3,
          isDayComplete: true,
        ),
        const MemberProgress(
          userId: '4',
          displayName: 'Cody',
          completedCount: 5,
        ),
        const MemberProgress(
          userId: '5',
          displayName: 'Aya',
          completedCount: 1,
          isDayComplete: true,
        ),
      ];

      final ranked = rankMembers(members);
      expect(
        ranked.map((m) => m.displayName).toList(),
        ['Bob', 'Aya', 'amy', 'Cody', 'Zed'],
      );
      expect(members.first.displayName, 'Zed');
    });

    test('merges adjacent months with summary fields from the newest', () {
      final october = HistoryData(
        year: 2026,
        month: 10,
        currentStreak: 6,
        bestStreak: 11,
        calendar: const [
          MonthDay(
            dateKey: '2026-10-01',
            day: 1,
            state: 'complete',
            completedCount: 5,
          ),
          MonthDay(
            dateKey: '2026-10-02',
            day: 2,
            state: 'today',
            completedCount: 1,
          ),
        ],
      );
      final september = HistoryData(
        year: 2026,
        month: 9,
        calendar: const [
          MonthDay(
            dateKey: '2026-09-28',
            day: 28,
            state: 'complete',
            completedCount: 5,
          ),
          MonthDay(
            dateKey: '2026-09-29',
            day: 29,
            state: 'complete',
            completedCount: 5,
          ),
          MonthDay(
            dateKey: '2026-09-30',
            day: 30,
            state: 'complete',
            completedCount: 5,
          ),
        ],
      );

      final merged = mergeMonthHistories([october, september]);
      expect(merged.calendar, hasLength(5));
      expect(merged.year, 2026);
      expect(merged.month, 10);
      expect(merged.currentStreak, 6);
      expect(merged.bestStreak, 11);
    });

    test('a week spanning two months keeps the previous-month history', () {
      final october = HistoryData(
        year: 2026,
        month: 10,
        calendar: const [
          MonthDay(
            dateKey: '2026-10-01',
            day: 1,
            state: 'complete',
            completedCount: 5,
          ),
          MonthDay(
            dateKey: '2026-10-02',
            day: 2,
            state: 'today',
            completedCount: 1,
          ),
        ],
      );
      final september = HistoryData(
        year: 2026,
        month: 9,
        calendar: const [
          MonthDay(
            dateKey: '2026-09-27',
            day: 27,
            state: 'missed',
            completedCount: 0,
          ),
          MonthDay(
            dateKey: '2026-09-28',
            day: 28,
            state: 'complete',
            completedCount: 5,
          ),
          MonthDay(
            dateKey: '2026-09-29',
            day: 29,
            state: 'complete',
            completedCount: 5,
          ),
          MonthDay(
            dateKey: '2026-09-30',
            day: 30,
            state: 'complete',
            completedCount: 5,
          ),
        ],
      );

      final merged = mergeMonthHistories([october, september]);
      final week = buildWeekChallenge(merged, DateTime(2026, 10, 2, 12));

      expect(week.start, DateTime(2026, 9, 28));
      expect(week.days[0].state, 'complete');
      expect(week.days[1].state, 'complete');
      expect(week.days[2].state, 'complete');
      expect(week.days[3].state, 'complete');
      expect(week.days[4].state, 'today');
      expect(week.days[5].state, 'future');
      expect(week.days[6].state, 'future');
      expect(week.completedDays, 4,
          reason: 'Sep 28-30 used to be mislabelled missed without the merge');

      final withoutMerge = buildWeekChallenge(october, DateTime(2026, 10, 2, 12));
      expect(withoutMerge.completedDays, 1);
    });

    test('duplicate dateKeys keep the first (newest) occurrence', () {
      final october = HistoryData(
        year: 2026,
        month: 10,
        calendar: const [
          MonthDay(
            dateKey: '2026-10-05',
            day: 5,
            state: 'complete',
            completedCount: 5,
          ),
        ],
      );
      final overlap = HistoryData(
        year: 2026,
        month: 10,
        calendar: const [
          MonthDay(
            dateKey: '2026-10-05',
            day: 5,
            state: 'missed',
            completedCount: 0,
          ),
          MonthDay(
            dateKey: '2026-10-06',
            day: 6,
            state: 'none',
            completedCount: 0,
          ),
        ],
      );

      final merged = mergeMonthHistories([october, overlap]);
      expect(merged.calendar, hasLength(2));
      expect(merged.calendar.first.state, 'complete');
      expect(merged.calendar.last.dateKey, '2026-10-06');
    });
  });
}
