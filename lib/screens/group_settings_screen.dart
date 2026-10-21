import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/streak_v2.dart';
import '../services/streak_v2_api.dart';
import '../services/api_client.dart';
import '../state/app_state.dart';
import '../state/streak_state.dart';
import '../theme/app_theme.dart';
import '../widgets/streak/streak_components.dart';

/// Group management: rename, invite code, join requests, members, leave,
/// archive, delete. Members reach it to leave; admin-only controls stay
/// disabled or hidden for them.
class GroupSettingsScreen extends StatefulWidget {
  final GroupDetail group;
  final int initialTab; // 0 = general, 1 = members & requests

  const GroupSettingsScreen({
    super.key,
    required this.group,
    this.initialTab = 0,
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  late int _tab;
  GroupDetail _group;
  List<JoinRequestItem> _requests = [];
  bool _requestsLoading = false;
  bool _busy = false;

  _GroupSettingsScreenState() : _group = GroupDetail(groupId: '', name: '');

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _tab = _isAdmin ? widget.initialTab.clamp(0, 1) : 0;
    if (_tab == 1) _loadRequests();
  }

  bool get _isOwner => _group.myRole == 'owner';
  bool get _isAdmin => _group.myRole == 'owner' || _group.myRole == 'admin';

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _err(AppState app, ApiException e) => e.isNetworkError
      ? app.t('No connection. Check your internet.', 'انٹرنیٹ نہیں چل رہا۔')
      : e.message;

  Future<void> _loadRequests() async {
    setState(() => _requestsLoading = true);
    try {
      final items = await StreakV2Api.instance.getGroupRequests(_group.groupId);
      if (!mounted) return;
      setState(() {
        _requests = items;
        _requestsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _requestsLoading = false);
    }
  }

  Future<void> _rename() async {
    final app = context.read<AppState>();
    final controller = TextEditingController(text: _group.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightCard,
        title: Text(app.t('Rename group', 'گروپ کا نام بدلیں')),
        content: TextField(
          controller: controller,
          maxLength: 60,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(app.t('Cancel', 'منسوخ')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(app.t('Save', 'محفوظ')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final name = controller.text.trim();
    if (name.isEmpty || name == _group.name) return;
    setState(() => _busy = true);
    try {
      await StreakV2Api.instance.renameGroup(_group.groupId, name);
      if (!mounted) return;
      setState(() {
        _group = GroupDetail(
          groupId: _group.groupId,
          name: name,
          status: _group.status,
          visibility: _group.visibility,
          timezone: _group.timezone,
          memberCount: _group.memberCount,
          inviteCode: _group.inviteCode,
          currentStreak: _group.currentStreak,
          bestStreak: _group.bestStreak,
          currentStreakStartDate: _group.currentStreakStartDate,
          isOwner: _group.isOwner,
          myRole: _group.myRole,
          dateKey: _group.dateKey,
        );
        _busy = false;
      });
      await context.read<StreakState>().groupsChanged();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(_err(app, e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.toString());
    }
  }

  Future<void> _rotateCode() async {
    final app = context.read<AppState>();
    final confirm = await _confirm(
      app,
      title: app.t('New invite code?', 'نیا کوڈ؟'),
      body: app.t(
        'The old code stops working. People you already invited need the new one.',
        'پرانا کوڈ بند ہو جائے گا۔ بلائے گئے لوگوں کو نیا کوڈ دیں۔',
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      final code = await StreakV2Api.instance.rotateInviteCode(_group.groupId);
      if (!mounted) return;
      setState(() {
        _group = GroupDetail(
          groupId: _group.groupId,
          name: _group.name,
          status: _group.status,
          visibility: _group.visibility,
          timezone: _group.timezone,
          memberCount: _group.memberCount,
          inviteCode: code,
          currentStreak: _group.currentStreak,
          bestStreak: _group.bestStreak,
          currentStreakStartDate: _group.currentStreakStartDate,
          isOwner: _group.isOwner,
          myRole: _group.myRole,
          dateKey: _group.dateKey,
        );
        _busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(_err(app, e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.toString());
    }
  }

  Future<void> _decideRequest(JoinRequestItem r, bool approve) async {
    final app = context.read<AppState>();
    setState(() => _busy = true);
    try {
      if (approve) {
        await StreakV2Api.instance.approveRequest(r.id);
      } else {
        await StreakV2Api.instance.declineRequest(r.id);
      }
      if (!mounted) return;
      setState(() => _busy = false);
      _loadRequests();
      await context.read<StreakState>().groupsChanged();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(_err(app, e));
      _loadRequests();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.toString());
    }
  }

  Future<void> _leave() async {
    final app = context.read<AppState>();
    final streakState = context.read<StreakState>();
    final confirm = await _confirm(
      app,
      title: app.t('Leave group?', 'گروپ چھوڑیں؟'),
      body: app.t(
        'Your past days stay in the group history. You can rejoin with an invite code.',
        'آپ کے گزرے دن گروپ کی تاریخ میں محفوظ رہیں گے۔ آپ کوڈ سے دوبارہ شامل ہو سکتے ہیں۔',
      ),
      danger: true,
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      final error = await streakState.leaveGroup(_group.groupId);
      if (!mounted) return;
      if (error == null) {
        Navigator.of(context).pop(); // settings
        Navigator.of(context).pop(); // dashboard
      } else {
        setState(() => _busy = false);
        _toast(
          error == 'network'
              ? app.t(
                  'No connection. Check your internet.',
                  'انٹرنیٹ نہیں چل رہا۔',
                )
              : error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.toString());
    }
  }

  Future<void> _archive() async {
    final app = context.read<AppState>();
    final streakState = context.read<StreakState>();
    final confirm = await _confirm(
      app,
      title: app.t('Archive group?', 'گروپ آرکائیو کریں؟'),
      body: app.t(
        'The group stops counting new days. History is preserved for everyone.',
        'گروپ اب نئے دن شمار نہیں کرے گا۔ تاریخ سب کے لیے محفوظ رہے گی۔',
      ),
      danger: true,
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      final error = await streakState.archiveGroup(_group.groupId);
      if (!mounted) return;
      if (error == null) {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      } else {
        setState(() => _busy = false);
        _toast(
          error == 'network'
              ? app.t(
                  'No connection. Check your internet.',
                  'انٹرنیٹ نہیں چل رہا۔',
                )
              : error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.toString());
    }
  }

  Future<void> _delete() async {
    final app = context.read<AppState>();
    final streakState = context.read<StreakState>();
    final confirm = await _confirm(
      app,
      title: app.t('Delete group permanently?', 'گروپ مستقل حذف کریں؟'),
      body: app.t(
        'This deletes all members, history and streak progress for everyone. This cannot be undone.',
        'یہ تمام ارکان، تاریخ اور اسٹریک کی پیش رفت سب کے لیے مستقل حذف کر دے گا۔ یہ واپس نہیں ہو سکتا۔',
      ),
      danger: true,
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      final error = await streakState.deleteGroup(_group.groupId);
      if (!mounted) return;
      if (error == null) {
        Navigator.of(context).pop();
        Navigator.of(context).pop();
      } else {
        setState(() => _busy = false);
        _toast(
          error == 'network'
              ? app.t(
                  'No connection. Check your internet.',
                  'انٹرنیٹ نہیں چل رہا۔',
                )
              : error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(e.toString());
    }
  }

  Future<bool?> _confirm(
    AppState app, {
    required String title,
    required String body,
    bool danger = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightCard,
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        content: Text(
          body,
          style: TextStyle(
            height: 1.4,
            color: isDark ? AppColors.darkMuted : AppColors.lightSecondaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(app.t('Cancel', 'منسوخ')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: danger ? AppColors.danger : AppColors.primary,
            ),
            child: Text(app.t('Confirm', 'تصدیق')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
        title: Text(
          app.t('Group settings', 'گروپ کی ترتیبات'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(app.t('General', 'عمومی'))),
                if (_isAdmin)
                  ButtonSegment(
                    value: 1,
                    label: Text(app.t('Members', 'ارکان')),
                  ),
              ],
              selected: {_tab},
              onSelectionChanged: (s) {
                setState(() => _tab = s.first);
                if (_tab == 1) _loadRequests();
              },
              style: SegmentedButton.styleFrom(
                foregroundColor: isDark
                    ? AppColors.darkMuted
                    : AppColors.lightSecondaryText,
                selectedForegroundColor: Colors.white,
                selectedBackgroundColor: AppColors.primary,
              ),
            ),
          ),
          Expanded(
            child: _tab == 0
                ? _generalTab(app, isDark)
                : _membersTab(app, isDark),
          ),
        ],
      ),
    );
  }

  Widget _generalTab(AppState app, bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        if (_isAdmin) ...[
          _ActionTile2(
            dark: isDark,
            icon: Icons.edit_outlined,
            label: app.t('Rename group', 'گروپ کا نام بدلیں'),
            onTap: _rename,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
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
                          color: dark(isDark),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _group.inviteCode ?? '—',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                          color: AppColors.primaryDeep,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : _rotateCode,
                  child: Text(app.t('New code', 'نیا کوڈ')),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (!_isOwner)
          _ActionTile2(
            dark: isDark,
            icon: Icons.logout_rounded,
            label: app.t('Leave group', 'گروپ چھوڑیں'),
            color: AppColors.danger,
            onTap: _busy ? null : _leave,
          ),
        if (_isOwner) ...[
          _ActionTile2(
            dark: isDark,
            icon: Icons.archive_outlined,
            label: app.t('Archive group', 'گروپ آرکائیو کریں'),
            color: AppColors.danger,
            onTap: _busy ? null : _archive,
          ),
          const SizedBox(height: 10),
          _ActionTile2(
            dark: isDark,
            icon: Icons.delete_forever_rounded,
            label: app.t('Delete group', 'گروپ حذف کریں'),
            color: AppColors.danger,
            onTap: _busy ? null : _delete,
          ),
        ],
      ],
    );
  }

  Color dark(bool isDark) =>
      isDark ? AppColors.darkMuted : AppColors.lightSecondaryText;

  Widget _membersTab(AppState app, bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        if (_isOwner && _group.visibility == 'public') ...[
          StreakSectionHeader(
            title: app.t('Join requests', 'شمولیت کی درخواستیں'),
          ),
          if (_requestsLoading)
            const LoadingList()
          else if (_requests.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkSurfaceAlt
                      : AppColors.lightBorder,
                ),
              ),
              child: Text(
                app.t('No pending requests.', 'کوئی زیرِ التوا درخواست نہیں۔'),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.darkMuted
                      : AppColors.lightSecondaryText,
                ),
              ),
            )
          else
            ..._requests.map(
              (r) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkSurfaceAlt
                        : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        r.displayName.isNotEmpty
                            ? r.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDeep,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        r.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkText
                              : AppColors.lightText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: _busy ? null : () => _decideRequest(r, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: Text(
                          app.t('Approve', 'منظور'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      height: 32,
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _decideRequest(r, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                        child: Text(
                          app.t('No', 'نہیں'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
        ],
        StreakSectionHeader(title: app.t('Manage members', 'ارکان کا انتظام')),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder,
            ),
          ),
          child: Text(
            app.t(
              'Open the group and long-press a member to make them owner or remove them.',
              'گروپ کھولیں اور کسی رکن پر لمبا دبائیں تاکہ اسے مالک بنایا یا ہٹایا جا سکے۔',
            ),
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: isDark
                  ? AppColors.darkMuted
                  : AppColors.lightSecondaryText,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionTile2 extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const _ActionTile2({
    required this.dark,
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? (dark ? AppColors.darkText : AppColors.lightText);
    return Material(
      color: dark ? AppColors.darkSurface : AppColors.lightCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: dark ? AppColors.darkSurfaceAlt : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 21, color: c),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: c,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: dark ? AppColors.darkMuted : AppColors.lightMutedText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
