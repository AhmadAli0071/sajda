import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../services/api_client.dart';
import 'notification_router.dart';

class DuaNotificationService {
  static final DuaNotificationService instance =
      DuaNotificationService._();
  DuaNotificationService._();

  // Shared singleton plugin — tap routing lives in NotificationRouter.
  FlutterLocalNotificationsPlugin get _plugin =>
      NotificationRouter.instance.plugin;
  static const int _baseId = 9200;
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
          'daily_dua',
          'Daily Dua',
          description: 'A beautiful dua every morning at 8 AM',
          importance: Importance.high,
        ));
    _initialized = true;
  }

  /// (Re)schedules the daily dua notification to repeat every day.
  Future<void> scheduleNext7Days({int hour = 8, int minute = 0, String timezone = 'Asia/Karachi'}) async {
    if (!_initialized) return;
    await cancelAll();
    final location = tz.getLocation(timezone);
    final now = tz.TZDateTime.now(location);
    final dayOfYear = now.difference(tz.TZDateTime(location, now.year)).inDays;
    List<dynamic> duas = [];
    try {
      duas = await ApiClient.instance.getDuas();
    } catch (_) {}

    var when = DateTime(now.year, now.month, now.day, hour, minute);
    if (when.isBefore(DateTime.now())) {
      when = when.add(const Duration(days: 1));
    }
    String title = 'Daily Dua';
    String body = 'A beautiful dua for today';
    if (duas.isNotEmpty) {
      final dua = duas[(dayOfYear) % duas.length];
      title = dua.titleUr.isNotEmpty ? dua.titleUr : dua.titleEn;
      final text = dua.urdu.isNotEmpty ? dua.urdu : dua.english;
      body = text.length > 160 ? '${text.substring(0, 160)}...' : text;
    }
    await _plugin.zonedSchedule(
      id: _baseId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when, location),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_dua',
          'Daily Dua',
          channelDescription: 'A beautiful dua every morning at 8 AM',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_dua',
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