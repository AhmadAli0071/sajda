import 'package:flutter_test/flutter_test.dart';
import 'package:sajda_dataplus/models/models.dart';
import 'package:sajda_dataplus/models/streak_v2.dart';
import 'package:sajda_dataplus/services/widget_service.dart';

/// F2: widget data mapping must be exact — the Kotlin providers read these
/// keys from HomeWidgetPreferences and render blindly.
void main() {
  group('WidgetService.prayerKeyValues', () {
    test('maps all five prayers + date to widget keys', () {
      final times = PrayerTimesResponse(
        prayers: [
          PrayerTime('Fajr', '05:20'),
          PrayerTime('Sunrise', '06:35'),
          PrayerTime('Dhuhr', '12:31'),
          PrayerTime('Asr', '15:44'),
          PrayerTime('Maghrib', '18:07'),
          PrayerTime('Isha', '19:21'),
        ],
        date: '2026-10-19',
        hijri: HijriInfo(),
      );

      final map = WidgetService.prayerKeyValues(times);
      expect(map[WidgetService.kFajr], '05:20');
      expect(map[WidgetService.kDhuhr], '12:31');
      expect(map[WidgetService.kAsr], '15:44');
      expect(map[WidgetService.kMaghrib], '18:07');
      expect(map[WidgetService.kIsha], '19:21');
      expect(map[WidgetService.kDate], '2026-10-19');
      // Sunrise is intentionally NOT a widget row.
      expect(map.length, 6);
    });

    test('missing prayer names are simply absent (no crash)', () {
      final times = PrayerTimesResponse(
        prayers: [PrayerTime('Fajr', '05:20')],
        date: '2026-10-19',
        hijri: HijriInfo(),
      );
      final map = WidgetService.prayerKeyValues(times);
      expect(map[WidgetService.kFajr], '05:20');
      expect(map.containsKey(WidgetService.kIsha), isFalse);
    });
  });

  group('WidgetService.streakKeyValues', () {
    test('null solo (logged out) zeroes everything', () {
      final map = WidgetService.streakKeyValues(null);
      expect(map, {WidgetService.kStreak: 0, WidgetService.kBest: 0, WidgetService.kToday: 0});
    });

    test('maps streak, best and today count', () {
      const solo = SoloStreakData(
        started: true,
        currentStreak: 12,
        bestStreak: 30,
        today: DayProgress(
          fajr: true,
          dhuhr: true,
          asr: true,
          completedCount: 3,
        ),
      );
      final map = WidgetService.streakKeyValues(solo);
      expect(map[WidgetService.kStreak], 12);
      expect(map[WidgetService.kBest], 30);
      expect(map[WidgetService.kToday], 3);
    });
  });
}
