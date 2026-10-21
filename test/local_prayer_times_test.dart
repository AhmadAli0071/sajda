import 'package:flutter_test/flutter_test.dart';
import 'package:sajda_dataplus/services/local_prayer_times_service.dart';

/// F3: on-device prayer time calculation must produce sane, timezone-correct
/// wall-clock strings without touching the network.
void main() {
  // Karachi, Pakistan — University of Islamic Sciences (method 1), Hanafi (school 1).
  const lat = 24.8607;
  const lng = 67.0011;
  final date = DateTime(2026, 10, 19);

  (int, int) hm(String time) {
    final parts = time.split(':');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }

  group('LocalPrayerTimesService.calculate', () {
    test('returns all six prayers with clean HH:mm for Asia/Karachi', () {
      final result = LocalPrayerTimesService.calculate(
        lat: lat,
        lng: lng,
        timezone: 'Asia/Karachi',
        date: date,
        method: 1,
        school: 1,
      );

      expect(result, isNotNull);
      expect(result!.prayers.map((p) => p.name).toList(),
          ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']);
      for (final p in result.prayers) {
        expect(p.time, matches(RegExp(r'^([01]\d|2[0-3]):[0-5]\d$')),
            reason: '${p.name} time must be clean HH:mm, got ${p.time}');
      }
      expect(result.date, '2026-10-19');
      expect(result.hijri.full, isNotEmpty);
    });

    test('Karachi times are in plausible ranges and ordered', () {
      final result = LocalPrayerTimesService.calculate(
        lat: lat,
        lng: lng,
        timezone: 'Asia/Karachi',
        date: date,
        method: 1,
        school: 1,
      )!;

      final fajr = hm(result.prayers[0].time);
      final sunrise = hm(result.prayers[1].time);
      final dhuhr = hm(result.prayers[2].time);
      final asr = hm(result.prayers[3].time);
      final maghrib = hm(result.prayers[4].time);
      final isha = hm(result.prayers[5].time);

      int toMin((int, int) t) => t.$1 * 60 + t.$2;
      // Mid-October in Karachi: Fajr before dawn, Dhuhr ~12:20-12:40,
      // Isha roughly 19:30-20:00 — generous windows around those anchors.
      expect(toMin(fajr), inInclusiveRange(4 * 60, 6 * 60));
      expect(toMin(sunrise), inInclusiveRange(5 * 60 + 30, 7 * 60));
      expect(toMin(dhuhr), inInclusiveRange(12 * 60, 13 * 60));
      expect(toMin(asr), inInclusiveRange(15 * 60, 16 * 60 + 30));
      expect(toMin(maghrib), inInclusiveRange(17 * 60 + 30, 18 * 60 + 30));
      expect(toMin(isha), inInclusiveRange(19 * 60, 20 * 60 + 30));

      // Strict ordering through the day.
      expect(toMin(fajr), lessThan(toMin(sunrise)));
      expect(toMin(sunrise), lessThan(toMin(dhuhr)));
      expect(toMin(dhuhr), lessThan(toMin(asr)));
      expect(toMin(asr), lessThan(toMin(maghrib)));
      expect(toMin(maghrib), lessThan(toMin(isha)));
    });

    test('Hanafi Asr is later than Shafi Asr (school 1 vs 0)', () {
      final hanafi = LocalPrayerTimesService.calculate(
        lat: lat, lng: lng, timezone: 'Asia/Karachi',
        date: date, method: 1, school: 1,
      )!.prayers[3].time;
      final shafi = LocalPrayerTimesService.calculate(
        lat: lat, lng: lng, timezone: 'Asia/Karachi',
        date: date, method: 1, school: 0,
      )!.prayers[3].time;
      expect(hanafi.compareTo(shafi), greaterThan(0));
    });

    test('same coordinates expressed in Tokyo shift by exactly +4h', () {
      // Karachi is UTC+5, Tokyo UTC+9 → identical absolute events render
      // 4 hours later on Tokyo's wall clock (offset plumbing works).
      final karachi = LocalPrayerTimesService.calculate(
        lat: lat, lng: lng, timezone: 'Asia/Karachi',
        date: date, method: 1, school: 1,
      )!;
      final tokyo = LocalPrayerTimesService.calculate(
        lat: lat, lng: lng, timezone: 'Asia/Tokyo',
        date: date, method: 1, school: 1,
      )!;

      for (var i = 0; i < karachi.prayers.length; i++) {
        final k = hm(karachi.prayers[i].time);
        final t = hm(tokyo.prayers[i].time);
        final kMin = k.$1 * 60 + k.$2;
        var tMin = t.$1 * 60 + t.$2;
        // Normalize the next-day wrap (e.g. Isha 19:45 -> 23:45 is same day;
        // a time past midnight rolls into the next day = +24h before shift).
        if (tMin < kMin) tMin += 24 * 60;
        expect(tMin - kMin, 4 * 60,
            reason: '${karachi.prayers[i].name} must shift +4h in Tokyo');
      }
    });

    test('zero coordinates return null (caller falls back to API)', () {
      expect(
        LocalPrayerTimesService.calculate(
          lat: 0, lng: 0, timezone: 'Asia/Karachi',
          date: date, method: 1, school: 1,
        ),
        isNull,
      );
    });

    test('unknown timezone falls back to device offset without throwing', () {
      final result = LocalPrayerTimesService.calculate(
        lat: lat, lng: lng, timezone: 'Not/A_Zone',
        date: date, method: 1, school: 1,
      );
      expect(result, isNotNull);
      expect(result!.prayers, hasLength(6));
    });

    test('every Settings method id maps to a valid calculation', () {
      for (final method in [1, 2, 3, 4, 5, 8, 13, 15]) {
        final result = LocalPrayerTimesService.calculate(
          lat: lat, lng: lng, timezone: 'Asia/Karachi',
          date: date, method: method, school: 1,
        );
        expect(result, isNotNull, reason: 'method $method must calculate');
        expect(result!.prayers, hasLength(6));
      }
    });

    test('unsupported method id returns null instead of silently using MWL',
        () {
      expect(
        LocalPrayerTimesService.calculate(
          lat: lat, lng: lng, timezone: 'Asia/Karachi',
          date: date, method: 99, school: 1,
        ),
        isNull,
        reason: 'callers must fall back to the network for unmapped ids',
      );
    });
  });
}
