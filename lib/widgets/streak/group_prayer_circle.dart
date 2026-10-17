import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/streak_v2.dart';
import '../../theme/app_theme.dart';
import 'streak_components.dart' show StreakLocalization;

/// Group Prayer Circle — members arranged around a center hub showing
/// today's group progress. Green ring + ✓ = 5/5, partial ring = x/5,
/// dimmed = excluded ghost. Tap an avatar → member sheet with prayer
/// status + nudge button.
class GroupPrayerCircle extends StatelessWidget {
  final List<MemberProgress> members;
  final int completed;
  final int needed;
  final bool dayComplete;
  final bool shielded; // today saved by the weekly shield
  final bool shieldAvailable; // shield not yet used this week
  final ValueChanged<MemberProgress>? onMemberTap;

  const GroupPrayerCircle({
    super.key,
    required this.members,
    required this.completed,
    required this.needed,
    this.dayComplete = false,
    this.shielded = false,
    this.shieldAvailable = false,
    this.onMemberTap,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watchLanguage;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shown = members.take(8).toList();
    final extra = members.length - shown.length;

    return RepaintBoundary(
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = math.min(constraints.maxWidth, constraints.maxHeight);
                final radius = size / 2 - 28;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    _CenterHub(
                      completed: completed,
                      needed: needed,
                      dayComplete: dayComplete,
                      shielded: shielded,
                      shieldAvailable: shieldAvailable,
                    ),
                    for (var i = 0; i < shown.length; i++)
                      _positionedAvatar(
                        angle: (i / shown.length) * 2 * math.pi - math.pi / 2,
                        radius: radius,
                        member: shown[i],
                      ),
                    if (extra > 0)
                      _positionedAvatar(
                        angle: (shown.length / (shown.length + 1)) * 2 * math.pi - math.pi / 2,
                        radius: radius,
                        member: MemberProgress(
                          userId: '',
                          displayName: '+$extra',
                          completedCount: 0,
                        ),
                        isExtra: true,
                      ),
                  ],
                );
              },
            ),
          ),
          if (shieldAvailable && !dayComplete) ...[
            const SizedBox(height: 4),
            Text(
              state.t(
                'Shield ready — one save left this week',
                'شیلڈ تیار — اس ہفتے ایک بچت باقی',
              ),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkMuted : AppColors.lightSecondaryText,
              ),
            ),
          ],
          ],
      ),
    ),
    );
  }

  Widget _positionedAvatar({
    required double angle,
    required double radius,
    required MemberProgress member,
    bool isExtra = false,
  }) {
    return Positioned(
      left: radius + radius * math.cos(angle) - 24,
      top: radius + radius * math.sin(angle) - 24,
      child: _MemberAvatar(
        member: member,
        isExtra: isExtra,
        onTap: isExtra || member.userId.isEmpty
            ? null
            : () => onMemberTap?.call(member),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Center hub — group progress
// ─────────────────────────────────────────────────────────────────────

class _CenterHub extends StatelessWidget {
  final int completed;
  final int needed;
  final bool dayComplete;
  final bool shielded;
  final bool shieldAvailable;

  const _CenterHub({
    required this.completed,
    required this.needed,
    required this.dayComplete,
    required this.shielded,
    required this.shieldAvailable,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watchLanguage;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: dayComplete
            ? const LinearGradient(
                colors: AppColors.gradientTeal,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: dayComplete ? null : (isDark ? AppColors.darkSurfaceAlt : AppColors.primaryLight),
        boxShadow: dayComplete
            ? const [BoxShadow(color: AppColors.shadow, blurRadius: 14, offset: Offset(0, 6))]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (dayComplete)
            Icon(
              shielded ? Icons.shield_rounded : Icons.check_rounded,
              color: Colors.white,
              size: 30,
            )
          else
            Text(
              '$completed/$needed',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkText : AppColors.primaryDeep,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            dayComplete
                ? (shielded
                    ? state.t('Shielded', 'شیلڈ')
                    : state.t('Done', 'مکمل'))
                : state.t('today', 'آج'),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: dayComplete
                  ? Colors.white.withValues(alpha: 0.95)
                  : (isDark ? AppColors.darkMuted : AppColors.lightSecondaryText),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Member avatar — progress ring around the initial
// ─────────────────────────────────────────────────────────────────────

class _MemberAvatar extends StatelessWidget {
  final MemberProgress member;
  final bool isExtra;
  final VoidCallback? onTap;

  const _MemberAvatar({required this.member, this.isExtra = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dimmed = member.excludedInactive;
    final fraction = (member.completedCount / 5).clamp(0.0, 1.0);

    return Tooltip(
      message: isExtra ? '' : member.displayName,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: member.isDayComplete
                ? AppColors.success
                : dimmed
                    ? (isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder)
                    : AppColors.primary.withValues(alpha: (0.15 + fraction * 0.55).toDouble()),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.darkSurface : AppColors.lightCard,
            ),
            child: isExtra
                ? Center(
                    child: Text(
                      member.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkMuted : AppColors.lightSecondaryText,
                      ),
                    ),
                  )
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        member.displayName.isNotEmpty
                            ? member.displayName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: dimmed
                              ? (isDark ? AppColors.darkMuted : AppColors.lightMutedText)
                              : (isDark ? AppColors.darkText : AppColors.primaryDeep),
                        ),
                      ),
                      if (member.isDayComplete)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded, size: 9, color: Colors.white),
                          ),
                        )
                      else if (member.completedCount > 0)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              '${member.completedCount}',
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDeep,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
