import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/daily_zikr_screen.dart';
import '../screens/group_dashboard_screen.dart';
import '../screens/group_settings_screen.dart';
import '../screens/ramadan_screen.dart';
import 'api_client.dart';
import 'streak_v2_api.dart';

/// The ONE place every notification tap lands — local plugin taps, FCM
/// background taps, FCM data messages, and cold-start launch payloads.
///
/// Why this exists: `FlutterLocalNotificationsPlugin` is a factory SINGLETON
/// (see `factory FlutterLocalNotificationsPlugin() => _instance`), and every
/// `initialize()` call OVERWRITES the shared `_onDidReceiveNotificationResponse`
/// field on the platform implementation. Before this router, six services each
/// called `initialize()` with their own callback — whichever ran LAST stole
/// every other service's taps, and a `null` callback silently disabled routing
/// for all of them. `ensureInitialized()` below is now the only `initialize()`
/// in the app; services create their channels and schedule through [plugin].
class NotificationRouter {
  static final NotificationRouter instance = NotificationRouter._();
  NotificationRouter._();

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  /// Root navigator for notification-tap routing (wired in main.dart).
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  bool _initialized = false;

  /// Payload of a notification the app was cold-started from. Held until the
  /// shell exists (see [flushPendingLaunch]) — the navigator is not mounted
  /// during main()/splash, so routing early would be a no-op.
  String? _pendingLaunchPayload;

  /// THE one initialize() in the app. Every notification service must call
  /// this instead of `plugin.initialize(...)`.
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Non-prompting on iOS: permission requests stay explicit (via each
    // service's requestNotificationsPermission) so we never prompt at boot.
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await plugin.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalTap,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundTap,
    );
    _initialized = true;
    unawaited(_captureLaunchPayload());
  }

  /// Cold start from a terminated state: the plugin remembers the payload of
  /// the notification the user tapped to open us. This was previously never
  /// read, so cold-start taps did nothing at all.
  Future<void> _captureLaunchPayload() async {
    try {
      final details = await plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return;
      final raw = details.notificationResponse?.payload;
      if (raw == null || raw.isEmpty) return;
      _pendingLaunchPayload = raw;
    } catch (_) {}
  }

  /// Called once the shell (and its navigator) is up: replays a cold-start
  /// tap. Safe to call repeatedly — the pending payload is cleared on use.
  void flushPendingLaunch() {
    final raw = _pendingLaunchPayload;
    if (raw == null) return;
    _pendingLaunchPayload = null;
    // Post-frame so the first route is fully built before we push on top.
    WidgetsBinding.instance.addPostFrameCallback((_) => handlePayload(raw));
  }

  // ── Entry points ──

  void _onLocalTap(NotificationResponse response) {
    handlePayload(response.payload, actionId: response.actionId);
  }

  /// Background isolate entry point (Android action buttons). Navigation is
  /// impossible here — only the side effect (the prayer tick) runs; the
  /// foreground tap path handles UI.
  @pragma('vm:entry-point')
  static Future<void> _onBackgroundTap(NotificationResponse response) async {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final data = _decode(raw);
      if (response.actionId == 'yes') await _tickPrayer(data);
    } catch (_) {}
  }

  /// FCM tap (background-open or cold-start getInitialMessage). Delegates to
  /// [handlePayload] so FCM and local taps share one routing table.
  static void handleRemoteMessageData(Map<String, dynamic> data) {
    instance._route(data);
  }

  /// Public entry for any raw payload string (JSON map or legacy plain
  /// string such as `'daily_ayah'`).
  void handlePayload(String? raw, {String? actionId}) {
    if (raw == null || raw.isEmpty) return;
    final data = _decode(raw);
    if (actionId == 'yes') {
      unawaited(_tickPrayer(data));
    }
    _route(data);
  }

  static Map<String, dynamic> _decode(String raw) {
    if (raw.startsWith('{')) {
      try {
        return jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    // Legacy payloads are the bare type string.
    return {'type': raw};
  }

  // ── Routing ──

  void _route(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    switch (type) {
      case 'daily_ayah':
      case 'prayer_azan':
        // Home tab (0) shows the ayah of the day and the prayer schedule.
        switchTab(0);
        break;
      case 'prayer_checkin':
      case 'prayer_completed':
      case 'group_day_completed':
        switchTab(2); // Streak tab
        break;
      case 'join_request':
      case 'member_joined':
      case 'join_decided':
        _routeGroup(data);
        break;
      case 'daily_reminder':
        _push((_) => const DailyZikrScreen());
        break;
      case 'ramadan_iftar':
        _push((_) => const RamadanScreen());
        break;
    }
  }

  /// join_request / member_joined → owners and admins land directly on the
  /// approve/decline tab of group settings; everyone else (and join_decided
  /// approvals) lands on the group dashboard.
  Future<void> _routeGroup(Map<String, dynamic> data) async {
    final type = data['type']?.toString();
    if (type == 'join_decided' && data['approved']?.toString() != 'true') {
      return; // nothing to open for a declined request
    }
    final groupId = data['groupId']?.toString();
    if (groupId == null || groupId.isEmpty) return;
    Widget screen = GroupDashboardScreen(groupId: groupId);
    if (type == 'join_request' || type == 'member_joined') {
      try {
        final dash = await StreakV2Api.instance.getGroupDashboard(groupId);
        final role = dash.group.myRole;
        if (role == 'owner' || role == 'admin') {
          screen = GroupSettingsScreen(group: dash.group, initialTab: 1);
        }
      } catch (_) {
        // Dashboard alone is the safe fallback (it loads its own data).
      }
    }
    _push((_) => screen);
  }

  /// THE one canonical prayer tick — updates the solo streak and every group
  /// the user belongs to (server fan-out). Timezone/dateKey are resolved
  /// server-side from the user's profile.
  static Future<void> _tickPrayer(Map<String, dynamic> data) async {
    final prayer = data['prayer'] as String?;
    if (prayer == null || prayer.isEmpty) return;
    try {
      // Include the actual Fajr time so the backend grace window is accurate.
      final fajrMin = _fajrMinutesFromCache();
      await StreakV2Api.instance.completePrayer(
        prayer.toLowerCase(),
        fajrMinutes: fajrMin,
      );
    } catch (_) {}
  }

  /// Fajr minutes-since-midnight from the cached prayer times (or null).
  static int? _fajrMinutesFromCache() {
    final times = ApiClient.instance.cachedPrayerTimes;
    if (times == null) return null;
    try {
      final fajr = times.prayers.firstWhere((p) => p.name == 'Fajr');
      final parts = fajr.time.split(':');
      if (parts.length != 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) return null;
      return h * 60 + m;
    } catch (_) {
      return null;
    }
  }

  // ── Navigation helpers ──

  /// Switches the bottom-nav bar to [index]. MainShell listens on
  /// [tabIndex]; if the shell isn't mounted yet (cold start / onboarding)
  /// the value is remembered and applied when it mounts.
  static final ValueNotifier<int> tabIndex = ValueNotifier<int>(0);

  static void switchTab(int index) {
    if (tabIndex.value != index) tabIndex.value = index;
  }

  void _push(WidgetBuilder builder) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    try {
      nav.push(MaterialPageRoute(builder: builder));
    } catch (_) {}
  }
}
