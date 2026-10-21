import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/streak_v2.dart';
import '../services/streak_v2_api.dart';
import '../state/app_state.dart';
import '../services/api_client.dart';
import '../state/streak_state.dart';
import '../theme/app_theme.dart';
import '../widgets/streak/streak_components.dart';
import 'group_dashboard_screen.dart';
import 'join_with_code_screen.dart';

/// Shows a group before joining — reached from an invite code (typed or
/// deep link sajda://join/CODE). Viewer states: member | pending | declined | none.
class GroupPreviewScreen extends StatefulWidget {
  final String inviteCode;
  final InvitePreview? initialPreview;

  const GroupPreviewScreen({
    super.key,
    required this.inviteCode,
    this.initialPreview,
  });

  @override
  State<GroupPreviewScreen> createState() => _GroupPreviewScreenState();
}

class _GroupPreviewScreenState extends State<GroupPreviewScreen> {
  InvitePreview? _preview;
  bool _loading = true;
  bool _joining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPreview;
    if (initial == null) {
      _load();
    } else {
      _preview = initial;
      _loading = false;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await StreakV2Api.instance.getInvitePreview(widget.inviteCode);
      if (!mounted) return;
      setState(() {
        _preview = p;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.isNetworkError ? 'network' : (e.code == 'INVALID_INVITE' ? 'invalid' : e.message);
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

  Future<void> _join() async {
    final app = context.read<AppState>();
    setState(() => _joining = true);
    try {
      final result = await StreakV2Api.instance.joinByInviteCode(widget.inviteCode);
      if (!mounted) return;
      await context.read<StreakState>().groupsChanged();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => GroupDashboardScreen(groupId: result.groupId)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.isNetworkError
            ? app.t('No connection. Check your internet.', 'انٹرنیٹ نہیں چل رہا۔')
            : e.message),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _requestToJoin() async {
    final app = context.read<AppState>();
    final p = _preview!;
    setState(() => _joining = true);
    try {
      await StreakV2Api.instance.requestToJoin(p.groupId);
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(app.t('Request sent — the owner will review it.', 'درخواست بھیج دی گئی — مالک دیکھے گا۔')),
      ));
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.isNetworkError
            ? app.t('No connection. Check your internet.', 'انٹرنیٹ نہیں چل رہا۔')
            : e.message),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
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
      ),
      body: _loading
          ? const LoadingList()
          : _error != null
              ? ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_error == 'invalid')
                      EmptyStateCard(
                        icon: Icons.link_off_rounded,
                        title: app.t('Invite not found', 'انوائٹ نہیں ملی'),
                        subtitle: app.t(
                          'This invite code doesn\u2019t exist or the group was archived.',
                          'یہ کوڈ موجود نہیں یا گروپ آرکائیو ہو چکا ہے۔',
                        ),
                        action: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const JoinWithCodeScreen()),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(app.t('Enter a code', 'کوڈ درج کریں')),
                          ),
                        ),
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
              : _buildPreview(app, isDark),
    );
  }

  Widget _buildPreview(AppState app, bool isDark) {
    final p = _preview!;
    final streaksLabel = app.t('day streak', 'دن کا سلسلہ');
    final membersLabel = app.t('members', 'ارکان');
    final byLabel = app.t('by', 'بذریعہ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const SizedBox(height: 8),
        Container(
          width: 84,
          height: 84,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppColors.gradientTeal),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 20, offset: Offset(0, 8))],
          ),
          child: Text(
            p.name.isNotEmpty ? p.name[0].toUpperCase() : 'G',
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          p.name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$byLabel ${p.ownerName}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? AppColors.darkMuted : AppColors.lightSecondaryText,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _InfoChip(
                dark: isDark,
                icon: Icons.local_fire_department_rounded,
                value: '${p.currentStreak}',
                label: streaksLabel,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoChip(
                dark: isDark,
                icon: Icons.group_rounded,
                value: '${p.memberCount}',
                label: membersLabel,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InfoChip(
                dark: isDark,
                icon: p.visibility == 'public' ? Icons.public_rounded : Icons.lock_outline_rounded,
                value: p.visibility == 'public' ? app.t('Public', 'عوامی') : app.t('Invite', 'انوائٹ'),
                label: app.t('Type', 'قسم'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        _buildAction(app, isDark, p),
      ],
    );
  }

  Widget _buildAction(AppState app, bool isDark, InvitePreview p) {
    switch (p.viewerState) {
      case 'member':
        return Column(
          children: [
            Text(
              app.t('You\u2019re already in this group.', 'آپ پہلے سے اس گروپ میں ہیں۔'),
              style: TextStyle(fontSize: 13.5, color: isDark ? AppColors.darkMuted : AppColors.lightSecondaryText),
            ),
            const SizedBox(height: 12),
            _bigButton(
              label: app.t('Go to group', 'گروپ پر جائیں'),
              loading: false,
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => GroupDashboardScreen(groupId: p.groupId)),
              ),
            ),
          ],
        );
      case 'pending':
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: AppColors.primaryDeep),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      app.t(
                        'Your join request is waiting for the owner\u2019s approval.',
                        'آپ کی درخواست مالک کی منظوری کا انتظار کر رہی ہے۔',
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case 'declined':
        return Column(
          children: [
            Text(
              app.t('A previous request was declined.', 'پچھلی درخواست مسترد ہوئی تھی۔'),
              style: TextStyle(fontSize: 13.5, color: isDark ? AppColors.darkMuted : AppColors.lightSecondaryText),
            ),
            const SizedBox(height: 12),
            _bigButton(
              label: app.t('Request again', 'دوبارہ درخواست'),
              loading: _joining,
              onPressed: _requestToJoin,
            ),
          ],
        );
      default: // none
        return _bigButton(
          label: p.visibility == 'public'
              ? app.t('Request to join', 'شامل ہونے کی درخواست')
              : app.t('Join group', 'گروپ میں شامل ہوں'),
          loading: _joining,
          onPressed: p.visibility == 'public' ? _requestToJoin : _join,
        );
    }
  }

  Widget _bigButton({required String label, required bool loading, required VoidCallback onPressed}) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String value;
  final String label;

  const _InfoChip({
    required this.dark,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? AppColors.darkSurfaceAlt : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: dark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: dark ? AppColors.darkMuted : AppColors.lightMutedText),
          ),
        ],
      ),
    );
  }
}
