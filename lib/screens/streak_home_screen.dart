import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/firebase_auth_service.dart';
import '../state/app_state.dart';
import '../state/streak_state.dart';
import '../theme/app_theme.dart';
import '../widgets/streak/streak_components.dart';
import 'create_group_screen.dart';
import 'discover_groups_screen.dart';
import 'group_dashboard_screen.dart';
import 'join_with_code_screen.dart';
import 'my_groups_screen.dart';
import 'solo_dashboard_screen.dart';

/// The Streak tab: auth gate → Solo card + Friends & Family card.
class StreakHomeScreen extends StatefulWidget {
  const StreakHomeScreen({super.key});

  @override
  State<StreakHomeScreen> createState() => _StreakHomeScreenState();
}

class _StreakHomeScreenState extends State<StreakHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppState>();
      if (app.isAuthenticated) {
        context.read<StreakState>().initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Only the auth flag gates the child — don't rebuild on every
    // unrelated AppState tick.
    final authenticated = context.select<AppState, bool>((s) => s.isAuthenticated);
    final streak = context.watch<StreakState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Gate shows the one-tap Google sign-in when there is no session OR
    // the backend rejected our token (authFailed) — never a dead UI that
    // errors "Authentication required" on every tap.
    final signedIn = authenticated && !streak.authFailed;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: signedIn ? const _StreakHome() : const _GoogleAuthGate(),
      ),
    );
  }
}

// ─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€
// Auth gate — one-tap Google sign-in. Streak data lives on the server
// bound to a verified identity, so sign-in is required. The gate
// disappears automatically once AppState.isAuthenticated flips true.
// ─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€

class _GoogleAuthGate extends StatefulWidget {
  const _GoogleAuthGate();

  @override
  State<_GoogleAuthGate> createState() => _GoogleAuthGateState();
}

class _GoogleAuthGateState extends State<_GoogleAuthGate> {
  bool _loading = false;

  String _friendlyError(String error) {
    final state = context.read<AppState>();
    if (error == 'network') {
      return state.t('No connection. Try again.', '\u0627\u0650\u0646\u0679\u0631\u0646\u06cc\u0679 \u0646\u06c1\u06cc\u06ba\u06d4 \u062f\u0648\u0628\u0627\u0631\u06c1 \u06a9\u0648\u0634\u0634 \u06a9\u0631\u06cc\u06ba\u06d4');
    }
    if (error == 'timeout') {
      return state.t('Server is slow. Please try again.', '\u0633\u0631\u0648\u0631 \u0633\u0633\u062a \u06c1\u06d2\u06d4 \u062f\u0648\u0628\u0627\u0631\u06c1 \u06a9\u0648\u0634\u0634 \u06a9\u0631\u06cc\u06ba\u06d4');
    }
    if (error == 'server_response') {
      return state.t('Server error. Try again later.', '\u0633\u0631\u0648\u0631 \u0645\u06cc\u06ba \u062e\u0631\u0627\u0628\u06cc\u06d4 \u0628\u0639\u062f \u0645\u06cc\u06ba \u06a9\u0648\u0634\u0634 \u06a9\u0631\u06cc\u06ba\u06d4');
    }
    if (error == 'sign_in_config') {
      // DEVELOPER_ERROR: this build's signing key is not registered in
      // Firebase (e.g. Play Store installs before the Play signing SHA-1
      // was added). Honest label instead of a fake "no connection".
      return state.t(
          'Google sign-in is not available for this app version yet.',
          '\u06af\u0648\u06af\u0644 \u0633\u0627\u0626\u0646 \u0627\u0650\u0646 \u0627\u0633 \u0648\u0642\u062a \u062f\u0633\u062a\u06cc\u0627\u0628 \u0646\u06c1\u06cc\u06ba\u06d4 \u0686\u0646\u062f \u0645\u0646\u0679 \u0628\u0639\u062f \u06a9\u0648\u0634\u0634 \u06a9\u0631\u06cc\u06ba\u06d4');
    }
    if (error.startsWith('google_platform:') || error.startsWith('google_unknown:')) {
      return state.t('Sign-in failed. Please try again.', '\u062f\u0627\u062e\u0644\u06c1 \u0646\u0627\u06a9\u0627\u0645\u06d4 \u062f\u0648\u0628\u0627\u0631\u06c1 \u06a9\u0648\u0634\u0634 \u06a9\u0631\u06cc\u06ba\u06d4');
    }
    if (error.startsWith('[') || error.contains('channel-error') || error.contains('firebase_init')) {
      return state.t('Service unavailable. Try again later.', '\u0633\u0631\u0648\u0633 \u062f\u0633\u062a\u06cc\u0627\u0628 \u0646\u06c1\u06cc\u06ba\u06d4 \u0628\u0639\u062f \u0645\u06cc\u06ba \u06a9\u0648\u0634\u0634 \u06a9\u0631\u06cc\u06ba\u06d4');
    }
    if (error.contains('too-many-requests')) {
      return state.t('Too many attempts. Try again later.', '\u0628\u06c1\u062a \u0632\u06cc\u0627\u062f\u06c1 \u06a9\u0648\u0634\u0634\u06cc\u06ba\u06d4 \u0628\u0639\u062f \u0645\u06cc\u06ba \u06a9\u0648\u0634\u0634 \u06a9\u0631\u06cc\u06ba\u06d4');
    }
    if (error == 'google_no_id_token' || error == 'session_missing') {
      return state.t('Sign-in failed. Please try again.', '\u062f\u0627\u062e\u0644\u06c1 \u0646\u0627\u06a9\u0627\u0645\u06d4 \u062f\u0648\u0628\u0627\u0631\u06c1 \u06a9\u0648\u0634\u0634 \u06a9\u0631\u06cc\u06ba\u06d4');
    }
    return state.t('Sign-in failed: $error', '\u062f\u0627\u062e\u0644\u06c1 \u0646\u0627\u06a9\u0627\u0645: $error');
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    String? error = await FirebaseAuthService.instance.signInWithGoogle();
    if (error == null) {
      final token = await FirebaseAuthService.instance.idToken;
      if (token == null) {
        error = 'session_missing';
      } else {
        error = await AuthService.instance.exchangeFirebaseToken(
          idToken: token,
          displayName: FirebaseAuthService.instance.user?.displayName,
        );
      }
    }
    setState(() => _loading = false);
    if (!mounted) return;
    if (error == null) {
      context.read<AppState>().adoptFirebaseSession();
      context.read<StreakState>().initialize();
      return;
    }
    if (error == 'cancelled') return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_friendlyError(error))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.gradientTeal),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 28, offset: Offset(0, 12))],
              ),
              child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 52),
            ),
            const SizedBox(height: 30),
            Text(
              state.t('Never break the chain', 'سلسلہ کبھی مت توڑیں'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              state.t(
                'Login with Google and start your streak',
                'گوگل سے لاگ اِن کریں اور اپنا سلسلہ شروع کریں',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: isDark ? AppColors.darkMuted : AppColors.lightSecondaryText,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                  foregroundColor: isDark ? AppColors.darkText : AppColors.lightText,
                  side: BorderSide(color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: isDark ? 0 : 1,
                ),
                icon: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : const Icon(Icons.g_mobiledata_rounded, size: 30),
                label: Flexible(
                  child: Text(
                    state.t('Continue with Google', 'گوگل سے جاری رکھیں'),
                    style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€
// Main content
// ─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€

class _StreakHome extends StatelessWidget {
  const _StreakHome();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final streak = context.watch<StreakState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final refreshLabel = app.t('Refresh', 'ریفریش');

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await Future.wait([
          streak.refreshSolo(),
          streak.refreshGroups(),
          streak.refreshNotifications(),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  app.t('Streaks', 'اسٹریک'),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ),
              _BellButton(unread: streak.unreadCount),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () {
                  streak.refreshSolo();
                  streak.refreshGroups();
                },
                icon: Icon(Icons.refresh_rounded, color: isDark ? AppColors.darkMuted : AppColors.lightSecondaryText),
                tooltip: refreshLabel,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ─”€─”€ SOLO ─”€─”€
          _SoloCard(dark: isDark),
          const SizedBox(height: 24),

          // ─”€─”€ FRIENDS & FAMILY ─”€─”€
          StreakSectionHeader(
            title: app.t('Friends & Family', 'دوست اور گھر والے'),
            action: TextButton(
              onPressed: () => _push(context, const MyGroupsScreen()),
              child: Text(app.t('See all', 'سب دیکھیں')),
            ),
          ),
          _GroupsPreview(dark: isDark),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.group_add_rounded,
                  label: app.t('New group', 'نیا گروپ'),
                  onTap: () => _push(context, const CreateGroupScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon: Icons.vpn_key_rounded,
                  label: app.t('Join with code', 'کوڈ سے شامل ہوں'),
                  onTap: () => _push(context, const JoinWithCodeScreen()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon: Icons.search_rounded,
                  label: app.t('Discover', 'تلاش'),
                  onTap: () => _push(context, const DiscoverGroupsScreen()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.lightCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  final int unread;
  const _BellButton({required this.unread});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () => showNotificationsSheet(context),
          icon: Icon(
            Icons.notifications_none_rounded,
            size: 26,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
              child: Text(
                unread > 9 ? '9+' : '$unread',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _SoloCard extends StatelessWidget {
  final bool dark;
  const _SoloCard({required this.dark});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final streak = context.watch<StreakState>();
    final solo = streak.solo;
    final title = app.t('SOLO', 'اکیلے');

    final header = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: dark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const Spacer(),
          if (solo != null && solo.started)
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SoloDashboardScreen()),
              ),
              child: Row(
                children: [
                  Text(
                    app.t('Details', 'تفصیل'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primary),
                ],
              ),
            ),
        ],
      ),
    );

    // Loading
    if (streak.soloPhase == StreakLoadPhase.loading && solo == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header, const LoadingList()]);
    }

    // Error
    if (streak.soloPhase == StreakLoadPhase.error && solo == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          ErrorCard(
            message: streak.soloError == 'network'
                ? app.t('No connection. Check your internet.', 'انٹرنیٹ نہیں ہے۔ اپنا کنکشن چیک کریں۔')
                : (streak.soloError ?? ''),
            onRetry: () => streak.refreshSolo(),
          ),
        ],
      );
    }

    // Not started yet
    if (solo == null || !solo.started) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          EmptyStateCard(
            icon: Icons.local_fire_department_outlined,
            title: app.t('Start your solo streak', 'اپنا سلسلہ شروع کریں'),
            subtitle: app.t(
              'Tick five prayers a day. Your streak grows with every complete day.',
              'روزانہ پانچ نمازیں ٹک کریں۔ ہر مکمل دن کے ساتھ آپ کا سلسلہ بڑھتا جاتا ہے۔',
            ),
            action: SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final err = await context.read<StreakState>().startSolo();
                  if (err != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                  }
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(app.t('Start streak', 'سلسلہ شروع کریں')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Active solo — hero + ticks
    final today = solo.today;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SoloDashboardScreen()),
          ),
          child: StreakHero(
            count: solo.currentStreak,
            best: solo.bestStreak,
            compact: true,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: dark ? AppColors.darkSurface : AppColors.lightCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: dark ? AppColors.darkSurfaceAlt : AppColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TodayProgressHeader(
                completed: today.completedCount,
                needed: 5,
                dayComplete: today.isDayComplete,
              ),
              const SizedBox(height: 12),
              ...['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'].map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PrayerTickTile(
                    prayer: p,
                    done: today.of(p),
                    inFlight: streak.isPrayerInFlight(p),
                    onToggle: (done) async {
                      final err = await context.read<StreakState>().togglePrayer(p, done);
                      if (err != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_friendly(app, err))),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _friendly(AppState app, String err) {
    if (err == 'network') {
      return app.t('No connection. Check your internet.', 'انٹرنیٹ نہیں ہے۔ اپنا کنکشن چیک کریں۔');
    }
    return err;
  }
}

class _GroupsPreview extends StatelessWidget {
  final bool dark;
  const _GroupsPreview({required this.dark});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final streak = context.watch<StreakState>();
    final groups = streak.activeGroups.take(3).toList();

    if (streak.groupsPhase == StreakLoadPhase.loading && streak.groups.isEmpty) {
      return const LoadingList();
    }
    if (streak.groupsPhase == StreakLoadPhase.error && streak.groups.isEmpty) {
      return ErrorCard(
        message: streak.groupsError == 'network'
            ? app.t('No connection. Check your internet.', 'انٹرنیٹ نہیں ہے۔ اپنا کنکشن چیک کریں۔')
            : (streak.groupsError ?? ''),
        onRetry: () => streak.refreshGroups(),
      );
    }
    if (groups.isEmpty) {
      return EmptyStateCard(
        icon: Icons.family_restroom_rounded,
        title: app.t('No groups yet', 'ابھی کوئی گروپ نہیں ہے'),
        subtitle: app.t(
          'Create a group with family, or join friends with an invite code.',
          'گھر والوں کا گروپ بنائیں، یا اِنوائٹ کوڈ سے دوستوں میں شامل ہوں۔',
        ),
      );
    }
    return Column(
      children: [
        for (final g in groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GroupCard(
              group: g,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => GroupDashboardScreen(groupId: g.groupId)),
              ),
            ),
          ),
      ],
    );
  }
}

// ─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€
// Notifications sheet (in-app feed; own actions excluded server-side)
// ─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€─”€

void showNotificationsSheet(BuildContext context) {
  final streak = context.read<StreakState>();
  final app = context.read<AppState>();
  streak.markNotificationsSeen();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      return Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkMuted : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                app.t('Notifications', 'اطلاعات'),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ),
            Flexible(
              child: Consumer<StreakState>(
                builder: (_, st, _) {
                  final items = st.notifications;
                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: EmptyStateCard(
                        icon: Icons.notifications_none_rounded,
                        title: app.t('Nothing yet', 'ابھی کچھ نہیں ہے'),
                        subtitle: app.t(
                          'Group activity will appear here.',
                          'گروپ کی سرگرمی یہاں نظر آئے گی۔',
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightDivider,
                    ),
                    itemBuilder: (_, i) {
                      final n = items[i];
                      return InkWell(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          if (n.groupId.isNotEmpty) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GroupDashboardScreen(groupId: n.groupId),
                              ),
                            );
                          }
                        },
                        child: ActivityRow(item: n, groupName: ' · ${n.notifGroupName}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  ).then((_) => streak.refreshNotifications());
}
