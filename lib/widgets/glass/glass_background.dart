import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class GlassBackground extends StatelessWidget {
  final Widget child;

  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    final blobs = isDark
        ? const [
            (Alignment(-0.9, -0.85), AppColors.primary, 0.30),
            (Alignment(0.95, -0.35), Color(0xFF00897B), 0.24),
            (Alignment(-0.7, 0.9), Color(0xFF00695C), 0.22),
            (Alignment(0.6, 0.95), AppColors.primaryDark, 0.18),
          ]
        : const [
            (Alignment(-0.9, -0.85), AppColors.emerald, 0.16),
            (Alignment(0.95, -0.35), AppColors.emeraldSoft, 0.14),
            (Alignment(-0.7, 0.9), AppColors.primary, 0.10),
            (Alignment(0.6, 0.95), AppColors.emerald, 0.10),
          ];

    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: base)),
        for (final (alignment, color, opacity) in blobs)
          Positioned.fill(
            child: CustomPaint(
              painter: _BlobPainter(alignment: alignment, color: color, opacity: opacity),
            ),
          ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: const SizedBox.shrink(),
          ),
        ),
        child,
      ],
    );
  }
}

class _BlobPainter extends CustomPainter {
  final Alignment alignment;
  final Color color;
  final double opacity;

  const _BlobPainter({required this.alignment, required this.color, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = alignment.alongSize(size);
    final radius = size.shortestSide * 0.55;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_BlobPainter oldDelegate) =>
      oldDelegate.alignment != alignment ||
      oldDelegate.color != color ||
      oldDelegate.opacity != opacity;
}
