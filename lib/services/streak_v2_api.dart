import '../services/api_client.dart';
import 'package:sajda_dataplus/models/streak_v2.dart';

/// Typed repository for the v2 streak system. Thin wrapper over ApiClient —
/// the backend is authoritative; every call returns parsed models or throws
/// ApiException(code, status).
class StreakV2Api {
  static final StreakV2Api instance = StreakV2Api._();
  StreakV2Api._();

  String get _base => '/streak/v2';

  // ── Solo ──

  Future<SoloStreakData> getSolo() async {
    final json = await ApiClient.instance.get('$_base/solo');
    return SoloStreakData.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<SoloStreakData> startSolo() async {
    final json = await ApiClient.instance.post('$_base/solo/start', {});
    return SoloStreakData.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// THE one canonical prayer tick. One action updates Solo + every group.
  Future<CompletePrayerResult> completePrayer(String prayer, {bool completed = true}) async {
    final json = await ApiClient.instance
        .post('$_base/prayers/complete', {'prayer': prayer, 'completed': completed});
    final data = json['data'] as Map<String, dynamic>;
    return CompletePrayerResult(
      solo: SoloStreakData.fromJson(data['solo'] as Map<String, dynamic>? ?? {}),
      groups: (data['groups'] as List? ?? [])
          .map((e) => GroupTouch.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<HistoryData> getSoloHistory({int? year, int? month}) async {
    final q = (year != null && month != null) ? '?year=$year&month=$month' : '';
    final json = await ApiClient.instance.get('$_base/solo/history$q');
    return HistoryData.fromJson(json['data'] as Map<String, dynamic>);
  }

  // ── Groups ──

  Future<List<GroupSummary>> getMyGroups() async {
    final json = await ApiClient.instance.get('$_base/groups');
    final list = json['data']?['groups'] as List? ?? [];
    return list.map((e) => GroupSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<GroupDetail> createGroup(String name, {bool public = false}) async {
    final json = await ApiClient.instance.post('$_base/groups', {
      'name': name,
      'visibility': public ? 'public' : 'invite',
    });
    return GroupDetail.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<GroupDashboardData> getGroupDashboard(String groupId) async {
    final json = await ApiClient.instance.get('$_base/groups/$groupId/dashboard');
    return GroupDashboardData.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<MemberDetailData> getMemberDetail(String groupId, String userId) async {
    final json = await ApiClient.instance.get('$_base/groups/$groupId/members/$userId');
    return MemberDetailData.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<HistoryData> getGroupHistory(String groupId, {int? year, int? month}) async {
    final q = (year != null && month != null) ? '?year=$year&month=$month' : '';
    final json = await ApiClient.instance.get('$_base/groups/$groupId/history$q');
    return HistoryData.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<ActivityPage> getGroupActivity(String groupId, {DateTime? before, int limit = 20}) async {
    final params = <String>[
      if (before != null) 'before=${before.toIso8601String()}',
      'limit=$limit',
    ];
    final json = await ApiClient.instance.get('$_base/groups/$groupId/activity?${params.join('&')}');
    final data = json['data'] as Map<String, dynamic>;
    return ActivityPage(
      items: (data['items'] as List? ?? [])
          .map((e) => ActivityItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: data['hasMore'] == true,
      nextCursor: data['nextCursor']?.toString(),
    );
  }

  Future<void> leaveGroup(String groupId) =>
      ApiClient.instance.post('$_base/groups/$groupId/leave', {});

  Future<void> removeMember(String groupId, String userId) =>
      ApiClient.instance.post('$_base/groups/$groupId/members/$userId/remove', {});

  Future<void> renameGroup(String groupId, String name) async {
    await ApiClient.instance.post('$_base/groups/$groupId/rename', {'name': name});
  }

  Future<String> rotateInviteCode(String groupId) async {
    final json = await ApiClient.instance.post('$_base/groups/$groupId/invite/rotate', {});
    return json['data']?['inviteCode']?.toString() ?? '';
  }

  Future<void> transferOwnership(String groupId, String userId) =>
      ApiClient.instance.post('$_base/groups/$groupId/transfer', {'userId': userId});

  Future<void> archiveGroup(String groupId) =>
      ApiClient.instance.post('$_base/groups/$groupId/archive', {});

  // ── Discover / invite / join ──

  Future<DiscoverPage> discoverGroups(String query, {int page = 0}) async {
    final json = await ApiClient.instance
        .get('$_base/groups/discover?q=${Uri.encodeQueryComponent(query)}&page=$page');
    final data = json['data'] as Map<String, dynamic>;
    return DiscoverPage(
      items: (data['items'] as List? ?? [])
          .map((e) => DiscoverGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: data['hasMore'] == true,
      page: page,
    );
  }

  Future<InvitePreview> getInvitePreview(String code) async {
    final json = await ApiClient.instance.get('$_base/invite/${code.toUpperCase()}');
    return InvitePreview.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Direct join via invite code. Already-member is a SUCCESS result.
  Future<JoinResult> joinByInviteCode(String code) async {
    final json = await ApiClient.instance.post('$_base/invite/${code.toUpperCase()}/join', {});
    final data = json['data'] as Map<String, dynamic>;
    return JoinResult(
      alreadyMember: data['alreadyMember'] == true,
      groupId: data['groupId']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      message: data['message']?.toString() ?? '',
    );
  }

  Future<void> requestToJoin(String groupId) =>
      ApiClient.instance.post('$_base/groups/$groupId/join-request', {});

  Future<List<JoinRequestItem>> getGroupRequests(String groupId) async {
    final json = await ApiClient.instance.get('$_base/groups/$groupId/requests');
    final list = json['data']?['items'] as List? ?? [];
    return list.map((e) => JoinRequestItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> approveRequest(String requestId) =>
      ApiClient.instance.post('$_base/requests/$requestId/approve', {});

  Future<void> declineRequest(String requestId) =>
      ApiClient.instance.post('$_base/requests/$requestId/decline', {});

  // ── Notifications ──

  Future<NotificationFeed> getNotifications() async {
    final json = await ApiClient.instance.get('$_base/notifications');
    final data = json['data'] as Map<String, dynamic>;
    return NotificationFeed(
      unread: data['unread'] is num ? (data['unread'] as num).toInt() : 0,
      items: (data['items'] as List? ?? [])
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<void> markNotificationsSeen() =>
      ApiClient.instance.post('$_base/notifications/seen', {});

  Future<void> registerDevice(String token, {String platform = 'android'}) =>
      ApiClient.instance.post('$_base/devices', {'token': token, 'platform': platform});

  // ── Nudge (Group Prayer Circle) ──

  /// Send a friendly reminder push to a group member. Backend enforces
  /// rate limits (once per prayer per day; max 3/day per target) and
  /// returns 429 with code NUDGE_DUPLICATE / NUDGE_LIMIT when exceeded.
  Future<void> nudgeMember(String groupId, String targetUserId, {String? prayer}) {
    final body = <String, dynamic>{
      'groupId': groupId,
      'targetUserId': targetUserId,
    };
    if (prayer != null) body['prayerName'] = prayer;
    return ApiClient.instance.post('/group/v2/nudge', body);
  }
}

// ---------- result types ----------

class GroupTouch {
  final String groupId;
  final String name;
  final String dateKey;
  final int currentStreak;
  const GroupTouch({required this.groupId, required this.name, this.dateKey = '', this.currentStreak = 0});
  factory GroupTouch.fromJson(Map<String, dynamic> json) => GroupTouch(
        groupId: json['groupId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        dateKey: json['dateKey']?.toString() ?? '',
        currentStreak: json['currentStreak'] is num ? (json['currentStreak'] as num).toInt() : 0,
      );
}

class CompletePrayerResult {
  final SoloStreakData solo;
  final List<GroupTouch> groups;
  const CompletePrayerResult({required this.solo, required this.groups});
}

class JoinResult {
  final bool alreadyMember;
  final String groupId;
  final String name;
  final String message;
  const JoinResult({required this.alreadyMember, required this.groupId, required this.name, required this.message});
}

class ActivityPage {
  final List<ActivityItem> items;
  final bool hasMore;
  final String? nextCursor;
  const ActivityPage({required this.items, required this.hasMore, this.nextCursor});
}

class DiscoverPage {
  final List<DiscoverGroup> items;
  final bool hasMore;
  final int page;
  const DiscoverPage({required this.items, required this.hasMore, required this.page});
}

class NotificationFeed {
  final int unread;
  final List<NotificationItem> items;
  const NotificationFeed({required this.unread, required this.items});
}
