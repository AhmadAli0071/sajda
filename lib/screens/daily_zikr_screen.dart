import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/daily_reminders.dart';
import '../services/daily_reminder_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// F11 — daily zikr/du'a of the day plus the upcoming rotation.
class DailyZikrScreen extends StatelessWidget {
  const DailyZikrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = reminderForDay(now, category: app.dailyReminderCategory);
    final upcoming = List.generate(6, (i) {
      return reminderForDay(
        now.add(Duration(days: i + 1)),
        category: app.dailyReminderCategory,
      );
    });

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(app.t('Zikr & Du\'a of the Day', 'آج کا ذکر اور دعا')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Row(
            children: [
              _CategoryChip(
                label: app.t('All', 'سب'),
                selected: app.dailyReminderCategory == 'all',
                onTap: () => _setCategory(app, 'all'),
              ),
              const SizedBox(width: 8),
              _CategoryChip(
                label: app.t('Zikr', 'ذکر'),
                selected: app.dailyReminderCategory == 'zikr',
                onTap: () => _setCategory(app, 'zikr'),
              ),
              const SizedBox(width: 8),
              _CategoryChip(
                label: app.t('Du\'a', 'دعا'),
                selected: app.dailyReminderCategory == 'dua',
                onTap: () => _setCategory(app, 'dua'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                colors: [Color(0xFF0B3D2E), Color(0xFF00695C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mosque_rounded,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      'SAJDA',
                      style: TextStyle(
                        letterSpacing: 2.6,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      today.kind == ReminderKind.zikr
                          ? app.t('DHIKR', 'ذکر')
                          : app.t('DU\'A', 'دعا'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 9,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  today.arabic,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: today.arabic.length > 80 ? 19 : 25,
                    height: 1.9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  today.transliteration,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFD4A937),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  app.isUrdu ? today.translationUr : today.translationEn,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  today.source,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              final text = app.t(
                '${today.arabic}\n\n${today.transliteration}\n\n${today.translationEn}\n\n— ${today.source}\n\nShared from the Sajda app\nhttps://play.google.com/store/apps/details?id=com.sajda.dataplus',
                '${today.arabic}\n\n${today.transliteration}\n\n${today.translationUr}\n\n— ${today.source}\n\nسجدة ایپ سے شیئر کیا گیا\nhttps://play.google.com/store/apps/details?id=com.sajda.dataplus',
              );
              SharePlus.instance.share(ShareParams(text: text));
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: Text(app.t('Share this reminder', 'یہ یاد دہانی شیئر کریں')),
          ),
          const SizedBox(height: 22),
          Text(
            app.t('Upcoming', 'آنے والے دن'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder,
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < upcoming.length; i++) ...[
                  _UpcomingRow(
                    app: app,
                    reminder: upcoming[i],
                    date: now.add(Duration(days: i + 1)),
                    isDark: isDark,
                    onTap: () => _showReminder(
                      context,
                      app,
                      upcoming[i],
                    ),
                  ),
                  if (i != upcoming.length - 1)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: isDark
                          ? AppColors.darkSurfaceAlt
                          : AppColors.lightBorder,
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_none_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    app.t(
                      'Daily reminders are opt-in. Turn them on or off in Settings → Notifications.',
                      'روزانہ یاد دہانی اختیاری ہے۔ ترتیبات → نوٹیفکیشنز میں آن یا آف کریں۔',
                    ),
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setCategory(AppState app, String category) async {
    await app.setDailyReminderCategory(category);
    if (app.dailyReminderEnabled) {
      await DailyReminderService.instance.scheduleNext7Days(
        timezone: app.locationTimezone,
        category: category,
        isUrdu: app.isUrdu,
      );
    }
  }

  void _showReminder(
    BuildContext context,
    AppState app,
    DailyReminder reminder,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              reminder.arabic,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, height: 1.9),
            ),
            const SizedBox(height: 12),
            Text(
              reminder.transliteration,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              app.isUrdu ? reminder.translationUr : reminder.translationEn,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              reminder.source,
              style: TextStyle(
                fontSize: 10.5,
                fontStyle: FontStyle.italic,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.14)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? AppColors.primaryDark : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  final AppState app;
  final DailyReminder reminder;
  final DateTime date;
  final bool isDark;
  final VoidCallback onTap;

  const _UpcomingRow({
    required this.app,
    required this.reminder,
    required this.date,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${date.day}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.isUrdu ? reminder.titleUr : reminder.titleEn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${weekdays[date.weekday - 1]} • '
                    '${reminder.kind == ReminderKind.zikr ? app.t('Zikr', 'ذکر') : app.t('Du\'a', 'دعا')}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
