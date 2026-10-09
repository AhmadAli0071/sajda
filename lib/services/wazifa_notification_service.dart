import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../services/api_client.dart';
import 'notification_router.dart';

class WazifaNotificationService {
  static final WazifaNotificationService instance =
      WazifaNotificationService._();
  WazifaNotificationService._();

  // Shared singleton plugin — tap routing lives in NotificationRouter.
  FlutterLocalNotificationsPlugin get _plugin =>
      NotificationRouter.instance.plugin;
  static const int _baseId = 9300;
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
          'daily_wazifa',
          'Daily Wazifa',
          description: 'Daily wazifa every evening at 6 PM',
          importance: Importance.high,
        ));
    _initialized = true;
  }

  /// (Re)schedules the daily wazifa notification to repeat every day.
  Future<void> scheduleNext7Days({int hour = 18, int minute = 0, String timezone = 'Asia/Karachi'}) async {
    if (!_initialized) return;
    await cancelAll();
    final location = tz.getLocation(timezone);
    final now = tz.TZDateTime.now(location);
    final dayOfYear = now.difference(tz.TZDateTime(location, now.year)).inDays;

    var when = DateTime(now.year, now.month, now.day, hour, minute);
    if (when.isBefore(DateTime.now())) {
      when = when.add(const Duration(days: 1));
    }
    String title = 'Daily Wazifa';
    String body = 'Today\'s wazifa for you';
    try {
      final wazifa = await ApiClient.instance.getWazifaByDay(dayOfYear);
      if (wazifa != null) {
        title = wazifa.titleUr.isNotEmpty ? wazifa.titleUr : wazifa.titleEn;
        final text = wazifa.urdu.isNotEmpty ? wazifa.urdu : wazifa.english;
        body = text.length > 160 ? '${text.substring(0, 160)}...' : text;
      }
    } catch (_) {}
    await _plugin.zonedSchedule(
      id: _baseId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, location),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_wazifa',
          'Daily Wazifa',
          channelDescription: 'Daily wazifa every evening at 6 PM',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_wazifa',
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