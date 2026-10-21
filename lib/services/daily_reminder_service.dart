import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/daily_reminders.dart';
import 'notification_router.dart';

/// F11 — opt-in daily zikr/du'a notification with a user-selected category.
class DailyReminderService {
  DailyReminderService._();
  static final DailyReminderService instance = DailyReminderService._();

  static const _channelId = 'daily_zikr';
  static const _channelName = 'Daily Zikr & Du\'a';
  static const _baseId = 9500;
  static const _slots = 8;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    await NotificationRouter.instance.ensureInitialized();
    await NotificationRouter.instance.plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'A short zikr or du\'a every morning',
          importance: Importance.high,
        ));
    _initialized = true;
  }

  /// Re-schedules the next 7 morning reminders. Rotating content (instead of
  /// one repeating text) means each reminder feels fresh.
  Future<void> scheduleNext7Days({
    required String timezone,
    int hour = 8,
    int minute = 0,
    String category = 'all',
    bool isUrdu = false,
  }) async {
    await init();
    await cancelAll();
    final tz.Location location;
    try {
      location = tz.getLocation(timezone);
    } catch (_) {
      return;
    }
    final now = tz.TZDateTime.now(location);
    for (var i = 0; i < 7; i++) {
      final date =
          tz.TZDateTime(location, now.year, now.month, now.day + i);
      final reminder = reminderForDay(
        DateTime(date.year, date.month, date.day),
        category: category,
      );
      final when =
          tz.TZDateTime(location, date.year, date.month, date.day, hour, minute);
      if (!when.isAfter(now)) continue;
      final title = reminder.kind == ReminderKind.zikr
          ? (isUrdu ? 'آج کا ذکر' : 'Zikr of the Day')
          : (isUrdu ? 'آج کی دعا' : 'Du\'a of the Day');
      final body = isUrdu
          ? reminder.translationUr
          : reminder.translationEn;
      await NotificationRouter.instance.plugin.zonedSchedule(
        id: _baseId + i,
        title: title,
        body: body.length > 180 ? '${body.substring(0, 180)}…' : body,
        scheduledDate: when,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'A short zikr or du\'a every morning',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: jsonEncode({
          'type': 'daily_reminder',
          'id': reminder.id,
        }),
      );
    }
  }

  Future<void> cancelAll() async {
    for (var id = _baseId; id < _baseId + _slots; id++) {
      try {
        await NotificationRouter.instance.plugin.cancel(id: id);
      } catch (_) {}
    }
  }
}
