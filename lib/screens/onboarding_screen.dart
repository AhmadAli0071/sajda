import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../screens/map_location_picker_screen.dart';
import '../state/app_state.dart';

// ─────────────────────────────────────────────────────────────
// Onboarding — "Emerald Night & Gold" design.
// Deep emerald gradient + subtle Islamic geometric pattern,
// each page opens with one of Allah's beautiful names in gold,
// and a slide-to-continue pill button.
// ─────────────────────────────────────────────────────────────

class _OnboardPage {
  final IconData icon;
  final String arabicName;
  final String transliteration;
  final String meaning;
  final String title;
  final String subtitle;
  final String cta;
  final Color accent; // glow / icon tint per page

  const _OnboardPage({
    required this.icon,
    required this.arabicName,
    required this.transliteration,
    required this.meaning,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.accent,
  });
}

const _kGold = Color(0xFFE3C46B);
const _kGoldLight = Color(0xFFF7E7A6);
const _kGoldDeep = Color(0xFFB9963F);
const _kGoldGradient = [_kGoldLight, _kGold, _kGoldDeep];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _page = PageController();
  int _index = 0;
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  static const _pages = [
    _OnboardPage(
      icon: Icons.auto_awesome_rounded,
      arabicName: 'الرَّحْمَنُ الرَّحِيمُ',
      transliteration: 'Ar-Rahman · Ar-Raheem',
      meaning: 'The Most Compassionate, The Most Merciful',
      title: 'Assalamu Alaikum',
      subtitle:
          'Welcome to Sajda — your daily companion\nfor prayer, Quran & Qibla',
      cta: 'Begin',
      accent: Color(0xFF2EE6C8),
    ),
    _OnboardPage(
      icon: Icons.notifications_active_rounded,
      arabicName: 'السَّمِيعُ',
      transliteration: 'As-Samee\'',
      meaning: 'The All-Hearing — He hears every call',
      title: 'Never Miss a Prayer',
      subtitle:
          'Accurate prayer times for your location\nwith beautiful Adhan notifications',
      cta: 'Continue',
      accent: Color(0xFF4FC3F7),
    ),
    _OnboardPage(
      icon: Icons.menu_book_rounded,
      arabicName: 'الْهَادِي',
      transliteration: 'Al-Haadi',
      meaning: 'The Guide — light for every heart',
      title: 'Read & Understand Quran',
      subtitle:
          'Explore all 114 Surahs with translations & tafsir\nTrack your reading progress',
      cta: 'Continue',
      accent: Color(0xFF7DE2A8),
    ),
    _OnboardPage(
      icon: Icons.local_fire_department_rounded,
      arabicName: 'الشَّكُورُ',
      transliteration: 'Ash-Shakoor',
      meaning: 'The Most Appreciative of every deed',
      title: 'Build Your Streak',
      subtitle:
          'Stay consistent with daily prayers\nand grow together with friends & family',
      cta: 'Continue',
      accent: Color(0xFFFFC96B),
    ),
    _OnboardPage(
      icon: Icons.explore_rounded,
      arabicName: 'النُّورُ',
      transliteration: 'An-Noor',
      meaning: 'The Light — wherever you are',
      title: 'Find Your Qibla',
      subtitle:
          'Precise Qibla compass that works everywhere\nSet your location and pray with confidence',
      cta: 'Bismillah',
      accent: Color(0xFFE3C46B),
    ),
  ];

  static const int _mapPageIndex = 5;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.08).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    _page.dispose();
    super.dispose();
  }

  void _next() {
    HapticFeedback.lightImpact();
    if (_index < _pages.length - 1) {
      _page.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    } else {
      setState(() => _index = _mapPageIndex);
    }
  }

  Future<void> _finish() async {
    final state = context.read<AppState>();
    await state.setOnboardingDone();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (_index == _mapPageIndex) {
      return MapLocationPickerScreen(onLocationConfirmed: _finish);
    }

    final p = _pages[_index];
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Deep emerald night gradient ──
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF04140E),
                    Color(0xFF06291E),
                    Color(0xFF03150F),
                  ],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
            // ── Islamic geometric star pattern ──
            Positioned.fill(
              child: CustomPaint(painter: _StarPatternPainter()),
            ),
            // ── Breathing accent glow orbs ──
            Positioned(
              top: -110,
              right: -80,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, _) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          p.accent.withValues(alpha: 0.22),
                          p.accent.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 60,
              left: -90,
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, _) => Transform.scale(
                  scale: 2 - _pulseAnim.value,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _kGold.withValues(alpha: 0.10),
                          _kGold.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // ── Content ──
            SafeArea(
              child: Column(
                children: [
                  // Skip
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, right: 12),
                      child: TextButton(
                        onPressed: _finish,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withValues(alpha: 0.5),
                        ),
                        child: Text(
                          state.t('Skip', 'چھوڑیں'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _page,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemCount: _pages.length,
                      itemBuilder: (_, i) => _OnboardPageView(
                        key: ValueKey(i),
                        page: _pages[i],
                      ),
                    ),
                  ),
                  // ── Gold dots ──
                  Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _index ? 30 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: i == _index
                                ? const LinearGradient(colors: _kGoldGradient)
                                : null,
                            color: i == _index
                                ? null
                                : Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: i == _index
                                ? [
                                    BoxShadow(
                                      color: _kGold.withValues(alpha: 0.45),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // ── Slide-to-continue pill ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: _SlideButton(
                      label: p.cta,
                      onSlideComplete: _next,
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page View ──────────────────────────────────────────────
class _OnboardPageView extends StatelessWidget {
  final _OnboardPage page;
  const _OnboardPageView({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 34 * (1 - t)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Feature icon in a glassy glowing circle
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: page.accent.withValues(alpha: 0.12),
                      border: Border.all(
                        color: page.accent.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: page.accent.withValues(alpha: 0.35),
                          blurRadius: 30,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(page.icon, color: page.accent, size: 32),
                  ),
                  const SizedBox(height: 34),
                  // ── Allah's beautiful name in gold ──
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: _kGoldGradient,
                      ).createShader(bounds),
                      child: Text(
                        page.arabicName,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 46,
                          height: 1.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    page.transliteration,
                    style: TextStyle(
                      color: _kGold.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    page.meaning,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  // Title
                  Text(
                    page.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.3,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Subtitle
                  Text(
                    page.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      color: Colors.white.withValues(alpha: 0.65),
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Slide-to-continue button ────────────────────────────────
class _SlideButton extends StatefulWidget {
  final String label;
  final VoidCallback onSlideComplete;
  const _SlideButton({required this.label, required this.onSlideComplete});

  @override
  State<_SlideButton> createState() => _SlideButtonState();
}

class _SlideButtonState extends State<_SlideButton> {
  double _dx = 0;
  bool _dragging = false;

  static const _thumbSize = 50.0;
  static const _trackPadding = 5.0;

  void _onStart(DragStartDetails d) {
    setState(() => _dragging = true);
  }

  void _onUpdate(DragUpdateDetails d, double maxDrag) {
    setState(() {
      _dragging = true;
      _dx = (_dx + d.delta.dx).clamp(0.0, maxDrag);
    });
  }

  void _onEnd(double maxDrag) {
    if (_dx >= maxDrag * 0.78) {
      HapticFeedback.mediumImpact();
      setState(() => _dx = maxDrag);
      widget.onSlideComplete();
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) setState(() { _dx = 0; _dragging = false; });
      });
    } else {
      setState(() {
        _dragging = false;
        _dx = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag =
            (constraints.maxWidth - _thumbSize - _trackPadding * 2 - 4)
                .clamp(0.0, double.infinity);
        final progress = maxDrag <= 0 ? 0.0 : (_dx / maxDrag).clamp(0.0, 1.0);
        final settle = Duration(milliseconds: _dragging ? 0 : 380);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onStart,
          onHorizontalDragUpdate: (d) => _onUpdate(d, maxDrag),
          onHorizontalDragEnd: (_) => _onEnd(maxDrag),
          onHorizontalDragCancel: () =>
              setState(() { _dragging = false; _dx = 0; }),
          onTap: widget.onSlideComplete,
          child: Container(
            // Full-width track: without an explicit width the Stack used to
            // shrink to the label text, clipping the thumb mid-slide.
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: _kGold.withValues(alpha: 0.35 + progress * 0.45),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _kGold.withValues(alpha: 0.15 + progress * 0.25),
                  blurRadius: 22,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28.8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Gold fill trailing the thumb
                  AnimatedPositioned(
                    duration: settle,
                    curve: Curves.easeOutBack,
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: (_trackPadding + 2 + _dx + _thumbSize / 2)
                        .clamp(0.0, double.infinity),
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _kGold.withValues(alpha: 0.04 + progress * 0.20),
                              _kGold.withValues(alpha: 0.04),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Center label — pad both sides equally so the text
                  // stays visually centred despite the thumb on the left.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _thumbSize),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: (1 - progress * 1.4).clamp(0.0, 1.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Flexible(
                            child: Text(
                              widget.label,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            Icons.keyboard_double_arrow_right_rounded,
                            color: _kGold.withValues(alpha: 0.9),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Draggable gold thumb
                  AnimatedPositioned(
                    duration: settle,
                    curve: Curves.easeOutBack,
                    left: _trackPadding + 2 + _dx,
                    top: 4,
                    child: Container(
                      width: _thumbSize,
                      height: _thumbSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _kGoldGradient,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _kGold.withValues(alpha: 0.55),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFF0A2E22),
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Islamic geometric star pattern ──────────────────────────
class _StarPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _kGold.withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const cell = 84.0;
    const r = 26.0;
    for (double x = -cell; x < size.width + cell; x += cell) {
      for (double y = -cell; y < size.height + cell; y += cell) {
        final center = Offset(x, y);
        // 8-point star = two overlapping squares (one rotated 45°)
        for (var rot = 0; rot < 2; rot++) {
          final path = Path();
          for (var i = 0; i < 4; i++) {
            final angle = i * 3.14159265 / 2 + rot * 3.14159265 / 4;
            final px = center.dx + r * math.cos(angle);
            final py = center.dy + r * math.sin(angle);
            if (i == 0) {
              path.moveTo(px, py);
            } else {
              path.lineTo(px, py);
            }
          }
          path.close();
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
