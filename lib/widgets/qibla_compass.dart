import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

/// Real compass that points toward Qibla using the device magnetometer.
/// If no sensor data is available it falls back to a static bearing view.
class QiblaCompass extends StatefulWidget {
  final QiblaResponse qibla;
  final double size;
  final bool isUrdu;
  const QiblaCompass({
    super.key,
    required this.qibla,
    this.size = 230,
    this.isUrdu = true,
  });

  @override
  State<QiblaCompass> createState() => _QiblaCompassState();
}

class _QiblaCompassState extends State<QiblaCompass> {
  double? _heading;
  bool _hasStream = false;
  /// False once we're confident the device has no magnetometer.
  /// Starts true so low-end devices don't flash the "no sensor" panel
  /// before the first compass event arrives.
  bool _sensorAvailable = true;
  StreamSubscription<CompassEvent>? _sub;

  // Magnetometers fire at 50-100 Hz; rebuilding the dial (3 transforms,
  // gradients, shadows) at that rate tanks low-end devices to <20 FPS.
  // We coalesce raw events and only setState at ~20 FPS, plus a 1.5°
  // dead-zone so micro-jitter never triggers a rebuild at all.
  static const Duration _throttleInterval = Duration(milliseconds: 50);
  static const double _deadZoneDeg = 1.5;
  DateTime _lastEmit = DateTime.fromMillisecondsSinceEpoch(0);
  CompassEvent? _pending;
  bool _flushScheduled = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _onSensorEvent(CompassEvent event) {
    if (!mounted) return;
    final now = DateTime.now();
    final elapsed = now.difference(_lastEmit);
    if (elapsed >= _throttleInterval) {
      _lastEmit = now;
      _applyHeading(event);
    } else {
      // Hold the latest event; a zero-delay timer flushes it once the
      // throttle window opens so we never lag behind the sensor.
      _pending = event;
      if (!_flushScheduled) {
        _flushScheduled = true;
        Future.delayed(_throttleInterval - elapsed, () {
          _flushScheduled = false;
          final pending = _pending;
          _pending = null;
          if (!mounted || pending == null) return;
          if (DateTime.now().difference(_lastEmit) >= _throttleInterval) {
            _lastEmit = DateTime.now();
            _applyHeading(pending);
          }
        });
      }
    }
  }

  void _applyHeading(CompassEvent event) {
    final next = event.heading;
    final prev = _heading;
    // Dead-zone: skip setState when the heading barely moved (noise).
    if (prev != null &&
        next != null &&
        (next - prev).abs() < _deadZoneDeg) {
      if (!_hasStream || !_sensorAvailable) {
        setState(() {
          _hasStream = true;
          _sensorAvailable = true;
        });
      }
      return;
    }
    setState(() {
      _heading = next;
      _hasStream = true;
      _sensorAvailable = true;
    });
  }

  Future<void> _init() async {
    final stream = FlutterCompass.events;
    if (stream == null) {
      if (mounted) {
        setState(() {
          _hasStream = false;
          _sensorAvailable = false;
        });
      }
      return;
    }
    _sub = stream.listen(
      _onSensorEvent,
      onError: (_) {
        if (mounted) {
          setState(() {
            _hasStream = false;
            _sensorAvailable = false;
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _hasStream = false;
            _sensorAvailable = false;
          });
        }
      },
    );
    // Some low-end devices expose the stream but never emit an event.
    // If nothing arrives within 2s, fall back to the static bearing view
    // with a clear "no sensor" message instead of a silently frozen dial.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_hasStream) {
        setState(() => _sensorAvailable = false);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  double get _bearing => widget.qibla.degree.toDouble();

  @override
  Widget build(BuildContext context) {
    final heading = _heading;
    final dialAngle = (heading == null ? 0.0 : -heading) * math.pi / 180;
    final arrowAngle = (heading == null ? _bearing : _bearing - heading) * math.pi / 180;
    final isUrdu = widget.isUrdu;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        if (!_sensorAvailable) ...[
          // Clear "no magnetometer" message instead of a silently frozen dial.
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.compass_calibration_outlined, color: Colors.orange, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _noSensorTitle(isUrdu),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _noSensorBody(isUrdu),
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else if (heading != null) ...[
          // Calibration tip for low-end / uncalibrated magnetometers.
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              _calibrationTip(isUrdu),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
        ],
        SizedBox(
          width: widget.size,
          height: widget.size,
          // Isolate the compass graphic into its own paint layer so the
          // ~20 FPS dial rotation never repaints the texts/cards around it.
          child: RepaintBoundary(
            child: Stack(
            alignment: Alignment.center,
            children: [
              // ---- rotating dial ----
              Transform.rotate(
                angle: dialAngle,
                child: CustomPaint(
                  size: Size.square(widget.size),
                  painter: _DialPainter(radius: widget.size / 2, isUrdu: isUrdu),
                ),
              ),
              // ---- qibla arrow ----
              Transform.rotate(
                angle: arrowAngle,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 6,
                    height: widget.size / 2 - 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.0)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              // ---- arrow head (Kaaba marker) ----
              Transform.rotate(
                angle: arrowAngle,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: EdgeInsets.only(top: widget.size / 2 - 52),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.mosque_rounded, color: Color(0xFF1B1203), size: 22),
                  ),
                ),
              ),
              // ---- center hub ----
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.55), width: 2),
                  boxShadow: const [
                    BoxShadow(color: AppColors.shadowSoft, blurRadius: 18, offset: Offset(0, 6)),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${widget.qibla.degree}°',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      _directionLabel(context, widget.qibla.direction),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (heading != null) ...[
          Text(
            '${_headingLabel(context)}  ${heading.toStringAsFixed(0)}°',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
        ] else if (_hasStream) ...[
          Text('…', style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 6),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            '${_kaabaLabel(context)}: ${widget.qibla.distance} km',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ),
      ],
    ),
  );
}

  String _directionLabel(BuildContext context, String direction) {
    if (!widget.isUrdu) return direction;
    switch (direction) {
      case 'North':
        return 'شمال';
      case 'North-East':
        return 'شمال مشرق';
      case 'East':
        return 'مشرق';
      case 'South-East':
        return 'جنوب مشرق';
      case 'South':
        return 'جنوب';
      case 'South-West':
        return 'جنوب مغرب';
      case 'West':
        return 'مغرب';
      case 'North-West':
        return 'شمال مغرب';
      default:
        return direction;
    }
  }

  String _headingLabel(BuildContext context) => widget.isUrdu ? 'شمال' : 'Heading';
  String _kaabaLabel(BuildContext context) => widget.isUrdu ? 'کعبہ کا فاصلہ' : 'Distance to Kaaba';

  String _noSensorTitle(bool isUrdu) => isUrdu
      ? 'قبلہ سینسر دستیاب نہیں'
      : "Qibla sensor not available";

  String _noSensorBody(bool isUrdu) => isUrdu
      ? 'اس فون میں قطب نما (Magnetometer) سینسر نہیں ہے۔ ${widget.qibla.degree}° پر ثابت رخ استعمال کریں — کعبہ کی طرف منہ کریں۔'
      : 'This phone has no compass (Magnetometer) sensor. Use the fixed bearing — face ${widget.qibla.degree}° to face the Kaaba.';

  String _calibrationTip(bool isUrdu) => isUrdu
      ? 'نکٹی کے لیے فون کو 8 کی شکل میں گھمائیں تاکہ قطب نما درست ہو'
      : 'Tip: Move your phone in a figure-8 to calibrate the compass';
}

class _DialPainter extends CustomPainter {
  final double radius;
  final bool isUrdu;
  _DialPainter({required this.radius, this.isUrdu = false});

  // Creating a LinearGradient + shader every paint() call at sensor rate
  // causes GPU allocation churn on low-end devices. Build it once per
  // (radius) and reuse across paints.
  static final Map<double, Shader> _shaderCache = {};

  Shader _ringShader(Offset center) {
    return _shaderCache.putIfAbsent(radius, () {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0B4A3C), Color(0xFF07281F)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final ring = Paint()..shader = _ringShader(center);
    canvas.drawCircle(center, radius, ring);

    final border = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, border);

    final tickMajor = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.9)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final tickMinor = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 72; i++) {
      final angle = (i * 5) * math.pi / 180;
      final isMajor = i % 9 == 0;
      final isMid = i % 18 == 0;
      final inner = isMajor ? radius - 22 : radius - 14;
      final outer = isMajor ? radius - 8 : radius - 8;
      final p1 = center + Offset(math.sin(angle) * inner, -math.cos(angle) * inner);
      final p2 = center + Offset(math.sin(angle) * outer, -math.cos(angle) * outer);
      canvas.drawLine(p1, p2, isMid ? tickMajor : tickMinor);
    }

    final labelStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      color: Colors.white.withValues(alpha: 0.92),
    );
    final offset = radius - 34;
    // Localized compass points (Urdu/Arabic/Persian use native letters).
    final labels = isUrdu
        ? <double, String>{0.0: 'ش', 90.0: 'م', 180.0: 'ج', 270.0: 'غ'}
        : <double, String>{0.0: 'N', 90.0: 'E', 180.0: 'S', 270.0: 'W'};
    labels.forEach((deg, label) {
      final a = deg * math.pi / 180;
      final pos = center + Offset(math.sin(a) * offset, -math.cos(a) * offset);
      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    });
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.isUrdu != isUrdu;
}