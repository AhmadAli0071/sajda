import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/streak_v2.dart';
import '../services/streak_v2_api.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../state/streak_state.dart';
import '../theme/app_theme.dart';
import '../utils/streak_invite_text.dart';
import '../widgets/streak/group_prayer_circle.dart';
import '../widgets/streak/streak_components.dart';
import 'group_history_screen.dart';
import 'group_settings_screen.dart';
import 'member_detail_screen.dart';

/// Group home: hero, today progress, members, activity, invite code.
class GroupDashboardScreen extends StatefulWidget {
  final String groupId;
  final bool justCreated;

  const GroupDashboardScreen({super.key, required this.groupId, this.justCreated = false});

  @override
  State<GroupDashboardScreen> createState() => _GroupDashboardScreenState();
}

class _GroupDashboardScreenState extends State<GroupDashboardScreen> {
  GroupDashboardData? _data;
  bool _loading = true;
  String? _error;
  bool _activityLoadingMore = false;
  bool _hasMoreActivity = false;
  String? _activityCursor;
  final List<ActivityItem> _activity = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await StreakV2Api.instance.getGroupDashboard(widget.groupId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _activity
          ..clear()
          ..addAll(data.activity);
        _hasMoreActivity = data.activity.length >= 20;
        _activityCursor = data.activity.isNotEmpty ? data.activity.last.createdAt.toIso8601String() : null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.isNetworkError ? 'network' : (e.code == 'NOT_MEMBER' ? 'left' : e.message);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMoreActivity() async {
    if (_activityLoadingMore || !_hasMoreActivity || _activityCursor == null) return;
    setState(() => _activityLoadingMore = true);
    try {
      final page = await StreakV2Api.instance.getGroupActivity(
        widget.groupId,
        before: DateTime.parse(_activityCursor!),
      );
      if (!mounted) return;
      setState(() {
        _activity.addAll(page.items);
        _hasMoreActivity = page.hasMore;
        if (page.items.isNotEmpty) {
          _activityCursor = page.items.last.createdAt.toIso8601String();
        }
        _activityLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _activityLoadingMore = false);
    }
  }

  void _shareInvite(AppState app, GroupDetail group) {
    final inviter = (app.displayName != null && app.displayName!.isNotEmpty)
        ? app.displayName!
        : app.t('A friend', 'ایک دوست');
    final text = buildStreakInviteShareText(
      inviterName: inviter,
      groupName: group.name,
      inviteCode: group.inviteCode ?? '',
      currentStreak: group.currentStreak,
    );
    SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? AppColors.darkText : AppColors.lightText),
        title: Text(
          _data?.group.name ?? app.t('Group', 'گروپ'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        actions: [
          if (_data != null)
            IconButton(
              tooltip: app.t('History', 'تاریخ'),
              icon: const Icon(Icons.calendar_month_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => GroupHistoryScreen(group: _data!.group)),
              ),
            ),
          if (_data != null && (_data!.group.myRole == 'owner' || _data!.group.myRole == 'admin'))
            IconButton(
              tooltip: app.t('Settings', 'ترتیبات'),
              icon: const Icon(Icons.settings_outlined),
              onPressed: () async {
                final streakState = context.read<StreakState>();
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GroupSettingsScreen(group: _data!.group),
                  ),
                );
                if (!mounted) return;
                _load();
                streakState.groupsChanged();
              },
            ),
        ],
      ),
      body: _loading && _data == null
          ? const LoadingList()
          : _error != null
              ? ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_error == 'left')
                      EmptyStateCard(
                        icon: Icons.logout_rounded,
                        title: app.t('You\u2019re no longer in this group', 'آپ اب اس گروپ میں نہیں'),
                        subtitle: app.t('The group may have archived or you were removed.', 'گروپ آرکائیو ہو گیا یا آپ ہٹا دیے گئے۔'),
                      )
                    else
                      ErrorCard(
                        message: _error == 'network'
                            ? app.t('No connection. Check your internet.', 'انٹرنیٹ نہیں چل رہا۔')
                            : _error!,
                        onRetry: _load,
                      ),
                  ],
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _load,
                  child: _buildBody(app, isDark),
                ),
    );
  }

  Widget _buildBody(AppState app, bool isDark) {
    final d = _data!;
    final g = d.group;
    final me = d.members.where((m) => m.isMe).toList().cast<MemberProgress?>().firstOrNull ??
        MemberProgress(userId: '', displayName: '', role: g.myRole, eligible: true, completedCount: 0, isMe: true);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (widget.justCreated) ...[
          _JustCreatedBanner(
            dark: isDark,
            onShare: () => _shareInvite(app, g),
          ),
          const SizedBox(height: 14),
        ],
        StreakHero(
          count: g.currentStreak,
          best: g.bestStreak,
          compact: true,
          caption:
              '${app.t('day streak', 'دن کا سلسلہ')} · ${g.memberCount} ${app.t('members', 'ارکان')}',
        ),
        if (d.shielded || d.shieldAvailable) ...[
          const SizedBox(height: 10),
          _ShieldChip(savedToday: d.shielded, available: d.shieldAvailable),
        ],
        const SizedBox(height: 16),

        // Group Prayer Circle — avatars around today's progress hub.
        GroupPrayerCircle(
          members: d.members,
          completed: d.completed,
          needed: d.needed,
          dayComplete: d.isGroupDayComplete,
          shielded: d.shielded,
          shieldAvailable: d.shieldAvailable,
          onMemberTap: (m) => _showMemberSheet(app, isDark, m),
        ),
        const SizedBox(height: 16),

        // Today
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: d.isGroupDayComplete
                  ? AppColors.success.withValues(alpha: 0.4)
                  : isDark
                      ? AppColors.darkSurfaceAlt
                      : AppColors.lightBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TodayProgressHeader(
                completed: d.completed,
                needed: d.needed,
                dayComplete: d.isGroupDayComplete,
              ),
              if (!me.isRequiredToday) ...[
                const SizedBox(height: 12),
                Text(
                  app.t(
                    'Your prayers count from today — you join the group day requirement from tomorrow.',
                    'آپ کی نمازیں آج سے شمار ہوں گی — گروپ کے دن کے لیے کل سے شامل ہوں گے۔',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.darkMuted : AppColors.lightSecondaryText,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Invite code
        if (g.myRole == 'owner' || g.myRole == 'admin') ...[
          _InviteCodeCard(
            dark: isDark,
            code: g.inviteCode ?? '',
            streak: g.currentStreak,
            onShare: () => _shareInvite(app, g),
          ),
          const SizedBox(height: 20),
        ],

        // Members
        StreakSectionHeader(
          title: app.t('Members', 'ارکان'),
          action: g.myRole == 'owner' || g.myRole == 'admin'
              ? TextButton(
                  onPressed: () async {
                    final streakState = context.read<StreakState>();
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => GroupSettingsScreen(group: g, initialTab: 1)),
                    );
                    if (!mounted) return;
                    _load();
                    streakState.groupsChanged();
                  },
                  child: Text(app.t('Manage', 'انتظام')),
                )
              : null,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder),
          ),
          child: Column(
            children: d.members
                .map((m) => MemberProgressRow(
                      member: m,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MemberDetailScreen(groupId: widget.groupId, member: m),
                        ),
                      ),
                      onLongPress: g.myRole == 'owner' && !m.isMe
                          ? () => _showMemberActions(app, isDark, m)
                          : null,
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 20),

        // Activity
        StreakSectionHeader(title: app.t('Activity', 'سرگرمی')),
        if (_activity.isEmpty)
          EmptyStateCard(
            icon: Icons.notifications_none_rounded,
            title: app.t('No activity yet', 'ابھی کوئی سرگرمی نہیں'),
            subtitle: app.t('Group events will show up here.', 'گروپ کی خبریں یہاں آئیں گی۔'),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder),
            ),
            child: Column(
              children: [
                ..._activity.map((a) => ActivityRow(item: a)),
                if (_hasMoreActivity)
                  TextButton(
                    onPressed: _loadMoreActivity,
                    child: _activityLoadingMore
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(app.t('Load more', 'مزید')),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  void _showMemberActions(AppState app, bool isDark, MemberProgress m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Text(
              m.displayName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.workspace_premium_rounded, color: AppColors.primary),
              title: Text(app.t('Make owner', 'مالک بنائیں')),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _transfer(app, m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined, color: AppColors.danger),
              title: Text(app.t('Remove from group', 'گروپ سے نکالیں'),
                  style: const TextStyle(color: AppColors.danger)),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _remove(app, m);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _transfer(AppState app, MemberProgress m) async {
    try {
      await StreakV2Api.instance.transferOwnership(widget.groupId, m.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(app.t('Ownership transferred', 'ملکیت منتقل ہو گئی')),
      ));
      _load();
      context.read<StreakState>().groupsChanged();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.isNetworkError
            ? app.t('No connection. Check your internet.', 'انٹرنیٹ نہیں چل رہا۔')
            : e.message),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _remove(AppState app, MemberProgress m) async {
    try {
      await StreakV2Api.instance.removeMember(widget.groupId, m.userId);
      if (!mounted) return;
      _load();
      context.read<StreakState>().groupsChanged();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.isNetworkError
            ? app.t('No connection. Check your internet.', 'انٹرنیٹ نہیں چل رہا۔')
            : e.message),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  // ── Group Prayer Circle: member sheet with prayer status + nudge ──

  void _showMemberSheet(AppState app, bool isDark, MemberProgress m) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _MemberSheetBody(
        member: m,
        onNudge: () => _nudge(app, m),
        onOpenDetail: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MemberDetailScreen(groupId: widget.groupId, member: m),
            ),
          );
        },
      ),
    );
  }

  Future<void> _nudge(AppState app, MemberProgress m) async {
    try {
      await StreakV2Api.instance.nudgeMember(widget.groupId, m.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(app.t('Reminder sent', 'یاد دہانی بھیج دی گئی')),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'NUDGE_DUPLICATE'
          ? app.t('Already nudged — try another prayer or tomorrow', 'پہلے ہی یاد دہانی بھیجی — کل دوبارہ کوشش کریں')
          : e.code == 'NUDGE_LIMIT'
              ? app.t('They got enough reminders for today', 'آج کے لیے کافی یاد دہانیاں بھیج چکیں')
              : e.isNetworkError
                  ? app.t('No connection. Check your internet.', 'انٹرنیٹ نہیں چل رہا۔')
                  : e.message;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _JustCreatedBanner extends StatelessWidget {
  final bool dark;
  final VoidCallback onShare;

  const _JustCreatedBanner({required this.dark, required this.onShare});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.gradientTeal),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.celebration_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  app.t('Group created! Share the code to invite.', 'گروپ بن گیا! کوڈ شیئر کریں۔'),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share_rounded, size: 18),
              label: Text(app.t('Invite people', 'لوگوں کو بلائیں')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDeep,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteCodeCard extends StatelessWidget {
  final bool dark;
  final String code;
  final int streak;
  final VoidCallback onShare;

  const _InviteCodeCard({
    required this.dark,
    required this.code,
    required this.streak,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.t('Invite code', 'انوائٹ کوڈ'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: dark ? AppColors.darkMuted : AppColors.lightSecondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  code,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: app.t('Copy', 'کاپی'),
            onPressed: () {
              if (code.isEmpty) return;
              final inviter = (app.displayName != null && app.displayName!.isNotEmpty)
                  ? app.displayName!
                  : app.t('A friend', 'ایک دوست');
              final text = buildStreakInviteShareText(
                inviterName: inviter,
                groupName: '',
                inviteCode: code,
                currentStreak: streak,
              );
              SharePlus.instance.share(ShareParams(text: text));
            },
            icon: const Icon(Icons.copy_rounded, size: 20),
            color: dark ? AppColors.darkMuted : AppColors.lightSecondaryText,
          ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            onPressed: onShare,
            icon: const Icon(Icons.share_rounded, size: 17),
            label: Text(app.t('Share', 'شیئر')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Shield chip — weekly group shield indicator
// ─────────────────────────────────────────────────────────────────────

class _ShieldChip extends StatelessWidget {
  final bool savedToday;
  final bool available;

  const _ShieldChip({required this.savedToday, required this.available});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final label = savedToday
        ? app.t('Shield used — streak saved', 'شیلڈ استعمال — سلسلہ بچ گیا')
        : app.t('Shield ready this week', 'اس ہفتے شیلڈ تیار');
    return Row(
      children: [
        Icon(
          Icons.shield_rounded,
          size: 16,
          color: savedToday ? AppColors.primary : AppColors.primary.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDeep,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Member sheet — prayer status + nudge (Group Prayer Circle tap target)
// ─────────────────────────────────────────────────────────────────────

class _MemberSheetBody extends StatelessWidget {
  final MemberProgress member;
  final VoidCallback onNudge;
  final VoidCallback onOpenDetail;

  const _MemberSheetBody({
    required this.member,
    required this.onNudge,
    required this.onOpenDetail,
  });

  static const _prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final you = app.t('You', 'آپ');
    final name = member.isMe ? '$you · ${member.displayName}' : member.displayName;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              name,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            if (member.excludedInactive) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  app.t('Inactive — not blocking the group', 'غیر فعال — گروپ نہیں روک رہا'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Prayer status rows
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: _prayers.map((p) {
                  final done = member.prayerDone(p);
                  final label = switch (p) {
                    'fajr' => app.t('Fajr', 'فجر'),
                    'dhuhr' => app.t('Dhuhr', 'ظہر'),
                    'asr' => app.t('Asr', 'عصر'),
                    'maghrib' => app.t('Maghrib', 'مغرب'),
                    _ => app.t('Isha', 'عشاء'),
                  };
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkText : AppColors.lightText,
                            ),
                          ),
                        ),
                        Icon(
                          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 20,
                          color: done ? AppColors.success : AppColors.lightMutedText,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenDetail,
                    icon: const Icon(Icons.person_outline_rounded, size: 18),
                    label: Text(app.t('View profile', 'پروفائل دیکھیں')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppColors.darkText : AppColors.lightText,
                      side: BorderSide(color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (!member.isMe && !member.isDayComplete) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onNudge,
                      icon: const Icon(Icons.notifications_active_outlined, size: 18),
                      label: Text(app.t('Nudge', 'یاد دہانی')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
