import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'streak_components.dart';

/// Shareable streak card (feature F1).
///
/// Pure UI: data + localized labels only, no network or state subscriptions
/// beyond language. `shareWidgetAsImage` (`lib/utils/share_image.dart`)
/// renders it through a RepaintBoundary into a 1080×1080 PNG (360 logical px
/// × 3 device pixel ratio) and hands it to the system share sheet.
class StreakShareCard extends StatelessWidget {
  final int currentStreak;
  final int bestStreak;
  final int todayCount;
  final String monthLabel;

  const StreakShareCard({
    super.key,
    required this.currentStreak,
    required this.bestStreak,
    required this.todayCount,
    required this.monthLabel,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watchLanguage;
    final streakLabel = state.t('day streak', 'روز کا سلسلہ');
    final bestLabel = state.t('Best', 'بہترین');
    final todayLabel = state.t('Today', 'آج');
    final brand = state.t('SAJDA', 'سجدہ');
    final tagline = state.t('DAILY ATHAN & QIBLA', 'روزانہ اذان و قبلہ');

    return Container(
      width: 360,
      height: 360,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.gradientTeal,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Brand header ──
          Row(
            children: [
              const Icon(Icons.mosque_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                brand,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
              const Spacer(),
              Text(
                monthLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),

          // ── Hero streak number ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.white,
                size: 52,
              ),
              const SizedBox(width: 10),
              Text(
                '$currentStreak',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 72,
                  fontWeight: FontWeight.w800,
                  height: 0.95,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    streakLabel,
                    maxLines: 2,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Today's 5-dot progress ──
          Row(
            children: [
              Text(
                '$todayLabel ${todayCount.clamp(0, 5)}/5',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: List.generate(5, (i) {
                  final filled = i < todayCount.clamp(0, 5);
                  return Container(
                    width: 11,
                    height: 11,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? Colors.white : Colors.transparent,
                      border: Border.all(
                        color: filled
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        width: 1.4,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white24, height: 1),
          const Spacer(),

          // ── Best + brand footer ──
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$bestLabel: $bestStreak',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tagline,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
