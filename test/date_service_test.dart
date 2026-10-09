import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:sajda_dataplus/services/date_service.dart';
import 'package:sajda_dataplus/services/hijri_date_service.dart';

void main() {
  group('DateService — timezone-aware local date (streak agreement)', () {
    test('formats plain date', () {
      expect(
        dateService.formatDateAsYYYYMMDD(date: DateTime(2024, 1, 15)),
        '2024-01-15',
      );
    });

    test('converts an instant into the location timezone (Tokyo +9)', () {
      // 2024-01-15 20:00 UTC == 2024-01-16 05:00 in Tokyo.
      expect(
        dateService.formatDateAsYYYYMMDD(
          date: DateTime.utc(2024, 1, 15, 20, 0),
          timezone: 'Asia/Tokyo',
        ),
        '2024-01-16',
      );
    });

    test('converts an instant into the location timezone (New York -5)', () {
      // 2024-01-15 20:00 UTC == 2024-01-15 15:00 in New York.
      expect(
        dateService.formatDateAsYYYYMMDD(
          date: DateTime.utc(2024, 1, 15, 20, 0),
          timezone: 'America/New_York',
        ),
        '2024-01-15',
      );
    });

    test('matches backend rule: 19:00 UTC == next day in Karachi (+5)', () {
      // Backend getTodayDateString('Asia/Karachi') at 19:00 UTC must agree.
      expect(
        dateService.formatDateAsYYYYMMDD(
          date: DateTime.utc(2024, 1, 15, 19, 0),
          timezone: 'Asia/Karachi',
        ),
        '2024-01-16',
      );
    });

    test('falls back to device-local formatting for unknown timezone', () {
      final d = DateTime(2024, 3, 9);
      expect(
        dateService.formatDateAsYYYYMMDD(date: d, timezone: 'Not/AZone'),
        '2024-03-09',
      );
    });

    test('pads month and day', () {
      expect(
        dateService.formatDateAsYYYYMMDD(date: DateTime(2024, 3, 5)),
        '2024-03-05',
      );
    });

    test('parses YYYY-MM-DD', () {
      final d = dateService.parseDate('2024-01-15');
      expect(d.year, 2024);
      expect(d.month, 1);
      expect(d.day, 15);
    });

    test('isToday / isYesterday (device-local)', () {
      final now = DateTime.now();
      expect(dateService.isToday(now), isTrue);
      expect(
        dateService.isYesterday(now.subtract(const Duration(days: 1))),
        isTrue,
      );
      expect(dateService.isToday(now.subtract(const Duration(days: 2))), isFalse);
    });
  });

  group('HijriDateService — user adjustment, printed-calendar convention', () {
    final date = DateTime(2024, 1, 15);

    test('no Maghrib shift: any date converts plainly', () {
      // One Hijri date per Gregorian day; no evening advance.
      expect(HijriDateService.getHijriDate(date).day,
          HijriDateService.convertPlain(date).day);
      expect(HijriDateService.getTodayHijri().day,
          HijriDateService.convertPlain(DateTime.now()).day);
    });

    test('adjustDays +2 shifts the displayed date two days ahead', () {
      final base = HijriDateService.convertPlain(date);
      HijriDateService.adjustDays = 2;
      addTearDown(() => HijriDateService.adjustDays = 0);
      final shifted = HijriDateService.convertPlain(date);
      // Ground truth: raw Umm al-Qura of (date + 2 days).
      final raw = HijriCalendar.fromDate(DateTime(2024, 1, 17));
      expect(shifted.day, raw.hDay);
      expect(shifted.day, base.day + 2);
      expect(shifted.month, base.month);
    });

    test('adjustDays -1 shifts the displayed date one day back', () {
      HijriDateService.adjustDays = -1;
      addTearDown(() => HijriDateService.adjustDays = 0);
      final raw = HijriCalendar.fromDate(DateTime(2024, 1, 14));
      final shifted = HijriDateService.convertPlain(date);
      expect(shifted.day, raw.hDay);
    });

    test('adjustDays reset restores the plain conversion', () {
      HijriDateService.adjustDays = 2;
      addTearDown(() => HijriDateService.adjustDays = 0);
      HijriDateService.adjustDays = 0;
      final raw = HijriCalendar.fromDate(date);
      expect(HijriDateService.convertPlain(date).day, raw.hDay);
    });

    test('HijriDateInfo formatting', () {
      final info = HijriDateService.convertPlain(DateTime(2024, 1, 15));
      expect(info.full, contains('AH'));
      expect(info.fullAr, contains('هـ'));
      expect(info.monthEn, isNotEmpty);
      expect(info.monthAr, isNotEmpty);
    });
  });
}
