import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../state/streak_state.dart';
import '../theme/app_theme.dart';
import '../utils/share_image.dart';
import '../utils/streak_share_text.dart';
import '../widgets/streak/streak_components.dart';
import '../widgets/streak/streak_share_card.dart';
import 'achievements_screen.dart';
import 'solo_history_screen.dart';

/// Full solo streak view: hero, today's ticks, stats, history link.
class SoloDashboardScreen extends StatelessWidget {
  const SoloDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final streak = context.watch<StreakState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final solo = streak.solo;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? AppColors.darkText : AppColors.lightText),
        title: Text(
          app.t('Solo Streak', 'اکیلے کا سلسلہ'),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        actions: [
          IconButton(
            tooltip: app.t('Achievements', 'کامیابیاں'),
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AchievementsScreen()),
            ),
          ),
          IconButton(
            tooltip: app.t('Share', 'شیئر کریں'),
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: solo == null || !solo.started
                ? null
                : () => shareWidgetAsImage(
                      context: context,
                      widget: StreakShareCard(
                        currentStreak: solo.currentStreak,
                        bestStreak: solo.bestStreak,
                        todayCount: solo.today.completedCount,
                        monthLabel: shareCardMonthLabel(),
                      ),
                      fileName: 'sajda_streak_card',
                      caption: buildStreakShareCaption(
                        currentStreak: solo.currentStreak,
                        bestStreak: solo.bestStreak,
                      ),
                    ),
          ),
          IconButton(
            tooltip: app.t('History', 'تاریخ'),
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SoloHistoryScreen()),
            ),
          ),
        ],
      ),
      body: solo == null || !solo.started
          ? Center(
              child: EmptyStateCard(
                icon: Icons.local_fire_department_outlined,
                title: app.t('No active streak', 'کوئی فعال سلسلہ نہیں'),
                subtitle: app.t('Start a streak from the Streaks tab.', 'اسٹریک ٹیب سے سلسلہ شروع کریں۔'),
              ),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => streak.refreshSolo(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  StreakHero(count: solo.currentStreak, best: solo.bestStreak),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TodayProgressHeader(
                          completed: solo.today.completedCount,
                          needed: 5,
                          dayComplete: solo.today.isDayComplete,
                        ),
                        const SizedBox(height: 12),
                        ...['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'].map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: PrayerTickTile(
                              prayer: p,
                              done: solo.today.of(p),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          dark: isDark,
                          icon: Icons.emoji_events_outlined,
                          label: app.t('Best streak', 'بہترین سلسلہ'),
                          value: '${solo.bestStreak}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          dark: isDark,
                          icon: Icons.flag_outlined,
                          label: app.t('Started', 'شروع ہوا'),
                          value: solo.currentStreakStartDate != null && solo.currentStreakStartDate!.length >= 8
                              ? '${solo.currentStreakStartDate!.substring(4, 6)}/${solo.currentStreakStartDate!.substring(6, 8)}'
                              : app.t('Today', 'آج'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SoloHistoryScreen()),
                      ),
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Text(app.t('View history', 'تاریخ دیکھیں')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _friendly(AppState app, String err) {
    if (err == 'network') return app.t('No connection. Check your internet.', 'انٹرنیٹ نہیں چل رہا۔');
    return err;
  }
}

class _StatCard extends StatelessWidget {
  final bool dark;
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({required this.dark, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? AppColors.darkSurfaceAlt : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: dark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.2,
                    color: dark ? AppColors.darkMuted : AppColors.lightSecondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
