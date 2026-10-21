import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/badges.dart';
import '../models/streak_v2.dart';
import '../services/auth_service.dart';
import '../services/sajda_stats_service.dart';
import '../services/streak_v2_api.dart';
import '../state/app_state.dart';
import '../state/streak_state.dart';
import '../theme/app_theme.dart';
import '../utils/share_image.dart';
import 'wrapped_screen.dart';

/// F4 — badge collection + prayer heatmap.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  bool _backfilling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _backfill());
  }

  Future<void> _backfill() async {
    if (!AuthService.instance.isAuthenticated || _backfilling) return;
    setState(() => _backfilling = true);
    final stats = context.read<SajdaStatsService>();
    await stats.load();
    final now = DateTime.now();
    try {
      for (var i = 0; i < 3; i++) {
        final month = DateTime(now.year, now.month - i);
        final HistoryData history = await StreakV2Api.instance
            .getSoloHistory(year: month.year, month: month.month);
        await stats.mergeHistory(history);
      }
    } catch (_) {
      // Offline — local stats still render.
    } finally {
      if (mounted) setState(() => _backfilling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final stats = context.watch<SajdaStatsService>();
    final streak = context.watch<StreakState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final snapshot = stats.snapshot(
      currentStreak: streak.solo?.currentStreak ?? 0,
      bestStreak: streak.solo?.bestStreak ?? 0,
    );
    final unlocked = unlockedBadgeCount(snapshot);
    final next = nextLockedBadge(snapshot);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(app.t('Achievements', 'کامیابیاں')),
        actions: [
          IconButton(
            tooltip: app.t('Sajda Wrapped', 'سجدة رپورٹ'),
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WrappedScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _backfill,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _HeroCard(
              app: app,
              stats: snapshot,
              unlocked: unlocked,
              total: sajdaBadges.length,
              next: next,
            ),
            const SizedBox(height: 16),
            _StatsGrid(app: app, stats: snapshot, isDark: isDark),
            const SizedBox(height: 20),
            _SectionTitle(
              app: app,
              title: 'Prayer Heatmap',
              titleUr: 'نماز کا نقشہ',
              trailing: _backfilling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            const SizedBox(height: 10),
            _HeatmapCard(app: app, stats: stats, isDark: isDark),
            const SizedBox(height: 12),
            _PrayerBreakdown(app: app, stats: stats, isDark: isDark),
            const SizedBox(height: 20),
            _SectionTitle(
              app: app,
              title: 'Badges',
              titleUr: 'بیجز',
              trailing: Text(
                '$unlocked/${sajdaBadges.length}',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.86,
              ),
              itemCount: sajdaBadges.length,
              itemBuilder: (context, i) {
                final badge = sajdaBadges[i];
                return _BadgeTile(
                  app: app,
                  badge: badge,
                  unlocked: badge.isUnlocked(snapshot),
                  isDark: isDark,
                  onTap: () => _showBadge(context, badge, snapshot, app),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBadge(
    BuildContext context,
    SajdaBadge badge,
    SajdaStatsSnapshot snapshot,
    AppState app,
  ) {
    final unlocked = badge.isUnlocked(snapshot);
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: badge.color.withValues(alpha: 0.16),
              child: Icon(badge.icon, color: badge.color, size: 36),
            ),
            const SizedBox(height: 12),
            Text(
              app.t(badge.titleEn, badge.titleUr),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              app.t(badge.descriptionEn, badge.descriptionUr),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (unlocked)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  shareWidgetAsImage(
                    context: context,
                    widget: _BadgeShareCard(
                      badge: badge,
                      stats: snapshot,
                      isUrdu: app.isUrdu,
                    ),
                    fileName: 'sajda_badge_${badge.id}',
                    caption:
                        '${app.t(badge.titleEn, badge.titleUr)} — SAJDA\n'
                        'https://play.google.com/store/apps/details?id=com.sajda.dataplus',
                  );
                },
                icon: const Icon(Icons.ios_share_rounded, size: 18),
                label: Text(app.t('Share badge', 'بیج شیئر کریں')),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(app.t('Keep going to unlock', 'حاصل کرنے کے لیے جاری رکھیں')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final AppState app;
  final String title;
  final String titleUr;
  final Widget? trailing;

  const _SectionTitle({
    required this.app,
    required this.title,
    required this.titleUr,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            app.t(title, titleUr),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final AppState app;
  final SajdaStatsSnapshot stats;
  final int unlocked;
  final int total;
  final SajdaBadge? next;

  const _HeroCard({
    required this.app,
    required this.stats,
    required this.unlocked,
    required this.total,
    this.next,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppColors.primaryDeep, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  app.t('Your journey of prayer', 'نماز کا سفر'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  '$unlocked/$total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _heroStat(
                '${stats.currentStreak}',
                app.t('Day streak', 'روز کا سلسلہ'),
              ),
              _heroDivider(),
              _heroStat(
                '${stats.totalPrayers}',
                app.t('Prayers', 'نمازیں'),
              ),
              _heroDivider(),
              _heroStat(
                '${stats.bestStreak}',
                app.t('Best streak', 'بہترین سلسلہ'),
              ),
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(next!.icon, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      app.t(
                        'Next: ${next!.titleEn}',
                        'اگلا: ${next!.titleUr}',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heroStat(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroDivider() => Container(
        width: 1,
        height: 34,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: Colors.white.withValues(alpha: 0.18),
      );
}

class _StatsGrid extends StatelessWidget {
  final AppState app;
  final SajdaStatsSnapshot stats;
  final bool isDark;

  const _StatsGrid({
    required this.app,
    required this.stats,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.calendar_month_rounded, '${stats.activeDays}',
          app.t('Active days', 'فعال دن'), AppColors.primary),
      (Icons.verified_rounded, '${stats.completeDays}',
          app.t('Perfect days', 'مکمل دن'), const Color(0xFFD4A937)),
      (Icons.circle_rounded, '${stats.tasbeehSets}',
          app.t('Tasbeeh sets', 'تسبیح'), const Color(0xFF117A65)),
      (Icons.psychology_rounded, '${stats.quizCorrect}',
          app.t('Quiz correct', 'کوئز درست'), const Color(0xFF7D3C98)),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.95,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final (icon, value, label, color) = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeatmapCard extends StatelessWidget {
  final AppState app;
  final SajdaStatsService stats;
  final bool isDark;

  const _HeatmapCard({
    required this.app,
    required this.stats,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final start = todayDate
        .subtract(Duration(days: (today.weekday - 1) + 16 * 7));
    const weeks = 17;
    const cell = 14.0;
    const gap = 3.0;
    final empty = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.055);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(weeks, (w) {
                return Padding(
                  padding: EdgeInsets.only(right: w == weeks - 1 ? 0 : gap),
                  child: Column(
                    children: List.generate(7, (d) {
                      final date = start.add(Duration(days: w * 7 + d));
                      final future = date.isAfter(todayDate);
                      final count = stats.countOn(date);
                      final alpha = count <= 0
                          ? 0.0
                          : (0.22 + count.clamp(0, 5) * 0.156);
                      return Padding(
                        padding: EdgeInsets.only(bottom: d == 6 ? 0 : gap),
                        child: Container(
                          width: cell,
                          height: cell,
                          decoration: BoxDecoration(
                            color: future
                                ? Colors.transparent
                                : count > 0
                                    ? AppColors.primary
                                        .withValues(alpha: alpha)
                                    : empty,
                            borderRadius: BorderRadius.circular(4),
                            border: future
                                ? Border.all(
                                    color: empty,
                                    width: 1,
                                  )
                                : null,
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                app.t('Last 17 weeks', 'پچھلے 17 ہفتے'),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                app.t('Less', 'کم'),
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              ...List.generate(5, (i) {
                final alpha = 0.22 + (i + 1) * 0.156;
                return Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: alpha),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
              Text(
                app.t('More', 'زیادہ'),
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrayerBreakdown extends StatelessWidget {
  final AppState app;
  final SajdaStatsService stats;
  final bool isDark;

  const _PrayerBreakdown({
    required this.app,
    required this.stats,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final counts = stats.prayerCounts;
    final rows = [
      ('fajr', app.t('Fajr', 'فجر'), Icons.wb_twilight_rounded),
      ('dhuhr', app.t('Dhuhr', 'ظہر'), Icons.wb_sunny_rounded),
      ('asr', app.t('Asr', 'عصر'), Icons.sunny_snowing),
      ('maghrib', app.t('Maghrib', 'مغرب'), Icons.wb_twilight_rounded),
      ('isha', app.t('Isha', 'عشاء'), Icons.nights_stay_rounded),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 30,
                color: isDark
                    ? AppColors.darkSurfaceAlt
                    : AppColors.lightBorder,
              ),
            Expanded(
              child: Column(
                children: [
                  Icon(
                    rows[i].$3,
                    size: 17,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${counts[rows[i].$1] ?? 0}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rows[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final AppState app;
  final SajdaBadge badge;
  final bool unlocked;
  final bool isDark;
  final VoidCallback onTap;

  const _BadgeTile({
    required this.app,
    required this.badge,
    required this.unlocked,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = unlocked
        ? badge.color
        : (isDark ? Colors.white24 : Colors.black26);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: unlocked ? 1 : 0.55,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: unlocked
                  ? badge.color.withValues(alpha: 0.35)
                  : (isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.14),
                    ),
                    child: Icon(badge.icon, color: color, size: 24),
                  ),
                  if (!unlocked)
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? AppColors.darkBackground
                              : AppColors.lightBackground,
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 11,
                          color: color,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                app.t(badge.titleEn, badge.titleUr),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeShareCard extends StatelessWidget {
  final SajdaBadge badge;
  final SajdaStatsSnapshot stats;
  final bool isUrdu;

  const _BadgeShareCard({
    required this.badge,
    required this.stats,
    required this.isUrdu,
  });

  @override
  Widget build(BuildContext context) {
    final arabicStyle = TextStyle(
      fontSize: 22,
      height: 1.8,
      color: Colors.white.withValues(alpha: 0.92),
    );
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            badge.color.withValues(alpha: 0.95),
            const Color(0xFF0B211A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.mosque_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text(
                'SAJDA',
                style: TextStyle(
                  letterSpacing: 3,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Container(
            width: 106,
            height: 106,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: Icon(badge.icon, color: Colors.white, size: 54),
          ),
          const SizedBox(height: 22),
          Text(
            'BADGE UNLOCKED',
            textAlign: TextAlign.center,
            style: TextStyle(
              letterSpacing: 2.5,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isUrdu ? badge.titleUr : badge.titleEn,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isUrdu ? badge.descriptionUr : badge.descriptionEn,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _stat('${stats.currentStreak}', isUrdu ? 'سلسلہ' : 'DAY STREAK'),
                _stat('${stats.totalPrayers}', isUrdu ? 'نمازیں' : 'PRAYERS'),
                _stat('${stats.completeDays}', isUrdu ? 'مکمل دن' : 'PERFECT DAYS'),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            isUrdu ? 'سجدة • روزانہ اذان اور قبلہ' : 'Sajda • Daily Athan & Qibla',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'play.google.com/store/apps/details?id=com.sajda.dataplus',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'وَمَا تَوْفِيقِي إِلَّا بِاللَّهِ',
            textAlign: TextAlign.center,
            style: arabicStyle.copyWith(fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 8,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
