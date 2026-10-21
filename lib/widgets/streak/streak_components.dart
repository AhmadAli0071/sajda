import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/static_data.dart';
import '../../models/streak_v2.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';

/// Shared, reusable building blocks for every v2 streak screen so the whole
/// system looks and behaves consistently.

/// Localized-data accessor for streak leaf widgets.
///
/// These widgets only consume `AppState.t()` / `isUrdu` (both derived from
/// `language`). A blanket `context.watch<AppState>()` rebuilt them on EVERY
/// AppState tick — streak refreshes, quran position saves, auth changes.
/// This extension subscribes to the language ONLY, so unrelated state
/// notifications no longer rebuild streak UI.
extension StreakLocalization on BuildContext {
  AppState get watchLanguage {
    select((AppState s) => s.language);
    return read<AppState>();
  }
}

// ─────────────────────────────────────────────────────────────────────
// Hero — the big streak number
// ─────────────────────────────────────────────────────────────────────

class StreakHero extends StatelessWidget {
  final int count;
  final int best;
  final String? caption;
  final bool compact;

  const StreakHero({
    super.key,
    required this.count,
    this.best = 0,
    this.caption,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watchLanguage;
    final streakLabel = state.t('day streak', 'روز کا سلسلہ');
    final bestLabel = state.t('Best', 'بہترین');
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 24,
        vertical: compact ? 16 : 28,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.gradientTeal,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(compact ? 16 : 24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            color: Colors.white,
            size: compact ? 40 : 56,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: compact ? 34 : 48,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  caption ?? streakLabel,
                  style: TextStyle(
                    fontSize: compact ? 13 : 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          if (best > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '$best',
                    style: TextStyle(
                      fontSize: compact ? 16 : 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    bestLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.9),
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

// ─────────────────────────────────────────────────────────────────────
// Progress header — "Today · 3/5" + bar
// ─────────────────────────────────────────────────────────────────────

class TodayProgressHeader extends StatelessWidget {
  final int completed;
  final int needed;
  final bool dayComplete;

  const TodayProgressHeader({
    super.key,
    required this.completed,
    required this.needed,
    this.dayComplete = false,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watchLanguage;
    final today = state.t('Today', 'آج');
    final done = state.t('done', 'مکمل');
    final allDone = state.t(
      'All prayers complete — Alhamdulillah!',
      'سب نمازیں مکمل — الحمدللہ!',
    );
    final fraction = needed <= 0 ? 0.0 : (completed / needed).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              today,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: state.darkMode
                    ? AppColors.darkText
                    : AppColors.lightText,
              ),
            ),
            Text(
              dayComplete ? allDone : '$completed/$needed $done',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: dayComplete
                    ? AppColors.success
                    : state.darkMode
                    ? AppColors.darkMuted
                    : AppColors.lightSecondaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor: state.darkMode
                ? AppColors.darkSurfaceAlt
                : AppColors.lightDivider,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Prayer tick tile — the one canonical tap target
// ─────────────────────────────────────────────────────────────────────

class PrayerTickTile extends StatelessWidget {
  final String prayer; // fajr..isha
  final bool done;
  final bool inFlight;
  final ValueChanged<bool> onToggle;

  const PrayerTickTile({
    super.key,
    required this.prayer,
    required this.done,
    this.inFlight = false,
    required this.onToggle,
  });

  static const _labels = {
    'fajr': ('Fajr', 'فجر', Icons.bedtime_outlined),
    'dhuhr': ('Dhuhr', 'ظهر', Icons.wb_sunny_outlined),
    'asr': ('Asr', 'عصر', Icons.wb_cloudy_outlined),
    'maghrib': ('Maghrib', 'مغرب', Icons.nightlight_round),
    'isha': ('Isha', 'عشاء', Icons.dark_mode_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watchLanguage;
    final meta = _labels[prayer] ?? (prayer, prayer, Icons.circle_outlined);
    final isFridayDhuhr =
        prayer == 'dhuhr' && DateTime.now().weekday == DateTime.friday;
    final label = isFridayDhuhr
        ? state.t('Friday', 'جمعہ')
        : state.t(meta.$1, meta.$2);
    final dark = state.darkMode;
    return Material(
      color: done
          ? AppColors.primary.withValues(alpha: 0.12)
          : dark
          ? AppColors.darkSurfaceAlt
          : AppColors.lightCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: inFlight ? null : () => onToggle(!done),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                meta.$3,
                size: 22,
                color: done
                    ? AppColors.primary
                    : (dark ? AppColors.darkMuted : AppColors.lightMutedText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: dark ? AppColors.darkText : AppColors.lightText,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.primary,
                  ),
                ),
              ),
              if (inFlight)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              else
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: done
                          ? AppColors.primary
                          : (dark
                                ? AppColors.darkMuted
                                : AppColors.lightBorder),
                      width: 2,
                    ),
                  ),
                  child: done
                      ? const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Colors.white,
                        )
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Member row — group dashboard / member list
// ─────────────────────────────────────────────────────────────────────

class MemberProgressRow extends StatelessWidget {
  final MemberProgress member;
  final String? trailingLabel;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const MemberProgressRow({
    super.key,
    required this.member,
    this.trailingLabel,
    this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watchLanguage;
    final dark = state.darkMode;
    final you = state.t('You', 'آپ');
    final name = member.isMe
        ? '$you · ${member.displayName}'
        : member.displayName;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: member.isDayComplete
                  ? AppColors.primary
                  : (dark ? AppColors.darkSurfaceAlt : AppColors.primaryLight),
              child: Text(
                member.displayName.isNotEmpty
                    ? member.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: member.isDayComplete
                      ? Colors.white
                      : AppColors.primaryDeep,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: dark
                                ? AppColors.darkText
                                : AppColors.lightText,
                          ),
                        ),
                      ),
                      if (member.role == 'owner' || member.role == 'admin') ...[
                        const SizedBox(width: 6),
                        Icon(
                          member.role == 'owner'
                              ? Icons.workspace_premium_rounded
                              : Icons.shield_outlined,
                          size: 14,
                          color: AppColors.primary,
                        ),
                      ],
                      // Brand-new joiner: counts from today, becomes part of
                      // the group-day requirement from tomorrow.
                      if (!member.isRequiredToday &&
                          !member.excludedInactive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            state.t('from tomorrow', 'کل سے'),
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDeep,
                            ),
                          ),
                        ),
                      ],
                      // 3-day ghost: still listed, no longer blocking.
                      if (member.excludedInactive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.lightMutedText.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            state.t('inactive', 'غیر فعال'),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: dark
                                  ? AppColors.darkMuted
                                  : AppColors.lightSecondaryText,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  StreakDots(count: member.completedCount, small: true),
                ],
              ),
            ),
            if (trailingLabel != null)
              Text(
                trailingLabel!,
                style: TextStyle(
                  fontSize: 12,
                  color: dark
                      ? AppColors.darkMuted
                      : AppColors.lightSecondaryText,
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: dark ? AppColors.darkMuted : AppColors.lightMutedText,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Dots — 5 prayer completions
// ─────────────────────────────────────────────────────────────────────

class StreakDots extends StatelessWidget {
  final int count;
  final bool small;

  const StreakDots({super.key, required this.count, this.small = false});

  @override
  Widget build(BuildContext context) {
    final size = small ? 9.0 : 12.0;
    return Row(
      children: List.generate(5, (i) {
        final filled = i < count;
        return Container(
          width: size,
          height: size,
          margin: EdgeInsets.only(right: small ? 4 : 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppColors.primary : Colors.transparent,
            border: Border.all(
              color: filled ? AppColors.primary : AppColors.lightBorder,
              width: 1.4,
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Activity row
// ─────────────────────────────────────────────────────────────────────

class ActivityRow extends StatelessWidget {
  final ActivityItem item;
  final String groupName; // when shown in notifications feed

  const ActivityRow({super.key, required this.item, this.groupName = ''});

  @override
  Widget build(BuildContext context) {
    final state = context.watchLanguage;
    final dark = state.darkMode;
    final (icon, color, text) = _describe(state);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: dark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            relativeTime(item.createdAt, state.t),
            style: TextStyle(
              fontSize: 11.5,
              color: dark ? AppColors.darkMuted : AppColors.lightMutedText,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, String) _describe(AppState state) {
    final g = groupName.isNotEmpty ? groupName : '';
    switch (item.type) {
      case 'prayer_completed':
        final p = _prayerLabel(state, item.prayer ?? '');
        return (
          Icons.check_circle_outline_rounded,
          AppColors.primary,
          '${item.displayName} ${state.t('completed', 'نے مکمل کی')}$g · $p',
        );
      case 'group_day_completed':
        return (
          Icons.emoji_events_outlined,
          AppColors.success,
          '${state.t('Group day complete', 'گروپ کا دن مکمل')}$g 🎉 (${item.displayName})',
        );
      case 'member_joined':
        return (
          Icons.person_add_alt_1_rounded,
          AppColors.primaryDark,
          '${item.displayName} ${state.t('joined the group', 'گروپ میں شامل ہوا')}$g',
        );
      case 'member_left':
        return (
          Icons.logout_rounded,
          AppColors.lightMutedText,
          '${item.displayName} ${state.t('left the group', 'گروپ چھوڑ گیا')}$g',
        );
      case 'member_removed':
        return (
          Icons.person_remove_outlined,
          AppColors.danger,
          '${item.displayName} ${state.t('was removed', 'ہٹایا گیا')}$g',
        );
      case 'group_created':
        return (
          Icons.flag_outlined,
          AppColors.primaryDark,
          '${item.displayName} ${state.t('created the group', 'گروپ بنایا')}$g',
        );
      case 'group_renamed':
        return (
          Icons.edit_outlined,
          AppColors.lightMutedText,
          '${item.displayName} ${state.t('renamed the group', 'گروپ کا نام بدلا')}$g',
        );
      case 'ownership_transferred':
        return (
          Icons.swap_horiz_rounded,
          AppColors.pastelPurple,
          '${state.t('Ownership transferred to', 'ملکیت منتقل ہوئی')} ${item.displayName}$g',
        );
      case 'join_request_approved':
        return (
          Icons.how_to_reg_outlined,
          AppColors.success,
          '${item.displayName} ${state.t('was approved', 'منظور ہوا')}$g',
        );
      case 'join_request_declined':
        return (
          Icons.block_outlined,
          AppColors.danger,
          '${item.displayName} ${state.t('was declined', 'مسترد ہوا')}$g',
        );
      case 'group_shield_used':
        return (
          Icons.shield_rounded,
          AppColors.primary,
          '${state.t('Shield saved the group day', 'شیلڈ نے گروپ کا دن بچا لیا')}$g',
        );
      case 'group_archived':
        return (
          Icons.archive_outlined,
          AppColors.lightMutedText,
          '${state.t('Group archived', 'گروپ آرکائیو ہو گیا')}$g',
        );
      default:
        return (
          Icons.notifications_none_rounded,
          AppColors.lightMutedText,
          state.t('Group activity', 'گروپ کی سرگرمی'),
        );
    }
  }

  String _prayerLabel(AppState state, String prayer) {
    if (prayer == 'dhuhr' && DateTime.now().weekday == DateTime.friday) {
      return state.t('Friday', 'جمعہ');
    }
    final map = {
      'fajr': ('Fajr', 'فجر'),
      'dhuhr': ('Dhuhr', 'ظهر'),
      'asr': ('Asr', 'عصر'),
      'maghrib': ('Maghrib', 'مغرب'),
      'isha': ('Isha', 'عشاء'),
    };
    final m = map[prayer];
    return m == null ? prayer : state.t(m.$1, m.$2);
  }
}

String relativeTime(DateTime utc, String Function(String en, String ur) t) {
  final now = DateTime.now().toUtc();
  final d = now.difference(utc);
  if (d.inSeconds < 60) return t('now', 'ابھی');
  if (d.inMinutes < 60) return t('${d.inMinutes}m', '${d.inMinutes} منٹ');
  if (d.inHours < 24) return t('${d.inHours}h', '${d.inHours} گھنٹے');
  if (d.inDays < 7) return t('${d.inDays}d', '${d.inDays} دن');
  return t('${(d.inDays / 7).floor()}w', '${(d.inDays / 7).floor()} ہفتے');
}

// ─────────────────────────────────────────────────────────────────────
// Scaffolding cards
// ─────────────────────────────────────────────────────────────────────

class StreakSectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const StreakSectionHeader({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    final state = context.watchLanguage;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: state.darkMode ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watchLanguage;
    final dark = state.darkMode;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.lightCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: dark ? AppColors.darkSurfaceAlt : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 44,
            color: dark ? AppColors.darkMuted : AppColors.lightMutedText,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: dark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: dark ? AppColors.darkMuted : AppColors.lightSecondaryText,
            ),
          ),
          if (action case final actionWidget?) ...[
            const SizedBox(height: 16),
            actionWidget,
          ],
        ],
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorCard({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final state = context.watchLanguage;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 34,
            color: AppColors.danger,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: state.darkMode ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          if (onRetry case final retry?) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(state.t('Retry', 'دوبارہ کوشش')),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ],
      ),
    );
  }
}

class LoadingList extends StatefulWidget {
  const LoadingList({super.key});

  @override
  State<LoadingList> createState() => _LoadingListState();
}

class _LoadingListState extends State<LoadingList>
    with SingleTickerProviderStateMixin {
  late int _index;
  Timer? _timer;
  // ONE controller drives every animation (name breathing, glow pulse,
  // shimmer sweep) — cheap on battery, perfectly in sync.
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void initState() {
    super.initState();
    // A different name every time the loader mounts — then it walks the
    // list one name per second while the data loads.
    _index = math.Random().nextInt(allahNames.length);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % allahNames.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watchLanguage;
    final n = allahNames[_index];
    final meaning = app.isUrdu ? n.meaningUr : n.meaning;

    // Isolate the 4s breathing/pulse animation into its own paint layer so
    // it repaints alone instead of dragging the whole loader subtree.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final t = _anim.value;
          final wave = 0.5 + 0.5 * math.sin(t * 2 * math.pi); // 0..1..0
          final breath = 1 + 0.025 * math.sin(t * 2 * math.pi);
          return Container(
            // Full-bleed night sky — the loader IS the screen while data loads.
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF07231E), // deep emerald night
                  Color(0xFF0F1A3C), // indigo
                  Color(0xFF07080F), // near black
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // Sparse star specks — drawn once, never repaint.
                const Positioned.fill(
                  child: CustomPaint(painter: _StarField(seed: 7)),
                ),
                // Golden halo behind the name, softly breathing.
                Center(
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(
                            0xFFE2B857,
                          ).withValues(alpha: 0.16 + 0.10 * wave),
                          Color(0xFFE2B857).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 450),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.96,
                                end: 1,
                              ).animate(anim),
                              child: child,
                            ),
                          ),
                          child: Transform.scale(
                            key: ValueKey(_index),
                            scale: breath,
                            child: Column(
                              key: ValueKey('n$_index'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ShaderMask(
                                  shaderCallback: (b) => const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFFF9E9C0), // light gold
                                      Color(0xFFE2B857), // gold
                                      Color(0xFFB98A2F), // deep gold
                                    ],
                                  ).createShader(b),
                                  child: Text(
                                    n.arabic,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 44,
                                      height: 1.45,
                                      fontWeight: FontWeight.w700,
                                      shadows: [
                                        Shadow(
                                          color: const Color(
                                            0xFFE2B857,
                                          ).withValues(alpha: 0.35),
                                          blurRadius: 24,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFE2B857,
                                    ).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFE2B857,
                                      ).withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Text(
                                    n.en,
                                    style: const TextStyle(
                                      color: Color(0xFFF3DFA8),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  meaning,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 34),
                        // Slim shimmer bar — sweeps gently while the data loads.
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: Container(
                            height: 4,
                            width: 210,
                            color: Colors.white.withValues(alpha: 0.10),
                            child: Align(
                              alignment: Alignment(
                                (-1 + 2 * wave).toDouble(),
                                0,
                              ),
                              child: Container(
                                width: 84,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(99),
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(
                                        0xFFE2B857,
                                      ).withValues(alpha: 0.0),
                                      const Color(0xFFF3DFA8),
                                      const Color(
                                        0xFFE2B857,
                                      ).withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          app.t('Loading…', 'لوڈ ہو رہا ہے…'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 11,
                            letterSpacing: 2.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Faint star specks on the night background — positions are seeded so
/// they are stable across rebuilds, and the painter never repaints.
class _StarField extends CustomPainter {
  final int seed;
  const _StarField({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final paint = Paint()..color = Colors.white;
    for (var i = 0; i < 46; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 0.5 + rng.nextDouble() * 1.3;
      paint.color = Colors.white.withValues(
        alpha: 0.06 + rng.nextDouble() * 0.22,
      );
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarField oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────
// Group card — my groups list
// ─────────────────────────────────────────────────────────────────────

class GroupCard extends StatelessWidget {
  final GroupSummary group;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const GroupCard({
    super.key,
    required this.group,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watchLanguage;
    final dark = state.darkMode;
    final membersLabel = state.t('members', 'ارکان');
    final waiting = state.t('waiting for others', 'دوسروں کا انتظار');
    final doneLabel = state.t('day complete', 'دن مکمل');
    final youDone = state.t("you're done", 'آپ مکمل');
    final groupDone = group.groupDayComplete;
    final myDone = group.myTodayComplete;
    return Material(
      color: dark ? AppColors.darkSurface : AppColors.lightCard,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: groupDone
                  ? AppColors.success.withValues(alpha: 0.4)
                  : dark
                  ? AppColors.darkSurfaceAlt
                  : AppColors.lightBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.gradientTeal,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(
                  child: Text(
                    group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            group.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: dark
                                  ? AppColors.darkText
                                  : AppColors.lightText,
                            ),
                          ),
                        ),
                        if (group.isOwner) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.workspace_premium_rounded,
                            size: 15,
                            color: AppColors.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${group.memberCount} $membersLabel · 🔥 ${group.currentStreak}',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: dark
                            ? AppColors.darkMuted
                            : AppColors.lightSecondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: groupDone
                      ? AppColors.success.withValues(alpha: 0.12)
                      : myDone
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : (dark
                            ? AppColors.darkSurfaceAlt
                            : AppColors.primaryLight),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  groupDone
                      ? '✓ $doneLabel'
                      : myDone
                      ? '✓ $youDone'
                      : waiting,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: groupDone
                        ? AppColors.success
                        : myDone
                        ? AppColors.primaryDeep
                        : (dark
                              ? AppColors.darkMuted
                              : AppColors.lightSecondaryText),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
