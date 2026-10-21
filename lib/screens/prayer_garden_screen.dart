import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/sajda_stats_service.dart';
import '../state/app_state.dart';
import '../state/streak_state.dart';
import '../theme/app_theme.dart';
import '../utils/share_image.dart';

/// F7 — a living garden that reflects on-device worship stats.
///
/// Trees grow with active days, flowers bloom from tasbeeh sets, and fireflies
/// appear once the user has kept a best streak of at least a week.
class PrayerGardenScreen extends StatefulWidget {
  const PrayerGardenScreen({super.key});

  @override
  State<PrayerGardenScreen> createState() => _PrayerGardenScreenState();
}

class _PrayerGardenScreenState extends State<PrayerGardenScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final statsService = context.watch<SajdaStatsService>();
    final streak = context.watch<StreakState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats = statsService.snapshot(
      currentStreak: streak.solo?.currentStreak ?? 0,
      bestStreak: streak.solo?.bestStreak ?? 0,
    );
    final trees = (stats.activeDays / 2).ceil().clamp(0, 18);
    final flowers = (stats.tasbeehSets / 10).ceil().clamp(0, 26);
    final fireflies = stats.bestStreak >= 7
        ? (stats.bestStreak / 7).ceil().clamp(0, 9)
        : 0;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(app.t('Prayer Garden', 'نماز کا باغ')),
        actions: [
          IconButton(
            tooltip: app.t('Share', 'شیئر کریں'),
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => shareWidgetAsImage(
              context: context,
              widget: _GardenShareCard(
                app: app,
                stats: stats,
                trees: trees,
                flowers: flowers,
              ),
              fileName: 'sajda_prayer_garden',
              caption:
                  '${app.t('My Prayer Garden', 'میرا نماز کا باغ')} — '
                  '${app.t('$trees trees, $flowers flowers', '$trees درخت، $flowers پھول')}\n'
                  'https://play.google.com/store/apps/details?id=com.sajda.dataplus',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            height: 430,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFF071E2B), Color(0xFF0F4C5C), Color(0xFF1B7F6B)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 34,
                  right: 36,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFF3C4).withValues(alpha: 0.92),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFF3C4).withValues(alpha: 0.5),
                          blurRadius: 40,
                          spreadRadius: 14,
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    size: Size.infinite,
                    painter: _GardenPainter(
                      trees: trees,
                      flowers: flowers,
                      fireflies: fireflies,
                      phase: _controller.value,
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.34),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.park_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            app.t(
                              '$trees trees • $flowers flowers',
                              '$trees درخت • $flowers پھول',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          app.t(
                            '${stats.currentStreak}-day streak',
                            '${stats.currentStreak} دن کا سلسلہ',
                          ),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
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
                  icon: Icons.park_rounded,
                  value: '$trees',
                  label: app.t('Trees grown', 'اگائے گئے درخت'),
                  color: const Color(0xFF1B7F5C),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.local_florist_rounded,
                  value: '$flowers',
                  label: app.t('Flowers bloomed', 'کھلے پھول'),
                  color: const Color(0xFFC0392B),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.local_fire_department_rounded,
                  value: '${stats.bestStreak}',
                  label: app.t('Best streak', 'بہترین سلسلہ'),
                  color: const Color(0xFFB9770E),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.auto_awesome_rounded,
                  value: '$fireflies',
                  label: app.t('Fireflies', 'جگنو'),
                  color: const Color(0xFF7D3C98),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app.t('How your garden grows', 'آپ کا باغ کیسے بڑھتا ہے'),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                _LegendRow(
                  color: const Color(0xFF1B7F5C),
                  icon: Icons.park_rounded,
                  text: app.t(
                    'Every 2 active prayer days grows a tree.',
                    'ہر 2 فعال نماز دن ایک درخت اگاتے ہیں۔',
                  ),
                ),
                const SizedBox(height: 8),
                _LegendRow(
                  color: const Color(0xFFC0392B),
                  icon: Icons.local_florist_rounded,
                  text: app.t(
                    'Every 10 tasbeeh sets blooms a flower.',
                    'ہر 10 تسبیح کے دور ایک پھول کھلاتے ہیں۔',
                  ),
                ),
                const SizedBox(height: 8),
                _LegendRow(
                  color: const Color(0xFF7D3C98),
                  icon: Icons.auto_awesome_rounded,
                  text: app.t(
                    'A 7-day best streak brings fireflies to your garden.',
                    '7 دن کا بہترین سلسلہ آپ کے باغ میں جگنو لاتا ہے۔',
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkSurfaceAlt : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900, height: 1.1),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
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

class _LegendRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _LegendRow({
    required this.color,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _GardenPainter extends CustomPainter {
  final int trees;
  final int flowers;
  final int fireflies;
  final double phase;

  _GardenPainter({
    required this.trees,
    required this.flowers,
    required this.fireflies,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final groundTop = h * 0.66;

    // Stars.
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.7);
    for (var i = 0; i < 42; i++) {
      final x = ((i * 73) % 101) / 101 * w;
      final y = ((i * 37) % 47) / 47 * groundTop * 0.8;
      final r = (i % 3) * 0.4 + 0.5;
      canvas.drawCircle(Offset(x, y), r, starPaint);
    }

    // Far hills.
    final hillPaint = Paint()..color = const Color(0xFF0D3B34);
    final hill = Path()
      ..moveTo(0, groundTop - 10)
      ..quadraticBezierTo(w * 0.2, groundTop - 70, w * 0.42, groundTop - 20)
      ..quadraticBezierTo(w * 0.66, groundTop - 92, w, groundTop - 28)
      ..lineTo(w, groundTop + 20)
      ..lineTo(0, groundTop + 20)
      ..close();
    canvas.drawPath(hill, hillPaint);

    final hillNear = Paint()..color = const Color(0xFF0B2C27);
    final hill2 = Path()
      ..moveTo(0, groundTop)
      ..quadraticBezierTo(w * 0.3, groundTop - 44, w * 0.58, groundTop - 4)
      ..quadraticBezierTo(w * 0.82, groundTop - 34, w, groundTop)
      ..lineTo(w, groundTop + 30)
      ..lineTo(0, groundTop + 30)
      ..close();
    canvas.drawPath(hill2, hillNear);

    // Ground gradient.
    final groundRect = Rect.fromLTWH(0, groundTop, w, h - groundTop);
    final groundPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF145043), Color(0xFF0A2F28)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(groundRect);
    canvas.drawRect(groundRect, groundPaint);

    // Winding stream.
    final stream = Path()
      ..moveTo(w * 0.18, h)
      ..cubicTo(
        w * 0.28,
        h * 0.86,
        w * 0.62,
        h * 0.9,
        w * 0.82,
        h * 0.74,
      );
    final streamPaint = Paint()
      ..color = const Color(0xFF7FD8C7).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(stream, streamPaint);
    final streamShine = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(stream, streamShine);

    // Trees.
    for (var i = 0; i < trees; i++) {
      final t = trees <= 1 ? 0.5 : i / (trees - 1);
      final x = w * 0.08 + t * w * 0.84 + math.sin(i * 1.7) * 12;
      final baseY = groundTop + 18 + ((i * 13) % 26) * 1.2;
      final scale = 0.7 + ((i * 7) % 10) / 18;
      _drawTree(canvas, Offset(x, baseY), scale, i);
    }

    // Flowers.
    for (var i = 0; i < flowers; i++) {
      final t = flowers <= 1 ? 0.5 : i / (flowers - 1);
      final x = w * 0.05 + t * w * 0.9 + math.sin(i * 2.3) * 8;
      final y = h * 0.78 + ((i * 11) % 9) * 7.0;
      final sway = math.sin(phase * math.pi * 2 + i) * 1.6;
      _drawFlower(canvas, Offset(x + sway, y), i);
    }

    // Fireflies.
    for (var i = 0; i < fireflies; i++) {
      final baseX = w * 0.15 + ((i * 61) % 89) / 89 * w * 0.72;
      final baseY = h * 0.42 + ((i * 29) % 43) / 43 * h * 0.28;
      final dx = math.sin(phase * math.pi * 2 + i * 1.9) * 14;
      final dy = math.cos(phase * math.pi * 2 + i * 1.3) * 9;
      final glow = Paint()
        ..color = const Color(0xFFFFE082).withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
      canvas.drawCircle(Offset(baseX + dx, baseY + dy), 7, glow);
      canvas.drawCircle(
        Offset(baseX + dx, baseY + dy),
        1.8,
        Paint()..color = const Color(0xFFFFF8D6),
      );
    }
  }

  void _drawTree(Canvas canvas, Offset base, double scale, int seed) {
    final trunkPaint = Paint()..color = const Color(0xFF5B3A22);
    final trunk = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(base.dx, base.dy - 18 * scale),
        width: 5 * scale,
        height: 36 * scale,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(trunk, trunkPaint);

    final canopyColors = [
      const Color(0xFF2E8B57),
      const Color(0xFF3FA46A),
      const Color(0xFF237A4B),
    ];
    final canopy = Paint()
      ..color = canopyColors[seed % canopyColors.length];
    final center = Offset(base.dx, base.dy - 42 * scale);
    canvas.drawCircle(center, 19 * scale, canopy);
    canvas.drawCircle(
      Offset(center.dx - 13 * scale, center.dy + 7 * scale),
      13 * scale,
      canopy..color = canopyColors[(seed + 1) % canopyColors.length],
    );
    canvas.drawCircle(
      Offset(center.dx + 13 * scale, center.dy + 6 * scale),
      12 * scale,
      canopy..color = canopyColors[(seed + 2) % canopyColors.length],
    );
  }

  void _drawFlower(Canvas canvas, Offset base, int seed) {
    final stem = Paint()
      ..color = const Color(0xFF4F9D69)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(base, Offset(base.dx, base.dy - 9), stem);
    final colors = [
      const Color(0xFFFFB3BA),
      const Color(0xFFFFD166),
      const Color(0xFFE8BAFF),
      const Color(0xFFFF8FA3),
    ];
    final petal = Paint()..color = colors[seed % colors.length];
    final center = Offset(base.dx, base.dy - 10);
    for (var p = 0; p < 5; p++) {
      final angle = p * math.pi * 2 / 5;
      canvas.drawCircle(
        center + Offset(math.cos(angle) * 2.4, math.sin(angle) * 2.4),
        2.1,
        petal,
      );
    }
    canvas.drawCircle(center, 1.5, Paint()..color = const Color(0xFFFFE082));
  }

  @override
  bool shouldRepaint(_GardenPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.trees != trees ||
      oldDelegate.flowers != flowers ||
      oldDelegate.fireflies != fireflies;
}

class _GardenShareCard extends StatelessWidget {
  final AppState app;
  final SajdaStatsSnapshot stats;
  final int trees;
  final int flowers;

  const _GardenShareCard({
    required this.app,
    required this.stats,
    required this.trees,
    required this.flowers,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF071E2B), Color(0xFF0F4C5C), Color(0xFF1B7F6B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.mosque_rounded,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 5),
                Text(
                  'SAJDA',
                  style: TextStyle(
                    letterSpacing: 3,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.park_rounded, color: Colors.white, size: 46),
            const SizedBox(height: 14),
            Text(
              app.t('MY PRAYER GARDEN', 'میرا نماز کا باغ'),
              style: TextStyle(
                letterSpacing: 2,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              app.t('$trees trees', '$trees درخت'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              app.t(
                '$flowers flowers grown from dhikr',
                'ذکر سے کھلے $flowers پھول',
              ),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _stat('${stats.activeDays}', app.t('DAYS', 'دن')),
                  _stat('${stats.currentStreak}', app.t('STREAK', 'سلسلہ')),
                  _stat('${stats.totalPrayers}', app.t('PRAYERS', 'نمازیں')),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'play.google.com/store/apps/details?id=com.sajda.dataplus',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.32),
                fontSize: 7.5,
              ),
            ),
          ],
        ),
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
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 8,
            letterSpacing: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
