import 'package:flutter_test/flutter_test.dart';
import 'package:sajda_dataplus/services/local_prayer_times_service.dart';
import 'package:sajda_dataplus/services/timezone_lookup.dart';

/// Regression suite for the 19 Oct 2026 "Isha 3:59 PM / Fajr 2:03 AM on the
/// Rahim Yar Khan phone" report.
///
/// Root cause: the coordinate → timezone lookup passed (lat, lng) to
/// `timezone_finder` 0.2.0 which expects (longitude, latitude). Rahim Yar
/// Khan's mirrored point fell in northern Norway, so the location timezone
/// was stored as Europe/Oslo (UTC+2 on the report date) instead of
/// Asia/Karachi (UTC+5) and every wall-clock time was 3 hours early.
///
/// Expected values below are the on-device results for 2026-10-19 with the
/// verified coordinates; the Karachi-method column matches public references
/// for that date (Fajr ~05:03, Isha ~19:04).
void main() {
  final date = DateTime(2026, 10, 19);

  Map<String, String> times({
    required double lat,
    required double lng,
    required String timezone,
    required int method,
  }) {
    final result = LocalPrayerTimesService.calculate(
      lat: lat,
      lng: lng,
      timezone: timezone,
      date: date,
      method: method,
      school: 1,
    );
    expect(result, isNotNull, reason: 'calculation must succeed');
    return {for (final p in result!.prayers) p.name: p.time};
  }

  group('Rahim Yar Khan (28.3902, 70.3216)', () {
    test('Karachi method matches the trusted online reference', () {
      final t = times(
        lat: 28.3902,
        lng: 70.3216,
        timezone: ianaTimezoneForCoordinates(28.3902, 70.3216)!,
        method: 1,
      );
      expect(t['Fajr'], '05:03');
      expect(t['Sunrise'], '06:22');
      expect(t['Dhuhr'], '12:05');
      expect(t['Asr'], '16:07');
      expect(t['Maghrib'], '17:45');
      expect(t['Isha'], '19:04');
    });

    test('MWL method differs only in the Isha angle (18:59 vs 19:04)', () {
      final t = times(
        lat: 28.3902,
        lng: 70.3216,
        timezone: 'Asia/Karachi',
        method: 3,
      );
      expect(t['Fajr'], '05:03');
      expect(t['Isha'], '18:59');
    });

    test('the bug scenario (Europe/Oslo) reproduces the screenshot values', () {
      final bug = times(
        lat: 28.3902,
        lng: 70.3216,
        timezone: 'Europe/Oslo',
        method: 3,
      );
      expect(bug['Fajr'], '02:03', reason: '2:03 AM on the phone screenshot');
      expect(bug['Isha'], '15:59', reason: '3:59 PM on the phone screenshot');

      final fixed = times(
        lat: 28.3902,
        lng: 70.3216,
        timezone: 'Asia/Karachi',
        method: 3,
      );
      int toMin(String t) =>
          int.parse(t.split(':')[0]) * 60 + int.parse(t.split(':')[1]);
      expect(toMin(fixed['Fajr']!) - toMin(bug['Fajr']!), 3 * 60);
      expect(toMin(fixed['Isha']!) - toMin(bug['Isha']!), 3 * 60);
    });

    test('resolved timezone can never be the bug zone', () {
      expect(ianaTimezoneForCoordinates(28.3902, 70.3216), 'Asia/Karachi');
    });
  });

  group('Raiwind / Lahore (31.5497, 74.3436)', () {
    test('resolves to Asia/Karachi and matches the working phone', () {
      expect(ianaTimezoneForCoordinates(31.5497, 74.3436), 'Asia/Karachi');

      final karachiMethod = times(
        lat: 31.5497,
        lng: 74.3436,
        timezone: 'Asia/Karachi',
        method: 1,
      );
      expect(karachiMethod['Fajr'], '04:47'); // reference 04:48
      expect(karachiMethod['Isha'], '18:48'); // reference ~18:50

      final mwl = times(
        lat: 31.5497,
        lng: 74.3436,
        timezone: 'Asia/Karachi',
        method: 3,
      );
      expect(mwl['Fajr'], '04:47');
      expect(mwl['Isha'], '18:43'); // 6:43 PM on the working phone
    });
  });

  group('date and ordering invariants', () {
    test('calculates the requested civil day, not the device day', () {
      final result = LocalPrayerTimesService.calculate(
        lat: 28.3902,
        lng: 70.3216,
        timezone: 'Asia/Karachi',
        date: DateTime(2026, 10, 20),
        method: 1,
        school: 1,
      )!;
      expect(result.date, '2026-10-20');
      expect(result.prayers, hasLength(6));
    });

    test('prayers are strictly ordered within the day', () {
      final t = times(
        lat: 28.3902,
        lng: 70.3216,
        timezone: 'Asia/Karachi',
        method: 1,
      );
      int toMin(String v) =>
          int.parse(v.split(':')[0]) * 60 + int.parse(v.split(':')[1]);
      final order = [
        t['Fajr']!,
        t['Sunrise']!,
        t['Dhuhr']!,
        t['Asr']!,
        t['Maghrib']!,
        t['Isha']!,
      ].map(toMin).toList();
      for (var i = 1; i < order.length; i++) {
        expect(order[i], greaterThan(order[i - 1]));
      }
    });
  });
}
