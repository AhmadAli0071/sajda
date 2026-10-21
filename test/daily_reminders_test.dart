import 'package:flutter_test/flutter_test.dart';

import 'package:sajda_dataplus/data/daily_reminders.dart';

void main() {
  group('daily zikr and du\'a rotation', () {
    test('rotation is stable for a given day', () {
      final day = DateTime(2026, 10, 19);
      expect(reminderForDay(day).id, reminderForDay(day).id);
      expect(reminderForDay(DateTime(2026, 1, 1)).id, 'subhanallah');
    });

    test('every entry has complete content', () {
      for (final r in dailyReminders) {
        expect(r.id, isNotEmpty);
        expect(r.arabic, isNotEmpty);
        expect(r.transliteration, isNotEmpty);
        expect(r.translationEn, isNotEmpty);
        expect(r.translationUr, isNotEmpty);
        expect(r.source, isNotEmpty);
        expect(r.titleEn, isNotEmpty);
        expect(r.titleUr, isNotEmpty);
      }
      expect(dailyReminders.map((r) => r.id).toSet(), hasLength(12));
    });

    test('category filters only return the requested kind', () {
      for (var i = 0; i < 40; i++) {
        final day = DateTime(2026, 1, 1).add(Duration(days: i));
        expect(reminderForDay(day, category: 'zikr').kind, ReminderKind.zikr);
        expect(reminderForDay(day, category: 'dua').kind, ReminderKind.dua);
      }
    });

    test('cycle covers both categories and wraps by day of year', () {
      final zikr = <String>{};
      final dua = <String>{};
      for (var i = 0; i < 12; i++) {
        final reminder = reminderForDay(DateTime(2026, 1, 1 + i));
        if (reminder.kind == ReminderKind.zikr) {
          zikr.add(reminder.id);
        } else {
          dua.add(reminder.id);
        }
      }
      expect(zikr, hasLength(7));
      expect(dua, hasLength(5));
      expect(
        reminderForDay(DateTime(2026, 1, 13)).id,
        reminderForDay(DateTime(2026, 1, 1)).id,
      );
    });
  });
}
