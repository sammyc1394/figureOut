import 'dart:math';
import 'dart:ui';

import 'package:figureout/src/functions/UserRemovable.dart';
import 'package:figureout/src/functions/BlinkingBehavior.dart';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_svg/flame_svg.dart';
import '../functions/DepthAware.dart';
import 'package:flutter/material.dart' hide Matrix4;

import '../effect/AttackExplosionEffect.dart';

class PentagonShape extends PositionComponent
    with HasPaint, TapCallbacks, UserRemovable, HasGameReference<FlameGame>, DepthAware {

  int energy;
  bool _isLongPressing = false;

  late final SvgComponent svg;
  late final SpriteComponent _png;

  final bool isDark;
  final VoidCallback? onForbiddenTouch;
  final double? attackTime;
  final VoidCallback? onExplode;
  final int? order;
  final BlendMode blendMode;

  bool isPaused = false;

  double _attackElapsed = 0;
  bool _attackDone = false;
  bool _penaltyFired = false;

  // ===============================
  // BLINK
  // ===============================

  double _blinkAlpha = 1.0;

  bool get _usesPngLayer => (attackTime ?? 0) > 0;

  @override
  void updateVisualsByRank(double rank) {
    const targetOpacity = 1.0;
    final darkness = rank;

    final filter = ColorFilter.matrix([
      darkness, 0, 0, 0, 0,
      0, darkness, 0, 0, 0,
      0, 0, darkness, 0, 0,
      0, 0, 0, 1, 0,
    ]);

    svg.paint.blendMode = BlendMode.srcOver;
    _png.paint.blendMode = BlendMode.srcOver;
    svg.paint.colorFilter = filter;
    _png.paint.colorFilter = filter;

    if (_usesPngLayer) {
      svg.opacity = 0;
      _png.opacity = _blinkAlpha * targetOpacity;
    } else {
      svg.opacity = _blinkAlpha * targetOpacity;
      _png.opacity = 0;
    }
  }

  @override
  void updateVisualsByPriority() {
    updateVisualsByRank(1.0);
  }

  void setBlinkAlpha(double alpha) {
    _blinkAlpha = alpha.clamp(0.0, 1.0);

    if (_usesPngLayer) {
      svg.opacity = 0;
      _png.opacity = _blinkAlpha;
    } else {
      svg.opacity = _blinkAlpha;
      _png.opacity = 0;
    }
  }

  // ===============================
  // LONG PRESS
  // ===============================

  double _pressElapsed = 0.0;
  static const double _pressTick = 1.0;
  Vector2? _frozenPosition;

  // ===============================
  // PULSE
  // ===============================

  static const Color _pulseColor = Color(0xFFFF6AD5);

  static const double _pulseMaxThickness = 18.0;
  static const double _pulseAppearTime = 0.10;
  static const double _pulseDisappearTime = 0.12;
  static const double _pulseCycleSeconds = 0.36;

  double _pulseThicknessT = 0.0;
  double _pulsePhase = 0.0;

  // ===============================
  // GEOMETRY
  // ===============================

  late Offset _center;
  late double _baseRadius;

  // ===============================
  // TOP CIRCLE
  // ===============================

  static const double _circleRadius = 18;
  static const int _circleSegments = 44;
  static const int _circleSeed = 999;

  final Paint _circlePaint = Paint()
    ..style = PaintingStyle.fill
    ..color = const Color(0xFFFFA6FC);

  // ===============================
  // ATTACK
  // ===============================

  final Paint _attackPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6
    ..color = const Color(0xFFFFA6FC);

  late Path _pentagonPath;
  late double _perimeter;

  final Color baseColor = const Color(0xFFFFA6FC);
  final Color dangerColor = const Color(0xFFEE0505);

  PentagonShape(
    Vector2 position,
    this.energy, {
    this.isDark = false,
    this.onForbiddenTouch,
    this.attackTime,
    this.onExplode,
    Vector2? customSize,
    this.order,
    this.blendMode = BlendMode.srcOver,
  }) : super(
          position: position,
          size: customSize ?? Vector2.all(100),
          anchor: Anchor.center,
        );

  Offset get _visualPentagonCenter => Offset(
        size.x / 2 - size.x * 0.04,
        size.y / 2 + size.y * 0.04,
      );

  @override
  Future<void> onLoad() async {

    priority = 100 + (1000 - size.x).toInt();

    await super.onLoad();

    final svgData =
        await Svg.load(isDark ? 'Pentagon_dark.svg' : 'Pentagon_basic.svg');

    svg = SvgComponent(
      svg: svgData,
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );

    add(svg);

    final img = await Images(prefix: 'assets/').load('shapes/Pentagon.png');

    _png = SpriteComponent(
      sprite: Sprite(img),
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    )..opacity = 0
     ..paint.blendMode = blendMode;

    add(_png);

    if (_usesPngLayer) {
      svg.opacity = 0;
      _png.opacity = 1;
    }

    _center = _visualPentagonCenter;

    _baseRadius = size.x * 0.392;

    _pentagonPath = _buildPentagonPath(_center, _baseRadius);

    _perimeter =
        _pentagonPath.computeMetrics().fold(0.0, (s, m) => s + m.length);

    updateVisualsByPriority();
  }

  // ===============================
  // UPDATE
  // ===============================

  @override
  void update(double dt) {

    if (_isLongPressing && _frozenPosition != null) {
      position.setFrom(_frozenPosition!);
    }

    super.update(dt);

    if (_isLongPressing && _frozenPosition != null) {
      position.setFrom(_frozenPosition!);
    }


    if (isPaused) return;

    if (_isLongPressing && !isDark) {

      if (_pulseThicknessT < 1.0) {
        _pulseThicknessT += dt / _pulseAppearTime;
      }

      _pulsePhase += dt / _pulseCycleSeconds;

      _pulsePhase -= _pulsePhase.floorToDouble();

      _pressElapsed += dt;

      if (_pressElapsed >= _pressTick) {

        _pressElapsed -= _pressTick;

        energy--;

        if (energy <= 0) {

          wasRemovedByUser = true;

          removeFromParent();

          return;
        }
      }
    } else {

      if (_pulseThicknessT > 0.0) {
        _pulseThicknessT -= dt / _pulseDisappearTime;
      }

      _pressElapsed = 0.0;
    }

    if ((attackTime ?? 0) > 0) {

      _attackElapsed += dt;

      if (!_attackDone && _attackElapsed >= attackTime!) {

        _attackDone = true;

        if (!_penaltyFired) {
          _penaltyFired = true;
          onExplode?.call();
        }

        wasRemovedByUser = false;

        parent?.add(
          AttackExplosionEffect(
            basePath: _buildExplosionPentagonPath(),
            position: position.clone(),
            size: size.clone(),
            color: const Color(0xFFC100BA),
          ),
        );

        removeFromParent();

        return;
      }
    }
  }

  // ===============================
  // RENDER
  // ===============================

  @override
  void render(Canvas canvas) {

    super.render(canvas);

    if (!isDark && _pulseThicknessT > 0.0) {

      final totalThickness = _pulseMaxThickness * _pulseThicknessT;

      final bandW = totalThickness / 2.5;

      for (int i = 0; i < 3; i++) {

        final innerR = _baseRadius + bandW * i;
        final outerR = innerR + bandW;

        final ring = _buildRingEvenOdd(_center, innerR, outerR);

        final phase = (_pulsePhase + i / 3.0) % 1.0;

        final tri = phase < 0.5 ? (phase * 2.0) : (2.0 - phase * 2.0);

        final smooth = tri * tri * (3 - 2 * tri);

        final opacity = lerpDouble(0.10, 0.34, smooth)!;

        final paint = Paint()
          ..style = PaintingStyle.fill
          ..color = _pulseColor.withOpacity(
              opacity * _pulseThicknessT * _blinkAlpha);

        canvas.drawPath(ring, paint);
      }
    }

    if (_isLongPressing && !isDark && energy > 0) {

      final c = _visualPentagonCenter
          .translate(-size.x * 0.035, -size.y * 0.7);

      canvas.drawPath(
        _buildHandDrawnCircle(c, _circleRadius, _circleSeed),
        _circlePaint,
      );

      _drawText(canvas, energy.toString(), c, 14, Colors.white);
    }

    if ((attackTime ?? 0) > 0 && !_attackDone) {

      final ratio =
          ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);

      _attackPaint.color =
          (ratio <= 0.2 ? dangerColor : baseColor)
              .withOpacity(_blinkAlpha);

      canvas.drawPath(
        _extractPartialPath(_pentagonPath, _perimeter * ratio),
        _attackPaint,
      );
    }

    if (!isDark && energy > 0) {

      _drawText(
        canvas,
        energy.toString(),
        _visualPentagonCenter,
        20,
        const Color(0xFFC100BA).withOpacity(_blinkAlpha),
      );
    }
  }

  // ===============================
  // GEOMETRY
  // ===============================

  Path _buildPentagonPath(Offset c, double r) {

    final path = Path();

    for (int i = 0; i < 5; i++) {

      final a = (-90 + i * 72) * pi / 180;

      final p = Offset(
        c.dx + cos(a) * r,
        c.dy + sin(a) * r,
      );

      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    path.close();

    return path;
  }

  Path _buildRingEvenOdd(
      Offset c,
      double innerR,
      double outerR,
      ) {

    final outer = _buildPentagonPath(c, outerR);
    final inner = _buildPentagonPath(c, innerR);

    final ring = Path()..fillType = PathFillType.evenOdd;

    ring.addPath(outer, Offset.zero);
    ring.addPath(inner, Offset.zero);

    return ring;
  }

  Path _extractPartialPath(Path p, double len) {

    final r = Path();

    double rem = len;

    for (final m in p.computeMetrics()) {

      if (rem <= 0) break;

      final l = rem.clamp(0.0, m.length);

      r.addPath(m.extractPath(0, l), Offset.zero);

      rem -= l;
    }

    return r;
  }

  Path _buildHandDrawnCircle(
      Offset c,
      double r,
      int seed,
      ) {

    final rand = Random(seed);

    final path = Path();

    for (int i = 0; i <= _circleSegments; i++) {

      final a = (i / _circleSegments) * pi * 2;

      final wobble = (rand.nextDouble() - 0.5) * 1.6;

      final rr = r + wobble;

      final p = Offset(
        c.dx + cos(a) * rr,
        c.dy + sin(a) * rr,
      );

      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    path.close();

    return path;
  }

  void _drawText(
      Canvas c,
      String t,
      Offset o,
      double s,
      Color col,
      ) {

    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          fontSize: s,
          fontWeight: FontWeight.bold,
          color: col,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
        c,
        Offset(
          o.dx - tp.width / 2,
          o.dy - tp.height * 0.52,
        ));
  }

  // ===============================
  // INPUT
  // ===============================

  @override
  void onTapDown(TapDownEvent e) {
    e.continuePropagation = false;
    if (isDark) onForbiddenTouch?.call();

    _frozenPosition = position.clone();
    children.whereType<Effect>().forEach((effect) => effect.pause());
    _myBlinking()?.isPaused = true;
  }

  @override
  void onLongTapDown(TapDownEvent e) {

    if (isDark) {

      onForbiddenTouch?.call();

      return;
    }

    _isLongPressing = true;

    _pulseThicknessT = 0.0;
    _pulsePhase = 0.0;
    _pressElapsed = 0.0;

    energy--;
    if (energy <= 0) {
      wasRemovedByUser = true;
      removeFromParent();
      return;
    }
  }

  @override
  void onTapUp(TapUpEvent e) {

    _isLongPressing = false;
    _frozenPosition = null;
    _myBlinking()?.isPaused = false;
  }

  BlinkingBehaviorComponent? _myBlinking() {

    for (final b
        in game.children.whereType<BlinkingBehaviorComponent>()) {

      if (identical(b.shape, this)) return b;
    }

    return null;
  }

  Path _buildExplosionPentagonPath() {

    final w = size.x;
    final h = size.y;

    return Path()
      ..moveTo(w / 2, 0)
      ..lineTo(0, h * 0.4)
      ..lineTo(w * 0.2, h)
      ..lineTo(w * 0.8, h)
      ..lineTo(w, h * 0.4)
      ..close();
  }
}