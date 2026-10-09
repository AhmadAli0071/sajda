import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../services/streak_v2_api.dart';
import 'firebase_auth_service.dart';
import 'notification_router.dart';

/// FCM push for group streak activity (prayer ticks, day-complete, join
/// requests). The streak system NEVER depends on push: every failure here
/// is swallowed so registration or display issues can't break sign-in
/// or prayer ticks.
class PushService {
  static final PushService instance = PushService._();
  PushService._();

  // Shared singleton plugin — tap routing lives in NotificationRouter.
  FlutterLocalNotificationsPlugin get _plugin =>
      NotificationRouter.instance.plugin;
  static const _channel = AndroidNotificationChannel(
    'streak_activity',
    'Streak Activity',
    description: 'Group members completing prayers and streak milestones',
    importance: Importance.high,
  );
  static const int _firstId = 9500;
  bool _initialized = false;
  bool _listenersSet = false;
  int _nextId = _firstId;

  /// Called whenever a backend session exists (app boot + every sign-in).
  Future<void> onSession() async {
    try {
      await FirebaseAuthService.instance.ensureInitialized();
    } catch (_) {
      return; // Firebase unavailable — push stays off, streaks still work.
    }
    try {
      await _init();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _register(token);
      if (!_listenersSet) {
        _listenersSet = true;
        FirebaseMessaging.instance.onTokenRefresh.listen(_register);
      }
    } catch (_) {}
  }

  Future<void> _init() async {
    if (_initialized) return;
    await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
    // ONE initialize() for the plugin singleton — taps are routed by
    // NotificationRouter (a second initialize here would steal its callback).
    await NotificationRouter.instance.ensureInitialized();
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
    FirebaseMessaging.onMessage.listen(_onMessage);
    // Taps: app open in background, or cold-start from a terminated state.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTapMessage);
    unawaited(
      FirebaseMessaging.instance.getInitialMessage().then((m) {
        if (m != null) _handleTapMessage(m);
      }),
    );
    _initialized = true;
  }

  Future<void> _register(String token) async {
    try {
      await StreakV2Api.instance.registerDevice(token);
    } catch (e) {
      // Never fatal, but never silent either — a device that never
      // registers is exactly why push audits show zero tokens.
      debugPrint('[PushService] registerDevice failed: $e');
    }
  }

  void _onMessage(RemoteMessage message) {
    final n = message.notification;
    final title = n?.title;
    if (title == null || title.isEmpty) return;
    _plugin.show(
      id: _nextId++,
      title: title,
      body: n?.body,
      payload: jsonEncode(message.data),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(n?.body ?? ''),
        ),
      ),
    );
  }

  // ── Tap routing ──

  /// FCM taps delegate to the shared router (join_*, streak ticks, etc.).
  void _handleTapMessage(RemoteMessage message) {
    NotificationRouter.handleRemoteMessageData(message.data);
  }
}
