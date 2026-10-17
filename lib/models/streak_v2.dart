/// Typed models for the v2 streak system (Solo + Friends & Family groups).
/// The backend is authoritative — these mirror its response shapes exactly.
library;

// ---------- helpers ----------

String _s(dynamic v, [String fallback = '']) =>
    v == null ? fallback : v.toString();

int _i(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

bool _b(dynamic v, [bool fallback = false]) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true' || v == '1';
  return fallback;
}

DateTime? _date(dynamic v) {
  if (v == null) return null;
  try {
    return DateTime.parse(v.toString());
  } catch (_) {
    return null;
  }
}

// ---------- solo ----------

class DayProgress {
  final bool fajr;
  final bool dhuhr;
  final bool asr;
  final bool maghrib;
  final bool isha;
  final int completedCount;
  final bool isDayComplete;

  const DayProgress({
    this.fajr = false,
    this.dhuhr = false,
    this.asr = false,
    this.maghrib = false,
    this.isha = false,
    this.completedCount = 0,
    this.isDayComplete = false,
  });

  bool of(String prayer) => switch (prayer) {
        'fajr' => fajr,
        'dhuhr' => dhuhr,
        'asr' => asr,
        'maghrib' => maghrib,
        'isha' => isha,
        _ => false,
      };

  DayProgress withPrayer(String prayer, bool done) {
    var count = completedCount;
    final was = of(prayer);
    if (was && !done) count--;
    if (!was && done) count++;
    final next = DayProgress(
      fajr: prayer == 'fajr' ? done : fajr,
      dhuhr: prayer == 'dhuhr' ? done : dhuhr,
      asr: prayer == 'asr' ? done : asr,
      maghrib: prayer == 'maghrib' ? done : maghrib,
      isha: prayer == 'isha' ? done : isha,
      completedCount: count,
    );
    return next._withComplete();
  }

  DayProgress _withComplete() => DayProgress(
        fajr: fajr,
        dhuhr: dhuhr,
        asr: asr,
        maghrib: maghrib,
        isha: isha,
        completedCount: completedCount,
        isDayComplete: completedCount >= 5,
      );

  factory DayProgress.fromJson(Map<String, dynamic> json) => DayProgress(
        fajr: _b(json['fajr']),
        dhuhr: _b(json['dhuhr']),
        asr: _b(json['asr']),
        maghrib: _b(json['maghrib']),
        isha: _b(json['isha']),
        completedCount: _i(json['completedCount']),
        isDayComplete: _b(json['isDayComplete']),
      );
}

class SoloStreakData {
  final bool started;
  final int currentStreak;
  final int bestStreak;
  final String? currentStreakStartDate;
  final String? lastCompletedDay;
  final DayProgress today;

  const SoloStreakData({
    this.started = false,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.currentStreakStartDate,
    this.lastCompletedDay,
    this.today = const DayProgress(),
  });

  SoloStreakData copyWith({DayProgress? today}) => SoloStreakData(
        started: started,
        currentStreak: currentStreak,
        bestStreak: bestStreak,
        currentStreakStartDate: currentStreakStartDate,
        lastCompletedDay: lastCompletedDay,
        today: today ?? this.today,
      );

  factory SoloStreakData.fromJson(Map<String, dynamic> json) => SoloStreakData(
        started: _b(json['started'], true),
        currentStreak: _i(json['currentStreak']),
        bestStreak: _i(json['bestStreak']),
        currentStreakStartDate: json['currentStreakStartDate']?.toString(),
        lastCompletedDay: json['lastCompletedDay']?.toString(),
        today: DayProgress.fromJson(json['today'] as Map<String, dynamic>? ?? {}),
      );
}

// ---------- history ----------

class MonthDay {
  final String dateKey;
  final int day;
  final String state; // complete | missed | today | future | none
  final int completedCount;

  const MonthDay({
    required this.dateKey,
    required this.day,
    required this.state,
    this.completedCount = 0,
  });

  factory MonthDay.fromJson(Map<String, dynamic> json) => MonthDay(
        dateKey: _s(json['dateKey']),
        day: _i(json['day']),
        state: _s(json['state'], 'future'),
        completedCount: _i(json['completedCount']),
      );
}

class HistoryData {
  final int year;
  final int month;
  final List<MonthDay> calendar;
  final int currentStreak;
  final int bestStreak;

  const HistoryData({
    required this.year,
    required this.month,
    required this.calendar,
    this.currentStreak = 0,
    this.bestStreak = 0,
  });

  factory HistoryData.fromJson(Map<String, dynamic> json) => HistoryData(
        year: _i(json['year']),
        month: _i(json['month']),
        calendar: (json['calendar'] as List? ?? [])
            .map((e) => MonthDay.fromJson(e as Map<String, dynamic>))
            .toList(),
        currentStreak: _i(json['currentStreak']),
        bestStreak: _i(json['bestStreak']),
      );
}

// ---------- groups ----------

class GroupSummary {
  final String groupId;
  final String name;
  final String status; // active | archived
  final String visibility; // public | invite
  final String timezone;
  final int memberCount;
  final String role; // owner | admin | member
  final int currentStreak;
  final int bestStreak;
  final int myTodayCount;
  final bool myTodayComplete;
  final bool eligible;
  final bool isRequiredToday; // false today for brand-new joiners
  final int requiredToday;
  final int completedToday;
  final bool groupDayComplete;
  final bool shielded; // group day completed by the weekly shield
  final bool shieldAvailable; // shield not yet used this week
  final bool isOwner;

  const GroupSummary({
    required this.groupId,
    required this.name,
    this.status = 'active',
    this.visibility = 'invite',
    this.timezone = 'Asia/Karachi',
    this.memberCount = 0,
    this.role = 'member',
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.myTodayCount = 0,
    this.myTodayComplete = false,
    this.eligible = false,
    bool? isRequiredToday,
    this.requiredToday = 0,
    this.completedToday = 0,
    this.groupDayComplete = false,
    this.shielded = false,
    this.shieldAvailable = false,
    this.isOwner = false,
  }) : isRequiredToday = isRequiredToday ?? eligible;

  bool get archived => status == 'archived';

  factory GroupSummary.fromJson(Map<String, dynamic> json) {
    final eligible = _b(json['myToday']?['eligible']);
    return GroupSummary(
      groupId: _s(json['groupId']),
      name: _s(json['name']),
      status: _s(json['status'], 'active'),
      visibility: _s(json['visibility'], 'invite'),
      timezone: _s(json['timezone'], 'Asia/Karachi'),
      memberCount: _i(json['memberCount']),
      role: _s(json['role'], 'member'),
      currentStreak: _i(json['currentStreak']),
      bestStreak: _i(json['bestStreak']),
      myTodayCount: _i(json['myToday']?['completedCount']),
      myTodayComplete: _b(json['myToday']?['isDayComplete']),
      eligible: eligible,
      isRequiredToday: _b(json['myToday']?['required'], eligible),
      requiredToday: _i(json['today']?['required']),
      completedToday: _i(json['today']?['completed']),
      groupDayComplete: _b(json['today']?['isGroupDayComplete']),
      shielded: _b(json['today']?['shielded']),
      shieldAvailable: _b(json['shieldAvailable']),
      isOwner: _b(json['isOwner']),
    );
  }
}

class MemberProgress {
  final String userId;
  final String displayName;
  final String role;
  final bool eligible;
  final bool isRequiredToday; // false = brand-new joiner (counts, blocks from tomorrow)
  final bool excludedInactive; // true = 3-day ghost, not blocking the group day
  final int completedCount;
  final bool isDayComplete;
  final bool isMe;
  final bool fajr;
  final bool dhuhr;
  final bool asr;
  final bool maghrib;
  final bool isha;

  const MemberProgress({
    required this.userId,
    required this.displayName,
    this.role = 'member',
    this.eligible = false,
    bool? isRequiredToday,
    this.excludedInactive = false,
    this.completedCount = 0,
    this.isDayComplete = false,
    this.isMe = false,
    this.fajr = false,
    this.dhuhr = false,
    this.asr = false,
    this.maghrib = false,
    this.isha = false,
  }) : isRequiredToday = isRequiredToday ?? eligible;

  bool prayerDone(String prayer) => switch (prayer) {
        'fajr' => fajr,
        'dhuhr' => dhuhr,
        'asr' => asr,
        'maghrib' => maghrib,
        'isha' => isha,
        _ => false,
      };

  factory MemberProgress.fromJson(Map<String, dynamic> json) {
    final eligible = _b(json['eligible']);
    return MemberProgress(
      userId: _s(json['userId']),
      displayName: _s(json['displayName'], '?'),
      role: _s(json['role'], 'member'),
      eligible: eligible,
      isRequiredToday: _b(json['required'], eligible),
      excludedInactive: _b(json['excludedInactive']),
      completedCount: _i(json['completedCount']),
      isDayComplete: _b(json['isDayComplete']),
      isMe: _b(json['isMe']),
      fajr: _b(json['fajr']),
      dhuhr: _b(json['dhuhr']),
      asr: _b(json['asr']),
      maghrib: _b(json['maghrib']),
      isha: _b(json['isha']),
    );
  }
}

class ActivityItem {
  final String id;
  final String groupId;
  final String groupName; // only in notification feed
  final String userId;
  final String displayName;
  final String type; // prayer_completed | group_day_completed | member_* | ...
  final String? prayer;
  final DateTime createdAt;

  const ActivityItem({
    required this.id,
    required this.groupId,
    this.groupName = '',
    required this.userId,
    required this.displayName,
    required this.type,
    this.prayer,
    required this.createdAt,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) => ActivityItem(
        id: _s(json['_id'] ?? json['id']),
        groupId: _s(json['groupId']),
        groupName: _s(json['groupName']),
        userId: _s(json['userId']),
        displayName: _s(json['displayName'], 'Someone'),
        type: _s(json['type']),
        prayer: json['prayer']?.toString(),
        createdAt: _date(json['createdAt']) ?? DateTime.now(),
      );
}

class GroupDetail {
  final String groupId;
  final String name;
  final String status;
  final String visibility;
  final String timezone;
  final int memberCount;
  final String? inviteCode;
  final int currentStreak;
  final int bestStreak;
  final String? currentStreakStartDate;
  final bool isOwner;
  final String myRole; // owner | admin | member | none (left)
  final String dateKey;

  const GroupDetail({
    required this.groupId,
    required this.name,
    this.status = 'active',
    this.visibility = 'invite',
    this.timezone = 'Asia/Karachi',
    this.memberCount = 0,
    this.inviteCode,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.currentStreakStartDate,
    this.isOwner = false,
    this.myRole = 'member',
    this.dateKey = '',
  });

  factory GroupDetail.fromJson(Map<String, dynamic> json) => GroupDetail(
        groupId: _s(json['groupId']),
        name: _s(json['name']),
        status: _s(json['status'], 'active'),
        visibility: _s(json['visibility'], 'invite'),
        timezone: _s(json['timezone'], 'Asia/Karachi'),
        memberCount: _i(json['memberCount']),
        inviteCode: json['inviteCode']?.toString(),
        currentStreak: _i(json['currentStreak']),
        bestStreak: _i(json['bestStreak']),
        currentStreakStartDate: json['currentStreakStartDate']?.toString(),
        isOwner: _b(json['isOwner']),
        myRole: _s(json['myRole'], 'member'),
        dateKey: _s(json['dateKey']),
      );
}

class GroupDashboardData {
  final GroupDetail group;
  final List<MemberProgress> members;
  final int needed;
  final int completed;
  final bool isGroupDayComplete;
  final bool shielded; // today's summary was completed by the weekly shield
  final bool shieldAvailable; // shield not yet used this week
  final List<ActivityItem> activity;

  const GroupDashboardData({
    required this.group,
    required this.members,
    this.needed = 0,
    this.completed = 0,
    this.isGroupDayComplete = false,
    this.shielded = false,
    this.shieldAvailable = false,
    this.activity = const [],
  });

  factory GroupDashboardData.fromJson(Map<String, dynamic> json) => GroupDashboardData(
        group: GroupDetail.fromJson(json['group'] as Map<String, dynamic>? ?? {}),
        members: (json['members'] as List? ?? [])
            .map((e) => MemberProgress.fromJson(e as Map<String, dynamic>))
            .toList(),
        needed: _i(json['today']?['required']),
        completed: _i(json['today']?['completed']),
        isGroupDayComplete: _b(json['today']?['isGroupDayComplete']),
        shielded: _b(json['today']?['shielded']),
        shieldAvailable: _b(json['shieldAvailable']),
        activity: (json['activity'] as List? ?? [])
            .map((e) => ActivityItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class InvitePreview {
  final String groupId;
  final String name;
  final int currentStreak;
  final int memberCount;
  final int maxMembers;
  final String visibility;
  final String timezone;
  final String ownerName;
  final String inviteCode;
  final String viewerState; // member | pending | declined | none

  const InvitePreview({
    required this.groupId,
    required this.name,
    this.currentStreak = 0,
    this.memberCount = 0,
    this.maxMembers = 50,
    this.visibility = 'invite',
    this.timezone = 'Asia/Karachi',
    this.ownerName = 'Someone',
    this.inviteCode = '',
    this.viewerState = 'none',
  });

  factory InvitePreview.fromJson(Map<String, dynamic> json) => InvitePreview(
        groupId: _s(json['group']?['groupId']),
        name: _s(json['group']?['name'], 'Group'),
        currentStreak: _i(json['group']?['currentStreak']),
        memberCount: _i(json['group']?['memberCount']),
        maxMembers: _i(json['group']?['maxMembers'], 50),
        visibility: _s(json['group']?['visibility'], 'invite'),
        timezone: _s(json['group']?['timezone'], 'Asia/Karachi'),
        ownerName: _s(json['group']?['ownerName'], 'Someone'),
        inviteCode: _s(json['inviteCode']),
        viewerState: _s(json['viewerState'], 'none'),
      );
}

class DiscoverGroup {
  final String groupId;
  final String name;
  final int memberCount;
  final int currentStreak;
  final String ownerName;
  final bool isMember;

  const DiscoverGroup({
    required this.groupId,
    required this.name,
    this.memberCount = 0,
    this.currentStreak = 0,
    this.ownerName = 'Someone',
    this.isMember = false,
  });

  factory DiscoverGroup.fromJson(Map<String, dynamic> json) => DiscoverGroup(
        groupId: _s(json['groupId']),
        name: _s(json['name'], 'Group'),
        memberCount: _i(json['memberCount']),
        currentStreak: _i(json['currentStreak']),
        ownerName: _s(json['ownerName'], 'Someone'),
        isMember: _b(json['isMember']),
      );
}

class JoinRequestItem {
  final String id;
  final String groupId;
  final String groupName;
  final String userId; // only in owner lists
  final String displayName;
  final String status;
  final DateTime createdAt;

  const JoinRequestItem({
    required this.id,
    required this.groupId,
    this.groupName = '',
    this.userId = '',
    this.displayName = '',
    this.status = 'pending',
    required this.createdAt,
  });

  factory JoinRequestItem.fromJson(Map<String, dynamic> json) => JoinRequestItem(
        id: _s(json['_id'] ?? json['id']),
        groupId: _s(json['groupId']),
        groupName: _s(json['groupName']),
        userId: _s(json['userId']),
        displayName: _s(json['displayName']),
        status: _s(json['status'], 'pending'),
        createdAt: _date(json['createdAt']) ?? DateTime.now(),
      );
}

class NotificationItem extends ActivityItem {
  final String notifGroupName;
  const NotificationItem({
    required super.id,
    required super.groupId,
    required this.notifGroupName,
    required super.userId,
    required super.displayName,
    required super.type,
    super.prayer,
    required super.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
        id: _s(json['_id'] ?? json['id']),
        groupId: _s(json['groupId']),
        notifGroupName: _s(json['groupName']),
        userId: _s(json['userId']),
        displayName: _s(json['displayName'], 'Someone'),
        type: _s(json['type']),
        prayer: json['prayer']?.toString(),
        createdAt: _date(json['createdAt']) ?? DateTime.now(),
      );
}

// ---------- member detail ----------

class MemberDetailData {
  final String userId;
  final String displayName;
  final String role;
  final DateTime? joinedAt;
  final bool requiredToday; // part of today's group-day requirement
  final bool isMe;
  final DayProgress today;
  final int score; // = totalPrayers (each prayer = 1 point)
  final int totalPrayers;
  final int completeDays;
  final int currentStreak;
  final int bestStreak;
  final String? currentStreakStartDate;

  const MemberDetailData({
    required this.userId,
    required this.displayName,
    this.role = 'member',
    this.joinedAt,
    this.requiredToday = true,
    this.isMe = false,
    this.today = const DayProgress(),
    this.score = 0,
    this.totalPrayers = 0,
    this.completeDays = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.currentStreakStartDate,
  });

  factory MemberDetailData.fromJson(Map<String, dynamic> json) {
    final member = json['member'] as Map<String, dynamic>? ?? {};
    final today = json['today'] as Map<String, dynamic>? ?? {};
    final totals = json['totals'] as Map<String, dynamic>? ?? {};
    final totalPrayers = _i(totals['totalPrayers']);
    return MemberDetailData(
      userId: _s(member['userId']),
      displayName: _s(member['displayName'], '?'),
      role: _s(member['role'], 'member'),
      joinedAt: _date(member['joinedAt']),
      requiredToday: _b(member['requiredToday'], true),
      isMe: _b(member['isMe']),
      today: DayProgress.fromJson(today),
      score: _i(totals['score'], totalPrayers),
      totalPrayers: totalPrayers,
      completeDays: _i(totals['completeDays']),
      currentStreak: _i(totals['currentStreak']),
      bestStreak: _i(totals['bestStreak']),
      currentStreakStartDate: totals['currentStreakStartDate']?.toString(),
    );
  }
}
