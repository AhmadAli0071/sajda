import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:quran/quran.dart' as q;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../services/quran_service.dart';
import 'notification_router.dart';

class AyahNotificationService {
  static final AyahNotificationService instance =
      AyahNotificationService._();
  AyahNotificationService._();

  // Shared singleton plugin — tap routing lives in NotificationRouter.
  FlutterLocalNotificationsPlugin get _plugin =>
      NotificationRouter.instance.plugin;
  static const int _baseId = 9400;
  bool _initialized = false;

  /// Called once from [main].
  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Karachi'));
    }
    await NotificationRouter.instance.ensureInitialized();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'daily_ayah',
          'Ayah of the Day',
          description: 'A beautiful ayah after Zuhr every day',
          importance: Importance.high,
        ));
    _initialized = true;
  }

  /// (Re)schedules the daily ayah notification to repeat every day.
  Future<void> scheduleNext7Days({int hour = 13, int minute = 30, String timezone = 'Asia/Karachi'}) async {
    if (!_initialized) return;
    await cancelAll();
    final location = tz.getLocation(timezone);
    final now = tz.TZDateTime.now(location);
    final dayOfYear = now.difference(tz.TZDateTime(location, now.year)).inDays;

    var when = tz.TZDateTime(location, now.year, now.month, now.day, hour, minute);
    if (when.isBefore(now)) {
      when = when.add(const Duration(days: 1));
    }
    final (surah, ayah) = QuranService.ayahForDay(dayOfYear);
    final arabic = QuranService.instance.verseArabic(surah, ayah);
    final body = arabic.length > 200 ? '${arabic.substring(0, 200)}...' : arabic;
    await _plugin.zonedSchedule(
      id: _baseId,
      title: 'Ayah of the Day • ${q.getSurahNameEnglish(surah)} $ayah',
      body: body,
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_ayah',
          'Ayah of the Day',
          channelDescription: 'A beautiful ayah after Zuhr every day',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_ayah',
    );
  }

  Future<void> cancelAll() async {
    if (!_initialized) return;
    for (var id = _baseId; id < _baseId + 100; id++) {
      try {
        await _plugin.cancel(id: id);
      } catch (_) {}
    }
  }
}