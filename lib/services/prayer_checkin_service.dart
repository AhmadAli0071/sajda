import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_router.dart';

class PrayerCheckinService {
  static final PrayerCheckinService instance = PrayerCheckinService._();
  PrayerCheckinService._();

  // Shared singleton plugin — tap routing (including the Yes/No action
  // buttons) lives in NotificationRouter.
  FlutterLocalNotificationsPlugin get _plugin =>
      NotificationRouter.instance.plugin;
  bool _initialized = false;

  static const String _channelId = 'prayer_checkin';
  static const String _channelName = 'Prayer Check-in';
  static const String _channelDesc = 'Did you pray? Tap to confirm';

  Future<void> init() async {
    if (_initialized) return;
    await NotificationRouter.instance.ensureInitialized();

    if (_plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>() != null) {
      _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    tzdata.initializeTimeZones();
    _initialized = true;
  }

  Future<void> scheduleCheckIns(List<dynamic> prayers, {String timezone = 'Asia/Karachi'}) async {
    await init();
    await cancelAll();

    final location = tz.getLocation(timezone);
    final now = tz.TZDateTime.now(location);

    for (final p in prayers) {
      if (p.name == 'Sunrise') continue;
      final parts = p.time.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      var prayerTime = tz.TZDateTime(location, now.year, now.month, now.day, hour, minute);
      if (prayerTime.isBefore(now)) {
        prayerTime = prayerTime.add(const Duration(days: 1));
      }

      final checkInTime = prayerTime.add(const Duration(hours: 1));
      final isFridayDhuhr =
          p.name == 'Dhuhr' && prayerTime.weekday == DateTime.friday;
      final displayName = isFridayDhuhr ? 'Friday' : p.name;

      await _plugin.zonedSchedule(
        id: _idFor(p.name),
        title: 'Did you pray?',
        body: 'Did you complete $displayName prayer?',
        scheduledDate: checkInTime,
        notificationDetails: _details(p.name),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: jsonEncode({'prayer': p.name, 'timezone': timezone}),
      );
    }
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    const prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    for (final p in prayers) {
      await _plugin.cancel(id: _idFor(p));
    }
  }

  int _idFor(String prayer) {
    return prayer.hashCode & 0x7FFFFFFF;
  }

  NotificationDetails _details(String prayer) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        autoCancel: true,
        actions: const [
          AndroidNotificationAction('yes', 'Yes'),
          AndroidNotificationAction('no', 'No'),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        categoryIdentifier: 'PRAYER_CHECKIN',
      ),
    );
  }
}
