import 'package:home_widget/home_widget.dart';

import '../models/models.dart';
import '../models/streak_v2.dart';

/// Home screen widget data bridge (feature F2).
///
/// Writes prayer times + streak progress into the `HomeWidgetPreferences`
/// SharedPreferences file (read natively by SajdaPrayerWidgetProvider /
/// SajdaStreakWidgetProvider) and pokes the widgets to re-render.
///
/// Every call is fire-and-forget and fully guarded: widgets are a nice-to-
/// have, so a missing plugin channel (tests, background isolates) must
/// never break the app.
class WidgetService {
  WidgetService._();

  static const String prayerProvider =
      'com.sajda.dataplus.SajdaPrayerWidgetProvider';
  static const String streakProvider =
      'com.sajda.dataplus.SajdaStreakWidgetProvider';

  static const String kFajr = 'widget_fajr';
  static const String kDhuhr = 'widget_dhuhr';
  static const String kAsr = 'widget_asr';
  static const String kMaghrib = 'widget_maghrib';
  static const String kIsha = 'widget_isha';
  static const String kDate = 'widget_date';
  static const String kCity = 'widget_city';

  static const String kStreak = 'widget_streak';
  static const String kBest = 'widget_best';
  static const String kToday = 'widget_today';

  /// Pure mapping of prayer times -> widget preference keys (unit-tested).
  static Map<String, String> prayerKeyValues(PrayerTimesResponse times) {
    final out = <String, String>{kDate: times.date};
    for (final p in times.prayers) {
      switch (p.name) {
        case 'Fajr':
          out[kFajr] = p.time;
        case 'Dhuhr':
          out[kDhuhr] = p.time;
        case 'Asr':
          out[kAsr] = p.time;
        case 'Maghrib':
          out[kMaghrib] = p.time;
        case 'Isha':
          out[kIsha] = p.time;
      }
    }
    return out;
  }

  /// Pure mapping of solo streak -> widget preference keys (unit-tested).
  static Map<String, int> streakKeyValues(SoloStreakData? solo) => {
        kStreak: solo?.currentStreak ?? 0,
        kBest: solo?.bestStreak ?? 0,
        kToday: solo?.today.completedCount ?? 0,
      };

  static Future<void> savePrayerTimes(PrayerTimesResponse times,
      {String? city}) async {
    try {
      for (final entry in prayerKeyValues(times).entries) {
        await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
      }
      if (city != null && city.isNotEmpty) {
        await HomeWidget.saveWidgetData<String>(kCity, city);
      }
      await HomeWidget.updateWidget(name: prayerProvider);
    } catch (_) {
      // Plugin channel unavailable (tests / background) — ignore.
    }
  }

  static Future<void> saveStreak(SoloStreakData? solo) async {
    try {
      for (final entry in streakKeyValues(solo).entries) {
        await HomeWidget.saveWidgetData<int>(entry.key, entry.value);
      }
      await HomeWidget.updateWidget(name: streakProvider);
    } catch (_) {
      // Plugin channel unavailable (tests / background) — ignore.
    }
  }
}
