import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/static_data.dart';
import '../services/custom_tasbeeh_service.dart';
import '../services/sajda_stats_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

const _channel = MethodChannel('sajda/prayer_alarm');
const _kSession = 'sajda_tasbeeh_session';

const _gold = Color(0xFFE9C46A);
const _goldLight = Color(0xFFF6E3A1);

class TasbeehScreen extends StatefulWidget {
  const TasbeehScreen({super.key});

  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends State<TasbeehScreen>
    with TickerProviderStateMixin {
  TasbeehPreset _preset = tasbeehPresets.isNotEmpty
      ? tasbeehPresets.first
      : const TasbeehPreset(name: '', arabic: '', meaning: '', defaultCount: 33);
  CustomTasbeeh? _custom;
  List<CustomTasbeeh> _customs = [];
  int _count = 0;
  int _sets = 0;
  int _target = 33;

  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceAnim;
  late final AnimationController _rippleCtrl;
  late final AnimationController _celebrateCtrl;
  List<_Confetti> _confetti = const [];

  final AudioPlayer _tickPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _target = _preset.defaultCount;
    _bounceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.86).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.86, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 65,
      ),
    ]).animate(_bounceCtrl);
    _rippleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _celebrateCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
    _celebrateCtrl.addListener(() => setState(() {}));
    _initSound();
    _restoreSession();
    WakelockPlus.enable().catchError((_) {});
  }

  @override
  void dispose() {
    WakelockPlus.disable().catchError((_) {});
    _bounceCtrl.dispose();
    _rippleCtrl.dispose();
    _celebrateCtrl.dispose();
    _tickPlayer.dispose();
    super.dispose();
  }

  Future<void> _initSound() async {
    try {
      await _tickPlayer.setAudioSource(AudioSource.asset('assets/audio/tick.wav'));
      await _tickPlayer.setVolume(0.55);
    } catch (_) {
      // Sound is a nice-to-have — never let it break the counter.
    }
  }

  void _playTick({double volume = 0.55}) {
    try {
      _tickPlayer.setVolume(volume);
      _tickPlayer.seek(Duration.zero);
      _tickPlayer.play();
    } catch (_) {}
  }

  Future<void> _restoreSession() async {
    final customs = await CustomTasbeehService.instance.getAll();
    TasbeehPreset preset = tasbeehPresets.isNotEmpty
        ? tasbeehPresets.first
        : const TasbeehPreset(name: '', arabic: '', meaning: '', defaultCount: 33);
    CustomTasbeeh? custom;
    int count = 0;
    int sets = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSession);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final key = json['key']?.toString() ?? '';
        final kind = json['kind']?.toString() ?? '';
        count = (json['count'] as num?)?.toInt() ?? 0;
        sets = (json['sets'] as num?)?.toInt() ?? 0;
        if (kind == 'custom') {
          custom = customs.where((c) => c.id == key).firstOrNull;
          if (custom == null) count = 0;
        } else {
          final found = tasbeehPresets.where((p) => p.name == key).firstOrNull;
          if (found != null) preset = found;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _customs = customs;
      if (custom != null) {
        _custom = custom;
        _target = custom.count;
      } else {
        _preset = preset;
        _target = preset.defaultCount;
      }
      _count = count.clamp(0, _target > 0 ? _target : count);
      _sets = sets;
    });
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kSession,
        jsonEncode({
          'kind': _custom != null ? 'custom' : 'preset',
          'key': _custom != null ? _custom!.id : _preset.name,
          'count': _count,
          'sets': _sets,
        }),
      );
    } catch (_) {}
  }

  Future<void> _haptic(int ms) async {
    try {
      final ok = await _channel.invokeMethod('vibrate', {'duration': ms});
      if (ok != true) HapticFeedback.heavyImpact();
    } catch (_) {
      HapticFeedback.heavyImpact();
    }
  }

  void _increment() {
    final state = context.read<AppState>();
    if (state.tasbeehVibration) _haptic(40);
    if (state.tasbeehSound) _playTick();
    _bounceCtrl.forward(from: 0);
    _rippleCtrl.forward(from: 0);

    final completed = _target > 0 && _count + 1 >= _target;
    setState(() {
      _count = completed ? 0 : _count + 1;
      if (completed) _sets++;
    });
    _persist();
    if (completed) {
      unawaited(SajdaStatsService.instance.addTasbeehSet());
      _celebrate(state);
    }
  }

  void _celebrate(AppState state) {
    if (state.tasbeehVibration) _haptic(180);
    if (state.tasbeehSound) {
      Future.delayed(const Duration(milliseconds: 130), () => _playTick(volume: 0.7));
    }
    final rng = Random();
    _confetti = List.generate(46, (i) {
      return _Confetti(
        angle: rng.nextDouble() * 2 * pi,
        dist: 0.55 + rng.nextDouble() * 0.5,
        size: 3.5 + rng.nextDouble() * 4,
        color: [
          _gold,
          _goldLight,
          const Color(0xFF00BFA5),
          const Color(0xFF7BE3D2),
          Colors.white,
        ][rng.nextInt(5)],
        spin: rng.nextDouble() * 2 * pi,
      );
    });
    _celebrateCtrl.forward(from: 0);
  }

  void _reset() {
    setState(() {
      _count = 0;
      _sets = 0;
    });
    _persist();
  }

  void _selectPreset(TasbeehPreset p) {
    setState(() {
      _preset = p;
      _custom = null;
      _target = p.defaultCount;
      _count = 0;
      _sets = 0;
    });
    _persist();
  }

  void _selectCustom(CustomTasbeeh c) {
    setState(() {
      _custom = c;
      _target = c.count;
      _count = 0;
      _sets = 0;
    });
    _persist();
  }

  Future<void> _addCustom() async {
    final nameCtrl = TextEditingController();
    final countCtrl = TextEditingController(text: '33');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Custom Tasbeeh'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Dhikr name (e.g. Rabighfirli)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: countCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target count'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Add')),
        ],
      ),
    );
    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      final count = int.tryParse(countCtrl.text) ?? 33;
      await CustomTasbeehService.instance.add(nameCtrl.text.trim(), count);
      await _loadCustoms();
    }
    nameCtrl.dispose();
    countCtrl.dispose();
  }

  Future<void> _loadCustoms() async {
    final c = await CustomTasbeehService.instance.getAll();
    if (!mounted) return;
    setState(() => _customs = c);
  }

  Future<void> _deleteCustom(CustomTasbeeh c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${c.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await CustomTasbeehService.instance.remove(c.id);
      if (_custom?.id == c.id) {
        _selectPreset(tasbeehPresets.isNotEmpty
            ? tasbeehPresets.first
            : const TasbeehPreset(name: '', arabic: '', meaning: '', defaultCount: 33));
      }
      await _loadCustoms();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = _target == 0 ? 0.0 : _count / _target;
    final size = MediaQuery.of(context).size;
    final isSmall = size.width < 360;
    final ringSize = (size.shortestSide * 0.52).clamp(180.0, 270.0);
    final countFont = (ringSize * 0.28).clamp(36.0, 72.0);
    final labelFont = (ringSize * 0.115).clamp(12.0, 18.0);
    final celebrating = _celebrateCtrl.isAnimating;

    return Scaffold(
      appBar: AppBar(title: Text(state.t('Tasbeeh Counter', 'تسبیح کاؤنٹر'))),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(bottom: isSmall ? 16 : 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: isSmall ? 84 : 96,
                      child: ListView.separated(
                        padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 16, vertical: 8),
                        scrollDirection: Axis.horizontal,
                        itemCount: tasbeehPresets.length + _customs.length + 1,
                        separatorBuilder: (_, _) => SizedBox(width: isSmall ? 8 : 10),
                        itemBuilder: (ctx, i) {
                          if (i < tasbeehPresets.length) {
                            final p = tasbeehPresets[i];
                            final selected = _custom == null && p.name == _preset.name;
                            return _PresetChip(
                              isSmall: isSmall,
                              selected: selected,
                              arabic: p.arabic,
                              name: p.name,
                              count: p.defaultCount,
                              color: selected ? AppColors.accent(isDark) : null,
                              onTap: () => _selectPreset(p),
                            );
                          }
                          final customIndex = i - tasbeehPresets.length;
                          if (customIndex < _customs.length) {
                            final c = _customs[customIndex];
                            final selected = _custom?.id == c.id;
                            return _PresetChip(
                              isSmall: isSmall,
                              selected: selected,
                              arabic: '',
                              name: c.name,
                              count: c.count,
                              icon: Icons.bookmark_added_outlined,
                              color: selected ? AppColors.primaryPill(isDark) : null,
                              onTap: () => _selectCustom(c),
                              onLongPress: () => _deleteCustom(c),
                            );
                          }
                          return _PresetChip(
                            isSmall: isSmall,
                            selected: false,
                            arabic: '',
                            name: state.t('Custom', 'اپنا ذکر'),
                            count: 0,
                            icon: Icons.add_circle_outline_rounded,
                            color: null,
                            borderColor: AppColors.accent(isDark).withValues(alpha: 0.5),
                            onTap: _addCustom,
                          );
                        },
                      ),
                    ),
                    SizedBox(height: isSmall ? 6 : 10),
                    Flexible(
                      child: Text(
                        _custom != null ? _custom!.name : _preset.arabic,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmall ? 22 : 34,
                          fontWeight: FontWeight.w700,
                          height: 1.6,
                          color: celebrating ? AppColors.accent(isDark) : null,
                        ),
                      ),
                    ),
                    SizedBox(height: isSmall ? 2 : 4),
                    Text(
                      _custom != null
                          ? state.t('Custom tasbeeh', 'اپنا ذکر')
                          : state.t(_preset.meaning, _preset.meaning),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    SizedBox(height: isSmall ? 8 : 14),
                    // Tappable ring — the whole area is the button.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _increment,
                      child: SizedBox(
                        width: ringSize + 44,
                        height: ringSize + 44,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Tap ripple
                            AnimatedBuilder(
                              animation: _rippleCtrl,
                              builder: (ctx, _) => CustomPaint(
                                size: Size(ringSize + 44, ringSize + 44),
                                painter: _RipplePainter(
                                  value: _rippleCtrl.isAnimating ? _rippleCtrl.value : 0,
                                  color: AppColors.accent(isDark),
                                ),
                              ),
                            ),
                            // Progress ring (gradient + glow)
                            TweenAnimationBuilder<double>(
                              tween: Tween(end: progress.clamp(0.0, 1.0)),
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              builder: (ctx, value, _) => CustomPaint(
                                size: Size(ringSize, ringSize),
                                painter: _RingPainter(progress: value, isDark: isDark),
                              ),
                            ),
                            // Confetti burst on set completion
                            if (celebrating)
                              IgnorePointer(
                                child: CustomPaint(
                                  size: Size(ringSize + 44, ringSize + 44),
                                  painter: _ConfettiPainter(
                                    confetti: _confetti,
                                    t: _celebrateCtrl.value,
                                  ),
                                ),
                              ),
                            // Count + sets
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedBuilder(
                                  animation: _bounceCtrl,
                                  builder: (ctx, child) => Transform.scale(
                                    scale: _bounceAnim.value,
                                    child: child,
                                  ),
                                  child: Text(
                                    '$_count',
                                    style: TextStyle(
                                      fontSize: countFont,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                      color: isDark ? Colors.white : null,
                                    ),
                                  ),
                                ),
                                SizedBox(height: isSmall ? 4 : 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryPill(isDark),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '$_sets / $_target',
                                    style: TextStyle(
                                      fontSize: labelFont,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.accent(isDark),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Completion banner
                            AnimatedBuilder(
                              animation: _celebrateCtrl,
                              builder: (ctx, child) {
                                final v = _celebrateCtrl.value;
                                return Opacity(
                                  opacity: v < 0.15 ? v / 0.15 : (v > 0.8 ? (1 - v) / 0.2 : 1),
                                  child: Transform.translate(
                                    offset: Offset(0, (1 - min(v / 0.15, 1.0)) * 10),
                                    child: child,
                                  ),
                                );
                              },
                              child: Visibility(
                                visible: celebrating,
                                maintainState: false,
                                child: Padding(
                                  padding: EdgeInsets.only(top: ringSize - 18),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [_gold, _goldLight]),
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _gold.withValues(alpha: 0.45),
                                          blurRadius: 18,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      state.t('MashaAllah! Set complete', 'ماشاء اللہ! سیٹ مکمل'),
                                      style: TextStyle(
                                        fontSize: isSmall ? 11 : 13,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF3D2E00),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isSmall ? 2 : 6),
                    Text(
                      state.t('Tap the ring to count', 'گنتی کے لیے رنگ پر ٹیپ کریں'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: isSmall ? 10.5 : 12,
                          ),
                    ),
                    SizedBox(height: isSmall ? 10 : 14),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ToggleCard(
                              icon: Icons.vibration_rounded,
                              label: state.t('Vibration', 'کمپن'),
                              value: state.tasbeehVibration,
                              isDark: isDark,
                              onChanged: state.setTasbeehVibration,
                            ),
                          ),
                          SizedBox(width: isSmall ? 8 : 10),
                          Expanded(
                            child: _ToggleCard(
                              icon: Icons.music_note_rounded,
                              label: state.t('Sound', 'آواز'),
                              value: state.tasbeehSound,
                              isDark: isDark,
                              onChanged: state.setTasbeehSound,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isSmall ? 10 : 12),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 16),
                      child: OutlinedButton.icon(
                        onPressed: _reset,
                        icon: Icon(Icons.refresh_rounded, size: isSmall ? 18 : 20),
                        label: Text(state.t('Reset', 'ری سیٹ'),
                            style: TextStyle(
                                fontSize: isSmall ? 13 : 15, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: Size.fromHeight(isSmall ? 48 : 52),
                          padding: EdgeInsets.symmetric(vertical: isSmall ? 10 : 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Confetti {
  final double angle;
  final double dist;
  final double size;
  final Color color;
  final double spin;
  const _Confetti({
    required this.angle,
    required this.dist,
    required this.size,
    required this.color,
    required this.spin,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Confetti> confetti;
  final double t;
  _ConfettiPainter({required this.confetti, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    final eased = Curves.easeOutCubic.transform(t);
    final paint = Paint();
    for (final c in confetti) {
      final r = c.dist * maxR * eased;
      final dx = cos(c.angle) * r;
      final dy = sin(c.angle) * r + 70 * t * t;
      paint.color = c.color.withValues(alpha: (1 - t).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(center.dx + dx, center.dy + dy), c.size * (1 - t * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

class _RipplePainter extends CustomPainter {
  final double value;
  final Color color;
  _RipplePainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (value <= 0 || value >= 1) return;
    final center = size.center(Offset.zero);
    final base = size.shortestSide * 0.33;
    final expand = Curves.easeOut.transform(value);
    final opacity = (1 - value) * 0.3;
    canvas.drawCircle(
      center,
      base + expand * size.shortestSide * 0.14,
      Paint()..color = color.withValues(alpha: opacity * 0.35),
    );
    canvas.drawCircle(
      center,
      base + expand * size.shortestSide * 0.2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = color.withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.value != value;
}

class _RingPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  _RingPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.shortestSide * 0.07;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - strokeWidth;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = (isDark ? Colors.white : Colors.grey).withValues(alpha: 0.13),
    );

    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;

    final shader = SweepGradient(
      startAngle: -pi / 2,
      endAngle: 3 * pi / 2,
      colors: const [_goldLight, _gold, _gold],
      transform: const GradientRotation(-pi / 2),
    ).createShader(rect);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = shader;

    // soft glow behind the arc
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * p,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 1.5
        ..strokeCap = StrokeCap.round
        ..color = _gold.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawArc(rect, -pi / 2, 2 * pi * p, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.isDark != isDark;
}

class _PresetChip extends StatelessWidget {
  final bool isSmall;
  final bool selected;
  final String arabic;
  final String name;
  final int count;
  final IconData? icon;
  final Color? color;
  final Color? borderColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _PresetChip({
    required this.isSmall,
    required this.selected,
    required this.arabic,
    required this.name,
    required this.count,
    this.icon,
    this.color,
    this.borderColor,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = color ?? (dark ? AppColors.darkSurface : AppColors.lightCard);
    final bdColor = selected
        ? (color ?? AppColors.primary)
        : (borderColor ?? Colors.grey.withValues(alpha: 0.3));
    final textColor = selected ? Colors.white : null;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isSmall ? 96 : 128,
        padding: EdgeInsets.all(isSmall ? 10 : 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: bdColor),
          boxShadow: selected && color != null
              ? [BoxShadow(color: color!.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null && arabic.isEmpty)
              Icon(icon, size: 18, color: color ?? AppColors.primary)
            else
              Text(arabic, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: isSmall ? 13 : 16, fontWeight: FontWeight.w700, color: textColor)),
            SizedBox(height: isSmall ? 3 : 5),
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: TextStyle(fontSize: isSmall ? 9 : (icon != null ? 10 : 11.5),
                    fontWeight: FontWeight.w700, color: selected ? Colors.white70 : AppColors.textMuted)),
            Text('$count', style: TextStyle(fontSize: isSmall ? 8 : 10, color: selected ? Colors.white54 : AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _ToggleCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Whole card is tappable — the 26px switch alone was an easy-to-miss
    // target, which felt like the toggle "sometimes not working".
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value
                ? AppColors.accent(isDark).withValues(alpha: 0.55)
                : Colors.grey.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 17, color: value ? AppColors.accent(isDark) : AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(
              height: 26,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: AppColors.accent(isDark),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
