import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'hijri_date_service.dart';
import 'local_prayer_times_service.dart';
import 'notification_router.dart';
import 'sajda_stats_service.dart';

/// F10 — Ramadan mode helpers: Iftar reminders scheduled from on-device
/// prayer-time calculation, Ramadan detection, and the countdown inputs.
class RamadanService {
  RamadanService._();
  static const _channelId = 'ramadan_iftar';
  static const _baseId = 9600;
  static const _slots = 31;
  static const _kLastScheduled = 'sajda_ramadan_scheduled_day';

  static bool _initialized = false;

  static bool isRamadan([DateTime? now]) =>
      HijriDateService.convertPlain(now ?? DateTime.now()).month == 9;

  static int ramadanDay([DateTime? now]) =>
      HijriDateService.convertPlain(now ?? DateTime.now()).day;

  static Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    await NotificationRouter.instance.ensureInitialized();
    await NotificationRouter.instance.plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          'Ramadan Iftar Reminders',
          description: 'A gentle reminder at Maghrib during Ramadan',
          importance: Importance.high,
        ));
    _initialized = true;
  }

  /// (Re)schedules the next [days] Iftar reminders. No-op outside Ramadan and
  /// on repeat calls during the same local day.
  static Future<void> scheduleIftarReminders({
    required double lat,
    required double lng,
    required String timezone,
    required int method,
    required int school,
    required String city,
    required bool isUrdu,
    int days = 30,
  }) async {
    if (!isRamadan()) return;
    if (lat == 0 && lng == 0) return;
    await init();
    final tz.Location location;
    try {
      location = tz.getLocation(timezone);
    } catch (_) {
      return;
    }
    final now = tz.TZDateTime.now(location);
    final todayKey = SajdaStatsService.dayKeyOf(now);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_kLastScheduled) == todayKey) return;

    await cancelAll();
    var scheduled = 0;
    for (var i = 0; i < days; i++) {
      final localDate = tz.TZDateTime(location, now.year, now.month, now.day)
          .add(Duration(days: i));
      final civilDate = DateTime(localDate.year, localDate.month, localDate.day);
      // Stop at Eid: never schedule Iftar reminders after Ramadan.
      if (HijriDateService.convertPlain(civilDate).month != 9) break;
      final times = LocalPrayerTimesService.calculate(
        lat: lat,
        lng: lng,
        timezone: timezone,
        date: civilDate,
        method: method,
        school: school,
      );
      if (times == null) continue;
      String? maghribTime;
      for (final p in times.prayers) {
        if (p.name == 'Maghrib') {
          maghribTime = p.time;
          break;
        }
      }
      if (maghribTime == null) continue;
      final parts = maghribTime.split(':');
      if (parts.length != 2) continue;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) continue;
      final when = tz.TZDateTime(
        location,
        localDate.year,
        localDate.month,
        localDate.day,
        h,
        m,
      );
      if (!when.isAfter(now)) continue;
      await NotificationRouter.instance.plugin.zonedSchedule(
        id: _baseId + i,
        title: isUrdu ? 'رمضان مبارک' : 'Ramadan Mubarak',
        body: isUrdu
            ? '$city میں افطار کا وقت $maghribTime ہے'
            : 'Iftar time in $city is $maghribTime',
        scheduledDate: when,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Ramadan Iftar Reminders',
            channelDescription: 'A gentle reminder at Maghrib during Ramadan',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: jsonEncode({'type': 'ramadan_iftar'}),
      );
      scheduled++;
    }
    if (scheduled > 0) {
      await prefs.setString(_kLastScheduled, todayKey);
    }
  }

  static Future<void> cancelAll() async {
    for (var id = _baseId; id < _baseId + _slots; id++) {
      try {
        await NotificationRouter.instance.plugin.cancel(id: id);
      } catch (_) {}
    }
    // Allow re-enabling on the same day to schedule again.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastScheduled);
  }

  /// Parses "HH:mm" into a wall-clock [DateTime] on [day].
  static DateTime? atTime(DateTime day, String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return DateTime(day.year, day.month, day.day, h, m);
  }
}
