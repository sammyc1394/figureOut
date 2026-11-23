import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:figureout/src/config/config.dart';
import 'package:figureout/src/config/theme_mode_scope.dart';

// Flutter-only looping demos for the tutorial screen. They imitate the game
// (sprites, timer bar, attack ring) but do not use the Flame components, which
// are tied to OneSecondGame. Every demo is laid out in a fixed stage size.

const double _stageW = 240;
const double _stageH = 150;
const _mid = Offset(_stageW / 2, _stageH / 2);
const _red = Color(0xFFED613D);
const _green = Color(0xFF78B263);
const _yellow = Color(0xFFF0C400);

enum _Kind {
  circle('Circle', 1, 1),
  triangle('Triangle', 1, 0.9),
  rectangle('Rectangle', 0.5, 1),
  pentagon('Pentagon', 1, 1),
  hexagon('Hexagon', 1, 1);

  const _Kind(this.asset, this.wRatio, this.hRatio);
  final String asset;
  final double wRatio;
  final double hRatio;
}

/// One looping demo: [stage] draws the scene at loop position t (0..1) and
/// [captionKey] picks the translation key shown under it.
class TutorialDemo extends StatefulWidget {
  TutorialDemo({
    super.key,
    required this.ms,
    required this.stage,
    required this.captionKey,
    this.end = 1.0,
  });

  final int ms;
  // Turns true after the first cycle ends; the pager then shows its hint.
  final ValueNotifier<bool> ended = ValueNotifier(false);
  // Fraction of [ms] where the content is done; the cycle then pauses briefly
  // with "Tap to Next" and restarts.
  final double end;
  final List<Widget> Function(double t) stage;
  final String Function(double t) captionKey;

  @override
  State<TutorialDemo> createState() => _TutorialDemoState();
}

class _TutorialDemoState extends State<TutorialDemo>
    with SingleTickerProviderStateMixin {
  static const _pauseMs = 900;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.ms * widget.end).round() + _pauseMs),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ThemeModeScope.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final elapsed = _controller.value * _controller.duration!.inMilliseconds;
        final t = math.min(elapsed / widget.ms, 1.0);
        if (elapsed >= widget.ms * widget.end && !widget.ended.value) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => widget.ended.value = true,
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Swallow taps on the stage so only blank space advances the pager.
            GestureDetector(
              onTap: () {},
              child: AspectRatio(
                aspectRatio: _stageW / _stageH,
                child: FittedBox(
                  child: Container(
                    width: _stageW,
                    height: _stageH,
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: const Color(bgColor),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black26),
                    ),
                    child: Stack(children: widget.stage(t)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              i18n.t(widget.captionKey(t)),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: appFontFamily,
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

double _c01(double v) => v.clamp(0.0, 1.0).toDouble();

/// Progress of t inside [a, b], clamped to 0..1.
double _seg(double t, double a, double b) => _c01((t - a) / (b - a));

/// 0 -> 1 -> 0 triangle wave with period 1.
double _tri(double x) {
  final f = x - x.floorToDouble();
  return f < 0.5 ? f * 2 : 2 - f * 2;
}

/// Short 0..1..0 bump around each time in [times].
double _pulse(double t, List<double> times, [double width = 0.04]) {
  var v = 0.0;
  for (final a in times) {
    v = math.max(v, 1 - _c01((t - a).abs() / width));
  }
  return v;
}

/// Point at fraction u (by length) along a polyline.
Offset _along(List<Offset> pts, double u) {
  final lens = <double>[];
  var total = 0.0;
  for (var i = 0; i < pts.length - 1; i++) {
    final l = (pts[i + 1] - pts[i]).distance;
    lens.add(l);
    total += l;
  }
  var d = _c01(u) * total;
  for (var i = 0; i < lens.length; i++) {
    if (d <= lens[i] || i == lens.length - 1) {
      final f = lens[i] == 0 ? 0.0 : _c01(d / lens[i]);
      return Offset.lerp(pts[i], pts[i + 1], f)!;
    }
    d -= lens[i];
  }
  return pts.last;
}

/// Linear interpolation between (time, point) keyframes.
Offset _keys(double t, List<(double, Offset)> k) {
  if (t <= k.first.$1) return k.first.$2;
  for (var i = 0; i < k.length - 1; i++) {
    if (t <= k[i + 1].$1) {
      return Offset.lerp(k[i].$2, k[i + 1].$2, _seg(t, k[i].$1, k[i + 1].$1))!;
    }
  }
  return k.last.$2;
}

List<Offset> _ellipse(
  Offset c,
  double rx,
  double ry, {
  int n = 48,
  double turns = 1,
  double start = -math.pi / 2,
}) {
  return [
    for (var i = 0; i <= n; i++)
      c +
          Offset(
            math.cos(start + 2 * math.pi * turns * i / n) * rx,
            math.sin(start + 2 * math.pi * turns * i / n) * ry,
          ),
  ];
}

// ---------------------------------------------------------------------------
// drawing blocks
// ---------------------------------------------------------------------------

Widget _shape(
  _Kind kind,
  Offset c, {
  double size = 64,
  double scale = 1,
  double opacity = 1,
  double angle = 0,
  bool dark = false,
  int? hp,
  int? badge,
}) {
  final w = size * kind.wRatio;
  final h = size * kind.hRatio;
  Widget img = Image.asset(
    'assets/shapes/${kind.asset}_3x.png',
    width: w,
    height: h,
    fit: BoxFit.fill,
  );
  if (dark) {
    img = ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.33, 0.33, 0.33, 0, 0, //
        0.33, 0.33, 0.33, 0, 0,
        0.33, 0.33, 0.33, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: img,
    );
  }
  return Positioned(
    left: c.dx - w / 2,
    top: c.dy - h / 2,
    width: w,
    height: h,
    child: Opacity(
      opacity: _c01(opacity),
      child: Transform.rotate(
        angle: angle,
        child: Transform.scale(
          scale: scale,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              img,
              if (hp != null && hp > 0)
                Text(
                  '$hp',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              if (badge != null)
                Positioned(
                  left: -4,
                  top: -4,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFA94D),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$badge',
                      style: TextStyle(
                        fontFamily: appFontFamily,
                        fontSize: badge > 9 ? 12 : 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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

/// Finger sprite whose fingertip sits exactly on [tip]. The sprite's index
/// fingertip is at about (0.09 * width, 0); [press] shrinks the hand around it.
Widget _hand(Offset tip, {double press = 0, double opacity = 1}) {
  const w = 44.0;
  return Positioned(
    left: tip.dx - w * 0.09,
    top: tip.dy - 3, // the sprite's soft top edge sits ~3px above the visible tip
    child: Opacity(
      opacity: _c01(opacity),
      child: Transform.scale(
        scale: 1 - 0.15 * press,
        alignment: const Alignment(-0.82, -1),
        child: Image.asset('assets/tutorial_hand.png', width: w),
      ),
    ),
  );
}

/// Mini version of the game's timer bar, plus an optional "-3"/"+1" note.
List<Widget> _bar(double ratio, {String? note, bool flash = false}) {
  final color = flash || ratio <= 0.25
      ? _red
      : ratio <= 0.5
          ? _yellow
          : _green;
  return [
    Positioned(
      left: 12,
      right: 12,
      top: 10,
      height: 12,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: _c01(ratio),
              heightFactor: 1,
              child: ColoredBox(color: color),
            ),
          ),
        ),
      ),
    ),
    if (note != null)
      Positioned(
        right: 14,
        top: 26,
        child: Text(
          note,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: note.startsWith('-') ? _red : _green,
          ),
        ),
      ),
  ];
}

/// Attack-timer ring drawn around a shape of [size].
Widget _ring(
  Offset c,
  double size,
  double ratio, {
  double opacity = 1,
  Color? color,
}) {
  final d = size + 12;
  return Positioned(
    left: c.dx - d / 2,
    top: c.dy - d / 2,
    width: d,
    height: d,
    child: Opacity(
      opacity: _c01(opacity),
      child: CustomPaint(painter: _RingPainter(ratio, color)),
    ),
  );
}

Widget _trace(
  List<Offset> pts, {
  required Color color,
  double width = 3,
  bool dashed = false,
  double progress = 1,
  double opacity = 1,
}) {
  return Positioned.fill(
    child: Opacity(
      opacity: _c01(opacity),
      child: CustomPaint(
        painter: _TracePainter(
          pts,
          color: color,
          width: width,
          dashed: dashed,
          progress: progress,
        ),
      ),
    ),
  );
}

Widget _guide(List<Offset> pts) =>
    _trace(pts, color: Colors.black26, width: 2, dashed: true);

/// Shakes [content] and flashes the stage red after [hitAt] (forbidden hit).
List<Widget> _shaken(double t, double hitAt, int ms, List<Widget> content) {
  final flash = t >= hitAt ? 1 - _seg(t, hitAt, hitAt + 0.3) : 0.0;
  return [
    Positioned.fill(
      child: Transform.translate(
        offset: Offset(math.sin(t * ms / 1000 * 40) * 6 * flash, 0),
        child: Stack(children: content),
      ),
    ),
    Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(color: _red.withValues(alpha: 0.3 * flash)),
      ),
    ),
  ];
}

/// Hourglass whose sand runs from the top half to the bottom half.
class _HourglassPainter extends CustomPainter {
  _HourglassPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final glass = Path()
      ..moveTo(2, 2)
      ..lineTo(w - 2, 2)
      ..lineTo(w / 2 + 2, h / 2)
      ..lineTo(w - 2, h - 2)
      ..lineTo(2, h - 2)
      ..lineTo(w / 2 - 2, h / 2)
      ..close();
    canvas.save();
    canvas.clipPath(glass);
    final sand = Paint()..color = Colors.grey;
    final half = h / 2 - 2;
    canvas.drawRect(
      Rect.fromLTRB(0, 2 + half * progress, w, h / 2),
      sand,
    );
    canvas.drawRect(
      Rect.fromLTRB(0, h - 2 - half * progress, w, h),
      sand,
    );
    canvas.restore();
    if (progress > 0 && progress < 1) {
      canvas.drawLine(
        Offset(w / 2, h / 2),
        Offset(w / 2, h - 2),
        Paint()
          ..color = Colors.grey
          ..strokeWidth = 1.5,
      );
    }
    canvas.drawPath(
      glass,
      Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_HourglassPainter old) => old.progress != progress;
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.ratio, this.color);

  final double ratio;
  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color ??
          (ratio <= 0.2 ? const Color(0xFFEE0505) : const Color(0xFFA93A1E));
    canvas.drawArc(
      (Offset.zero & size).deflate(2.5),
      -math.pi / 2,
      2 * math.pi * ratio,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ratio != ratio || old.color != color;
}

class _TracePainter extends CustomPainter {
  _TracePainter(
    this.pts, {
    required this.color,
    required this.width,
    required this.dashed,
    required this.progress,
  });

  final List<Offset> pts;
  final Color color;
  final double width;
  final bool dashed;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final m in path.computeMetrics()) {
      final end = m.length * _c01(progress);
      if (!dashed) {
        canvas.drawPath(m.extractPath(0, end), paint);
        continue;
      }
      for (var d = 0.0; d < end; d += 11) {
        canvas.drawPath(m.extractPath(d, math.min(d + 6, end)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_TracePainter old) => true;
}

/// Clips one side of the infinite line through a and b.
class _HalfClipper extends CustomClipper<Path> {
  const _HalfClipper(this.a, this.b, this.positive);

  final Offset a;
  final Offset b;
  final bool positive;

  @override
  Path getClip(Size size) {
    final d = (b - a) / (b - a).distance;
    final n = Offset(-d.dy, d.dx) * (positive ? 1 : -1);
    final p1 = a - d * 400;
    final p2 = b + d * 400;
    return Path()..addPolygon([p1, p2, p2 + n * 400, p1 + n * 400], true);
  }

  @override
  bool shouldReclip(_HalfClipper old) =>
      old.a != a || old.b != b || old.positive != positive;
}

// ---------------------------------------------------------------------------
// shapes
// ---------------------------------------------------------------------------

TutorialDemo circleDemo() => TutorialDemo(
      ms: 4000,
      end: 0.75,
      captionKey: (_) => 'tutorial_circle',
      stage: (t) {
        const taps = [0.2, 0.4, 0.6];
        final hp = 3 - taps.where((a) => t >= a).length;
        final pop = _seg(t, 0.6, 0.72);
        return [
          if (t < 0.72)
            _shape(
              _Kind.circle,
              _mid,
              size: 70,
              hp: hp,
              scale: 1 + 0.4 * pop,
              opacity: 1 - pop,
            ),
          _hand(
            _mid,
            press: _pulse(t, taps),
            opacity: t < 0.72 ? 1 : 0,
          ),
        ];
      },
    );

TutorialDemo triangleDemo() => TutorialDemo(
      ms: 5000,
      end: 0.72,
      captionKey: (_) => 'tutorial_triangle',
      stage: (t) {
        const size = 80.0;
        const w = size;
        const h = size * 0.9;
        const c = _mid; // centre of the sprite's bounding box
        // Sprite geometry (svg 96x86): top (48, 3.5), base corners at y 78.5.
        final top = Offset(c.dx, c.dy - h / 2 + h * 3.5 / 86);
        final left = Offset(c.dx - w / 2 + w * 2.1 / 96, c.dy - h / 2 + h * 78.5 / 86);
        final right = Offset(c.dx - w / 2 + w * 93.9 / 96, left.dy);
        // Centroid of the triangle; the loop circles around it.
        final g = Offset(
          (top.dx + left.dx + right.dx) / 3,
          (top.dy + left.dy + right.dy) / 3,
        );
        final r = [top, left, right].map((v) => (v - g).distance).reduce(math.max) + 14;
        final loop = _ellipse(g, r, r, turns: 1.05);
        final p = _seg(t, 0.1, 0.55);
        final gone = _seg(t, 0.55, 0.7);
        return [
          if (t < 0.7)
            _shape(
              _Kind.triangle,
              c,
              size: size,
              scale: 1 + 0.3 * gone,
              opacity: 1 - gone,
            ),
          _trace(
            loop,
            color: const Color(0xFFF2AC32),
            progress: p,
            opacity: 1 - gone,
          ),
          _hand(_along(loop, p), opacity: t > 0.08 && t < 0.6 ? 1 : 0),
        ];
      },
    );

TutorialDemo rectangleDemo() => TutorialDemo(
      ms: 5000,
      end: 0.77,
      captionKey: (_) => 'tutorial_rectangle',
      stage: (t) {
        const a = Offset(76, 48);
        const b = Offset(164, 106);
        final p = _seg(t, 0.1, 0.4);
        final q = _seg(t, 0.4, 0.75);
        Widget rect() => _shape(_Kind.rectangle, _mid, size: 100);
        Widget half(bool positive) {
          final d = (b - a) / (b - a).distance;
          final n = Offset(-d.dy, d.dx) * (positive ? 1 : -1);
          return Positioned.fill(
            child: Transform.translate(
              offset: n * (16 * q) + Offset(0, 36 * q * q),
              child: Opacity(
                opacity: 1 - q,
                child: ClipPath(
                  clipper: _HalfClipper(a, b, positive),
                  child: Stack(children: [rect()]),
                ),
              ),
            ),
          );
        }

        return [
          if (t < 0.4) rect(),
          if (t >= 0.4 && t < 0.75) ...[half(true), half(false)],
          if (t < 0.75)
            _trace([a, b], color: Colors.black87, progress: p, opacity: 1 - q),
          _hand(Offset.lerp(a, b, p)!, opacity: t > 0.08 && t < 0.45 ? 1 : 0),
        ];
      },
    );

TutorialDemo pentagonDemo() => TutorialDemo(
      ms: 6000,
      end: 0.65,
      captionKey: (_) => 'tutorial_pentagon',
      stage: (t) {
        // First tick is the long-press start, then one per second.
        const ticks = [0.18, 0.347, 0.513];
        final hp = 3 - ticks.where((a) => t >= a).length;
        final holding = t >= 0.18 && t < 0.513;
        final pop = _seg(t, 0.513, 0.63);
        final touching = t >= 0.08 && t < 0.55;
        return [
          if (t < 0.63)
            _shape(
              _Kind.pentagon,
              _mid,
              size: 80,
              hp: hp,
              angle: holding ? math.sin(t * 6 * 45) * 0.07 : 0,
              scale: 1 + 0.4 * pop,
              opacity: 1 - pop,
            ),
          _hand(
            _mid + const Offset(0, 6),
            press: touching ? 1 : 0,
            opacity: touching ? 1 : 0,
          ),
        ];
      },
    );

TutorialDemo hexagonDemo() => TutorialDemo(
      ms: 7000,
      end: 0.8,
      captionKey: (_) => 'tutorial_hexagon',
      stage: (t) {
        // Pull to one side a little, let go (shrinks back, HP restores), then
        // pull all the way in one drag. d is how far the finger has pulled (0..1).
        // The hexagon sits left of centre so the pull has room on the right.
        const hc = Offset(90, 75);
        final double d;
        final double s;
        if (t < 0.05) {
          d = 0;
          s = 1;
        } else if (t < 0.2) {
          d = 0.77 * _seg(t, 0.05, 0.2);
          s = 1 + 0.65 * d;
        } else if (t < 0.32) {
          d = 0;
          s = 1.5 - 0.5 * _seg(t, 0.2, 0.32);
        } else if (t < 0.4) {
          d = 0;
          s = 1;
        } else {
          d = _seg(t, 0.4, 0.65);
          s = 1 + 0.65 * d;
        }
        final hp = 3 - ((s - 1) / 0.2).floor().clamp(0, 3).toInt();
        final dragging = (t >= 0.05 && t < 0.2) || (t >= 0.4 && t < 0.65);
        final pop = _seg(t, 0.65, 0.78);
        final grab = Offset(hc.dx + 25, hc.dy);
        final tip = Offset(grab.dx + 80 * d, grab.dy);
        const pull = Color(0xFF398A63);
        return [
          if (t < 0.78)
            _shape(
              _Kind.hexagon,
              hc,
              size: 70,
              hp: hp,
              scale: s * (1 + 0.15 * pop),
              opacity: 1 - pop,
            ),
          // "-----" line from the grab point to the finger, with an arrow head.
          if (dragging && d > 0.02) ...[
            _trace([grab, tip], color: pull, width: 4),
            _trace(
              [tip + const Offset(-9, -7), tip, tip + const Offset(-9, 7)],
              color: pull,
              width: 4,
            ),
          ],
          _hand(tip, press: 1, opacity: dragging ? 1 : 0),
        ];
      },
    );

TutorialDemo darkDemo() => TutorialDemo(
      ms: 4000,
      end: 0.8,
      captionKey: (_) => 'tutorial_dark',
      stage: (t) {
        final hit = t >= 0.3 && t < 0.6;
        return [
          ..._shaken(t, 0.3, 4000, [
            ..._bar(
              0.8 - 0.15 * _seg(t, 0.3, 0.4),
              note: t >= 0.3 && t < 0.75 ? '-10' : null,
              flash: hit,
            ),
            _shape(
              _Kind.circle,
              _mid + const Offset(0, 14),
              size: 64,
              dark: true,
            ),
          ]),
          _hand(
            _mid + const Offset(0, 14),
            press: _pulse(t, const [0.3]),
            opacity: t > 0.12 && t < 0.5 ? 1 : 0,
          ),
        ];
      },
    );

// ---------------------------------------------------------------------------
// movement
// ---------------------------------------------------------------------------

/// D(a,b) blink: fade in over the first 40% of the visible time, hold 20%,
/// fade out 40%, then stay hidden. [u] is the position in one cycle (0..1).
double _blink(double u, double visibleFrac) {
  if (u >= visibleFrac) return 0;
  final p = u / visibleFrac;
  final f = p < 0.4 ? p / 0.4 : (p > 0.6 ? (1 - p) / 0.4 : 1.0);
  return f * f * (3 - 2 * f);
}

List<TutorialDemo> movementDemos() {
  const a = Offset(40, 110);
  const b = Offset(110, 40);
  const c = Offset(200, 100);
  const route = [a, b, c];
  const loop = [a, b, c, a];
  const left = Offset(40, 75);
  const right = Offset(200, 75);

  Widget dot(Offset p, {double scale = 1, double opacity = 1}) =>
      _shape(_Kind.circle, p, size: 40, scale: scale, opacity: opacity);

  TutorialDemo demo(String key, int ms, List<Widget> Function(double t) stage,
          {double end = 1.0}) =>
      TutorialDemo(ms: ms, end: end, captionKey: (_) => key, stage: stage);

  return [
    // Z: a straight leg to the point, stops there.
    demo('tutorial_move_line', 5000, (t) => [
          _guide(const [a, c]),
          dot(_along(const [a, c], _seg(t, 0.1, 0.9))),
        ], end: 0.9),
    // Z + Repeat: after the last leg it returns to the spawn point and loops.
    demo('tutorial_move_repeat', 9000, (t) => [
          _guide(loop),
          dot(_along(loop, (t * 2) % 1)),
        ]),
    // Z + Back: retraces the path leg by leg.
    demo('tutorial_move_back', 9000, (t) => [
          _guide(route),
          dot(_along(route, _tri(t * 2))),
        ]),
    // L: endless back and forth between two points.
    demo('tutorial_move_shuttle', 6000, (t) => [
          _guide(const [left, right]),
          dot(_along(const [left, right], _tri(t * 2))),
        ]),
    // B: bounces off the play-area walls.
    demo('tutorial_move_bounce', 6000, (t) => [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26, width: 2),
                ),
              ),
            ),
          ),
          dot(Offset(40 + 160 * _tri(t * 2 + 0.1), 40 + 70 * _tri(t * 3 + 0.3))),
        ]),
    // C: orbits around the spawn point, starting at its right side.
    demo('tutorial_move_orbit', 8000, (t) => [
          _guide(_ellipse(const Offset(120, 75), 45, 45, n: 60, start: 0)),
          Positioned(
            left: 117,
            top: 72,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
            ),
          ),
          dot(Offset(
            120 + 45 * math.cos(4 * math.pi * t),
            75 + 45 * math.sin(4 * math.pi * t),
          )),
        ]),
    // M: pops in at the spawn point, then moves in a straight line.
    demo('tutorial_move_drop', 4000, (t) {
      const top = Offset(120, 28);
      const bottom = Offset(120, 125);
      return [
        _guide(const [top, bottom]),
        dot(
          Offset.lerp(top, bottom, _seg(t, 0.25, 0.85))!,
          scale: _seg(t, 0, 0.2),
        ),
      ];
    }, end: 0.85),
    // P: launched from below the screen, falls back out of the bottom; a
    // normal shape that is missed costs time.
    demo('tutorial_move_launch', 5000, (t) {
      Offset at(double u) => Offset(40 + 160 * u, 190 - 520 * u * (1 - u));
      final u = _seg(t, 0.05, 0.75);
      return [
        _guide([for (var i = 0; i <= 40; i++) at(i / 40)]),
        if (u < 1) dot(at(u)),
        ..._bar(
          0.8 - 0.15 * _seg(t, 0.75, 0.8),
          note: t >= 0.75 && t < 0.95 ? '-3' : null,
          flash: t >= 0.75 && t < 0.85,
        ),
      ];
    }, end: 0.95),
    // D: blinks in place (2s visible, 1s hidden), two cycles.
    demo('tutorial_move_blink', 6000, (t) => [
          dot(_mid, opacity: _blink((t * 2) % 1, 2 / 3)),
        ]),
    // DR: like D, but each new cycle starts at a random spot.
    demo('tutorial_move_blink_random', 9000, (t) {
      const spots = [Offset(60, 50), Offset(180, 60), Offset(110, 110)];
      final k = (t * 3).floor().clamp(0, 2).toInt();
      return [dot(spots[k], opacity: _blink((t * 3) % 1, 2 / 3))];
    }),
    // Wait n: visible at the spawn point, starts moving after n seconds.
    demo('tutorial_move_wait', 6000, (t) => [
          _guide(const [left, right]),
          dot(Offset.lerp(left, right, _seg(t, 0.45, 0.9))!),
          if (t < 0.45)
            Positioned(
              left: 31,
              top: 20,
              width: 18,
              height: 26,
              child: CustomPaint(painter: _HourglassPainter(_seg(t, 0.05, 0.45))),
            ),
        ], end: 0.9),
    // Disappear(n): fades out after n seconds and leaves, no penalty.
    demo('tutorial_move_vanish', 5000, (t) => [
          dot(_mid, opacity: 1 - _seg(t, 0.55, 0.8)),
        ], end: 0.8),
    // S(start,end,sec): linear size change.
    demo('tutorial_move_size', 4000, (t) => [
          dot(_mid, scale: 0.6 + _seg(t, 0.1, 0.9)),
        ], end: 0.9),
  ];
}

// ---------------------------------------------------------------------------
// timer
// ---------------------------------------------------------------------------

const _timerShape = Offset(_stageW / 2, 96);

/// Bar intro, then the ring runs out: the shape explodes and the bar loses time.
TutorialDemo timerFailDemo() => TutorialDemo(
      ms: 9000,
      end: 0.95,
      captionKey: (t) => t < 0.15
          ? 'tutorial_timer_bar'
          : t < 0.7
              ? 'tutorial_timer_ring'
              : 'tutorial_timer_fail',
      stage: (t) {
        final ratio = 1 - _seg(t, 0.15, 0.7);
        final boom = _seg(t, 0.7, 0.82);
        return [
          ..._bar(
            0.8 - 0.15 * _seg(t, 0.7, 0.78),
            note: t >= 0.7 && t < 0.95 ? '-3' : null,
            flash: t >= 0.7 && t < 0.88,
          ),
          if (t < 0.7) ...[
            _shape(_Kind.circle, _timerShape, size: 60, hp: 1),
            _ring(_timerShape, 60, ratio),
          ],
          if (t >= 0.7 && t < 0.82)
            _ring(_timerShape, 60 + 90 * boom, 1, opacity: 1 - boom, color: _red),
        ];
      },
    );

/// The shape is tapped away before its ring runs out.
TutorialDemo timerClearDemo() => TutorialDemo(
      ms: 6000,
      end: 0.9,
      captionKey: (_) => 'tutorial_timer_clear',
      stage: (t) {
        final pop = _seg(t, 0.5, 0.62);
        return [
          ..._bar(
            0.8 + 0.05 * _seg(t, 0.5, 0.6),
            note: t >= 0.5 && t < 0.9 ? '+1' : null,
          ),
          if (t < 0.62)
            _shape(
              _Kind.circle,
              _timerShape,
              size: 60,
              hp: t < 0.5 ? 1 : 0,
              scale: 1 + 0.4 * pop,
              opacity: 1 - pop,
            ),
          if (t < 0.5) _ring(_timerShape, 60, 1 - 0.65 * _seg(t, 0, 0.45)),
          _hand(
            _timerShape,
            press: _pulse(t, const [0.5]),
            opacity: t > 0.35 && t < 0.62 ? 1 : 0,
          ),
        ];
      },
    );

// ---------------------------------------------------------------------------
// order
// ---------------------------------------------------------------------------

const _orderPos = [Offset(50, 96), Offset(120, 96), Offset(190, 96)];
const _orderNum = [7, 13, 3];

/// Taps 7 although 3 is still there: forbidden hit, the bar loses time.
TutorialDemo orderWrongDemo() => TutorialDemo(
      ms: 6000,
      end: 0.8,
      captionKey: (_) => 'tutorial_order_wrong',
      stage: (t) => [
        ..._shaken(t, 0.3, 6000, [
          ..._bar(
            0.8 - 0.15 * _seg(t, 0.3, 0.4),
            note: t >= 0.3 && t < 0.8 ? '-3' : null,
            flash: t >= 0.3 && t < 0.6,
          ),
          for (var i = 0; i < 3; i++)
            _shape(_Kind.circle, _orderPos[i], size: 56, hp: 1, badge: _orderNum[i]),
        ]),
        _hand(
          _orderPos[0],
          press: _pulse(t, const [0.3]),
          opacity: t > 0.12 && t < 0.5 ? 1 : 0,
        ),
      ],
    );

/// Taps 3, 7, 13 (smallest first) and each one pops.
TutorialDemo orderRightDemo() => TutorialDemo(
      ms: 8000,
      end: 0.88,
      captionKey: (_) => 'tutorial_order_right',
      stage: (t) {
        const taps = [0.2, 0.5, 0.78];
        // Circle index tapped 1st, 2nd, 3rd (numbers 3, 7, 13).
        const order = [2, 0, 1];
        double popAt(int i) => taps[order.indexOf(i)];
        final tip = _keys(t, [
          (0.05, _orderPos[2]),
          (0.25, _orderPos[2]),
          (0.4, _orderPos[0]),
          (0.55, _orderPos[0]),
          (0.65, _orderPos[1]),
          (0.82, _orderPos[1]),
        ]);
        return [
          ..._bar(0.8),
          for (var i = 0; i < 3; i++)
            if (t < popAt(i) + 0.1)
              _shape(
                _Kind.circle,
                _orderPos[i],
                size: 56,
                hp: t < popAt(i) ? 1 : 0,
                badge: _orderNum[i],
                scale: 1 + 0.4 * _seg(t, popAt(i), popAt(i) + 0.1),
                opacity: 1 - _seg(t, popAt(i), popAt(i) + 0.1),
              ),
          _hand(
            tip,
            press: _pulse(t, taps),
            opacity: t > 0.05 && t < 0.85 ? 1 : 0,
          ),
        ];
      },
    );

// ---------------------------------------------------------------------------
// demo lists, one per tutorial tab (shown one at a time)
// ---------------------------------------------------------------------------

List<TutorialDemo> shapeDemos() =>
    [circleDemo(), triangleDemo(), rectangleDemo(), pentagonDemo(), hexagonDemo()];

List<TutorialDemo> darkDemos() => [darkDemo()];

List<TutorialDemo> timerDemos() => [timerFailDemo(), timerClearDemo()];

List<TutorialDemo> orderDemos() => [orderWrongDemo(), orderRightDemo()];
