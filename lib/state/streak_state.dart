import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/streak_v2.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/push_service.dart';
import '../services/sajda_stats_service.dart';
import '../services/streak_v2_api.dart';
import '../services/widget_service.dart';

enum StreakLoadPhase { idle, loading, ready, error }

/// Central state for the v2 streak system (Solo + Friends & Family groups).
///
/// The backend is authoritative: every method applies server state to the
/// UI. The one canonical prayer tick (`togglePrayer`) updates Solo AND every
/// group from a single response. Local caches exist only for UX speed.
class StreakState extends ChangeNotifier {
  // ── Solo ──
  SoloStreakData? _solo;
  StreakLoadPhase _soloPhase = StreakLoadPhase.idle;
  String? _soloError;

  SoloStreakData? get solo => _solo;
  StreakLoadPhase get soloPhase => _soloPhase;
  String? get soloError => _soloError;

  // ── My groups ──
  List<GroupSummary> _groups = [];
  StreakLoadPhase _groupsPhase = StreakLoadPhase.idle;
  String? _groupsError;

  List<GroupSummary> get groups => List.unmodifiable(_groups);
  StreakLoadPhase get groupsPhase => _groupsPhase;
  String? get groupsError => _groupsError;
  List<GroupSummary> get activeGroups =>
      _groups.where((g) => !g.archived).toList();

  // ── Notifications (in-app feed; actor never sees own actions) ──
  int _unreadCount = 0;
  List<NotificationItem> _notifications = [];
  int get unreadCount => _unreadCount;
  List<NotificationItem> get notifications => List.unmodifiable(_notifications);

  // ── In-flight guards (no duplicate submissions) ──
  final Set<String> _prayersInFlight = {};

  /// True while [prayer]'s request is on the wire (per-prayer lock so the
  /// user can still tap other prayers).
  bool isPrayerInFlight(String prayer) => _prayersInFlight.contains(prayer);

  bool _authenticated = false;
  bool get authenticated => _authenticated;

  /// True when the backend rejected our token AND device-recovery failed —
  /// the Streak tab must then show the email magic-link gate instead of a
  /// dead UI that errors with "Authentication required" on every tap.
  bool _authFailed = false;
  bool get authFailed => _authFailed;

  final StreakV2Api _api = StreakV2Api.instance;

  // ── Day-change detection (stale-data fix) ──
  // The screens live in an IndexedStack, so their initState runs once per
  // app session — without an explicit rollover check the UI kept showing
  // YESTERDAY's ticks after midnight until a full app restart.
  String? _lastLoadedLocalDay;
  Timer? _dayWatch;
  bool _rolling = false;

  /// Local (device) calendar day key, YYYY-MM-DD.
  static String get _todayLocalKey {
    final n = DateTime.now();
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '${n.year.toString().padLeft(4, '0')}-$m-$d';
  }

  /// True when the app is still showing data loaded on a previous day.
  bool get isStaleDay =>
      _lastLoadedLocalDay != null && _lastLoadedLocalDay != _todayLocalKey;

  void _startDayWatch() {
    _dayWatch?.cancel();
    _dayWatch = Timer.periodic(const Duration(seconds: 30), (_) {
      if (isStaleDay) refreshIfDayChanged();
    });
  }

  /// Entry point — call on app start / streak screen open / auth change.
  Future<void> initialize() async {
    _authenticated = AuthService.instance.isAuthenticated;
    _authFailed = false;
    if (!_authenticated) {
      _dayWatch?.cancel();
      _dayWatch = null;
      _lastLoadedLocalDay = null;
      _solo = null;
      _groups = [];
      _notifications = [];
      _unreadCount = 0;
      _soloPhase = StreakLoadPhase.idle;
      _groupsPhase = StreakLoadPhase.idle;
      notifyListeners();
      return;
    }
    await Future.wait([refreshSolo(silent: true), refreshGroups(silent: true)]);
    _lastLoadedLocalDay = _todayLocalKey;
    _startDayWatch();
    unawaited(refreshNotifications());
    // Real-time group pushes: register the FCM token against this session.
    unawaited(PushService.instance.onSession());
  }

  Future<bool> _recoverAuth() async {
    // Keep the deviceId: the server resolves device accounts by it, so the
    // fallback login re-mints a token for the SAME user. (clear() here used
    // to destroy the deviceId — the next login then always 404'd on a
    // fresh random id and locked the user out of their streaks/groups.)
    await AuthService.instance.clearSession();
    try {
      await AuthService.instance.login();
      _authenticated = AuthService.instance.isAuthenticated;
      return _authenticated;
    } catch (_) {
      return false;
    }
  }

  Future<T> _withAuthRecovery<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ApiException catch (e) {
      if (!e.isAuthError) rethrow;
      if (await _recoverAuth()) return await action();
      // Token invalid AND no device account to fall back on — surface the
      // email sign-in gate.
      _authenticated = false;
      _authFailed = true;
      notifyListeners();
      rethrow;
    }
  }

  /// Called when the Streak tab becomes visible again or the app resumes:
  /// full re-fetch ONLY when the local day has rolled over — otherwise the
  /// cached state is already current and nothing is downloaded.
  Future<void> refreshIfDayChanged() async {
    if (_rolling || !isStaleDay || !AuthService.instance.isAuthenticated) {
      return;
    }
    _rolling = true;
    try {
      await initialize();
    } finally {
      _rolling = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // SOLO + GROUPS + NOTIFICATIONS
  // ─────────────────────────────────────────────────────────────────────

  Future<void> refreshSolo({bool silent = false}) async {
    if (!AuthService.instance.isAuthenticated) return;
    if (!silent) {
      _soloPhase = StreakLoadPhase.loading;
      notifyListeners();
    }
    try {
      final data = await _withAuthRecovery(_api.getSolo);
      _solo = data;
      _soloPhase = StreakLoadPhase.ready;
      _soloError = null;
      unawaited(WidgetService.saveStreak(_solo));
      unawaited(SajdaStatsService.instance.syncToday(data.today));
    } on ApiException catch (e) {
      if (e.isAuthError) {
        _authenticated = false;
        _authFailed = true;
      }
      _soloPhase = StreakLoadPhase.error;
      _soloError = e.isNetworkError ? 'network' : e.toString();
    } catch (e) {
      _soloPhase = StreakLoadPhase.error;
      _soloError = e.toString();
    }
    notifyListeners();
  }

  Future<void> refreshGroups({bool silent = false}) async {
    if (!AuthService.instance.isAuthenticated) return;
    if (!silent) {
      _groupsPhase = StreakLoadPhase.loading;
      notifyListeners();
    }
    try {
      final data = await _withAuthRecovery(_api.getMyGroups);
      _groups = data;
      _groupsPhase = StreakLoadPhase.ready;
      _groupsError = null;
    } on ApiException catch (e) {
      if (e.isAuthError) {
        _authenticated = false;
        _authFailed = true;
      }
      _groupsPhase = StreakLoadPhase.error;
      _groupsError = e.isNetworkError ? 'network' : e.toString();
    } catch (e) {
      _groupsPhase = StreakLoadPhase.error;
      _groupsError = e.toString();
    }
    notifyListeners();
  }

  Future<void> refreshNotifications() async {
    if (!AuthService.instance.isAuthenticated) return;
    try {
      final feed = await _withAuthRecovery(_api.getNotifications);
      _notifications = feed.items;
      _unreadCount = feed.unread;
    } catch (_) {
      // Notifications are supplementary — never break flows on them.
    }
    notifyListeners();
  }

  Future<void> markNotificationsSeen() async {
    _unreadCount = 0;
    notifyListeners();
    try {
      await _api.markNotificationsSeen();
    } catch (_) {}
  }

  /// Approve/decline a pending join request straight from the bell feed.
  /// Returns null on success, or a user-facing error message.
  Future<String?> decideJoinRequest(String requestId, bool approve) async {
    try {
      await _withAuthRecovery(
        () => approve
            ? _api.approveRequest(requestId)
            : _api.declineRequest(requestId),
      );
      _notifications = _notifications
          .where((n) => !(n.type == 'join_request' && n.id == requestId))
          .toList();
      notifyListeners();
      unawaited(refreshNotifications());
      unawaited(refreshGroups(silent: true));
      return null;
    } on ApiException catch (e) {
      return e.isNetworkError ? 'network' : e.toString();
    } catch (e) {
      return e.toString();
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // THE ONE PRAYER TICK — updates Solo + ALL groups from one response.
  // ─────────────────────────────────────────────────────────────────────

  /// Returns null on success, or an error message. Optimistic local state
  /// is applied immediately; the authoritative server response overwrites
  /// it (and group lists refresh from the fan-out result).
  Future<String?> togglePrayer(String prayer, bool completed) async {
    if (_prayersInFlight.contains(prayer)) return null;
    _prayersInFlight.add(prayer);

    // Optimistic solo state for instant feedback.
    if (_solo != null) {
      _solo = _solo!.copyWith(
        today: _solo!.today.withPrayer(prayer, completed),
      );
      notifyListeners();
      unawaited(WidgetService.saveStreak(_solo));
    }

    try {
      // Send the actual Fajr time (minutes since local midnight) so the
      // backend grace window uses the real Fajr cutoff, not a fixed 4 AM.
      final fajrMin = _fajrMinutes();
      final result = await _withAuthRecovery(
        () => _api.completePrayer(
          prayer,
          completed: completed,
          fajrMinutes: fajrMin,
        ),
      );
      _solo = result.solo;
      notifyListeners();
      unawaited(WidgetService.saveStreak(_solo));
      unawaited(SajdaStatsService.instance.syncToday(result.solo.today));
      // Groups were touched by the same tick — refresh their summaries
      // quietly so every group card/dashboard reflects the fan-out.
      unawaited(refreshGroups(silent: true));
      unawaited(refreshNotifications());
      return null;
    } on ApiException catch (e) {
      // Roll back optimistic state to the last authoritative snapshot.
      await refreshSolo(silent: true);
      return e.isNetworkError ? 'network' : e.toString();
    } catch (e) {
      await refreshSolo(silent: true);
      return e.toString();
    } finally {
      _prayersInFlight.remove(prayer);
    }
  }

  Future<String?> startSolo() async {
    try {
      final data = await _withAuthRecovery(_api.startSolo);
      _solo = data;
      _soloPhase = StreakLoadPhase.ready;
      notifyListeners();
      unawaited(WidgetService.saveStreak(_solo));
      unawaited(SajdaStatsService.instance.syncToday(data.today));
      return null;
    } catch (e) {
      return e is ApiException && e.isNetworkError ? 'network' : e.toString();
    }
  }

  /// Fajr time as minutes since local midnight, from the cached prayer
  /// times. Returns null when unavailable (backend falls back to 4 AM).
  int? _fajrMinutes() {
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

  // ─────────────────────────────────────────────────────────────────────
  // GROUP OPERATIONS (screens own navigation; state stays consistent)
  // ─────────────────────────────────────────────────────────────────────

  Future<String?> createGroup(String name, {bool public = false}) async {
    try {
      await _withAuthRecovery(() => _api.createGroup(name, public: public));
      await refreshGroups(silent: true);
      return null;
    } on ApiException catch (e) {
      return e.isNetworkError ? 'network' : e.toString();
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> leaveGroup(String groupId) async {
    try {
      await _withAuthRecovery(() => _api.leaveGroup(groupId));
      await refreshGroups(silent: true);
      return null;
    } on ApiException catch (e) {
      return e.isNetworkError ? 'network' : e.toString();
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> archiveGroup(String groupId) async {
    try {
      await _withAuthRecovery(() => _api.archiveGroup(groupId));
      await refreshGroups(silent: true);
      return null;
    } on ApiException catch (e) {
      return e.isNetworkError ? 'network' : e.toString();
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> renameGroup(String groupId, String name) async {
    try {
      await _withAuthRecovery(() => _api.renameGroup(groupId, name));
      await refreshGroups(silent: true);
      return null;
    } on ApiException catch (e) {
      return e.isNetworkError ? 'network' : e.toString();
    } catch (e) {
      return e.toString();
    }
  }

  /// Permanent, owner-only delete (members + history + progress).
  Future<String?> deleteGroup(String groupId) async {
    try {
      await _withAuthRecovery(() => _api.deleteGroup(groupId));
      await refreshGroups(silent: true);
      unawaited(refreshNotifications());
      return null;
    } on ApiException catch (e) {
      return e.isNetworkError ? 'network' : e.toString();
    } catch (e) {
      return e.toString();
    }
  }

  /// Used after any mutation from a group screen to keep cards in sync.
  Future<void> groupsChanged() => refreshGroups(silent: true);

  void reset() {
    _dayWatch?.cancel();
    _dayWatch = null;
    _lastLoadedLocalDay = null;
    _rolling = false;
    _solo = null;
    _groups = [];
    _notifications = [];
    _unreadCount = 0;
    _soloPhase = StreakLoadPhase.idle;
    _groupsPhase = StreakLoadPhase.idle;
    _soloError = null;
    _groupsError = null;
    _authenticated = false;
    _authFailed = false;
    notifyListeners();
    // Logged out / reset — the home widget must not keep stale streak data.
    unawaited(WidgetService.saveStreak(null));
  }
}
