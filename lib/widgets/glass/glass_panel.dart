import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final double sigma;
  final Color? tint;
  final Color? border;
  final bool darken;

  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 22,
    this.padding,
    this.sigma = 18,
    this.tint,
    this.border,
    this.darken = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = tint ??
        (isDark
            ? Colors.white.withValues(alpha: darken ? 0.06 : 0.08)
            : Colors.white.withValues(alpha: darken ? 0.42 : 0.55));
    final stroke = border ??
        (isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.70));
    final List<BoxShadow> shadow = isDark
        ? <BoxShadow>[]
        : <BoxShadow>[
            BoxShadow(
              color: AppColors.shadowSoft,
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: stroke, width: 1),
            boxShadow: shadow,
          ),
          child: child,
        ),
      ),
    );
  }
}
