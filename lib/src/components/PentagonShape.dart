import 'dart:math';
import 'dart:ui';

import 'package:figureout/src/functions/UserRemovable.dart';
import 'package:figureout/src/functions/BlinkingBehavior.dart';
import 'package:figureout/src/functions/blink_alpha_target.dart';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' hide Matrix4;

import '../effect/AttackExplosionEffect.dart';
import '../functions/OverlapHighlightable.dart';
import 'shape_path_utils.dart';

class PentagonShape extends PositionComponent
    with HasPaint, TapCallbacks, UserRemovable, HasGameReference<FlameGame>, OverlapHighlightable, BlinkAlphaTarget {

  static final _images = Images(prefix: 'assets/');

  int energy;
  TextComponent? _hpTextComponent;
  bool _isLongPressing = false;

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

  final Paint _overlapOutlinePaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;

  void setBlinkAlpha(double alpha) {
    _blinkAlpha = alpha.clamp(0.0, 1.0);

    _hpTextComponent?.textRenderer = TextPaint(
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black.withValues(alpha: _blinkAlpha)),
    );
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
    ..color = const Color(0xFFF6B4B9);

  // ===============================
  // ATTACK
  // ===============================

  final Paint _attackPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6
    ..color = const Color(0xFFF6B4B9);

  late Sprite _sprite;
  late Path _pentagonPath;
  late Path _wobblePath;
  late double _perimeter;

  late Path _attackBorderPath;
  late double _attackBorderPerimeter;

  final Color baseColor = const Color(0xFFC96C72);
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
    // z-order(priority)는 스폰 시 생성 순서 기반으로 설정된다. (크기 무관)
    await super.onLoad();

    _center = _visualPentagonCenter;

    _baseRadius = size.x * 0.42;

    _sprite = await Sprite.load('shapes/Pentagon_3x.png', images: _images);
    _pentagonPath = _buildPentagonPath(_center, _baseRadius);

    _perimeter =
        _pentagonPath.computeMetrics().fold(0.0, (s, m) => s + m.length);
    _wobblePath = ShapePathUtils.wobble(_pentagonPath, amplitude: size.x * 0.009);

    final attackCenter = Offset(size.x / 2, size.y / 2 + size.y * 0.04);
    _attackBorderPath = _buildPentagonPath(attackCenter, size.x * 0.50);
    _attackBorderPerimeter =
        _attackBorderPath.computeMetrics().fold(0.0, (s, m) => s + m.length);

    if (!isDark && energy >= 1) {
      _hpTextComponent = TextComponent(
        text: energy.toString(),
        anchor: Anchor.center,
        position: Vector2(_visualPentagonCenter.dx, _visualPentagonCenter.dy),
        priority: 999,
        textRenderer: TextPaint(
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      );
      add(_hpTextComponent!);
    }
  }

  // ===============================
  // UPDATE
  // ===============================

  @override
  void update(double dt) {

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

        if (energy >= 1) {
          _hpTextComponent?.text = energy.toString();
        } else {
          _hpTextComponent?.removeFromParent();
          _hpTextComponent = null;
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
            color: const Color(0xFFF3ACB1),
            maxScale: 6.0,
            ringSpacing: 0.45,
            maxRings: 9,
            strokeMaxWidth: 0.9,
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
  bool containsLocalPoint(Vector2 point) {
    final cx = size.x / 2 - size.x * 0.04;
    final cy = size.y / 2 + size.y * 0.04;
    final r = size.x * 0.392;
    final pts = List.generate(5, (i) {
      final a = (-90 + i * 72) * pi / 180;
      return Vector2(cx + cos(a) * r, cy + sin(a) * r);
    });
    return _pointInPolygon(point, pts);
  }

  bool _pointInPolygon(Vector2 p, List<Vector2> poly) {
    int count = 0;
    for (int i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      if (((a.y > p.y) != (b.y > p.y)) &&
          (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y + 0.0001) + a.x)) {
        count++;
      }
    }
    return count.isOdd;
  }

  static const double _borderHalo = 0.05;

  @override
  void render(Canvas canvas) {
    _sprite.render(
      canvas,
      position: Vector2(-size.x * _borderHalo / 2, -size.y * _borderHalo / 2),
      size: size * (1 + _borderHalo),
      overridePaint: Paint()
        ..colorFilter = ColorFilter.mode(
          Color.fromARGB((_blinkAlpha * 255).round(), 0xE4, 0xE0, 0xD3),
          BlendMode.srcIn,
        ),
    );

    _sprite.render(
      canvas,
      size: size,
      overridePaint: isDark
          ? (Paint()
              ..blendMode = blendMode
              ..colorFilter = ColorFilter.matrix([
                0.20, 0.20, 0.20, 0, 0,
                0.20, 0.20, 0.20, 0, 0,
                0.20, 0.20, 0.20, 0, 0,
                0, 0, 0, _blinkAlpha, 0,
              ]))
          : (Paint()
              ..blendMode = blendMode
              ..colorFilter = ColorFilter.mode(
                Color.fromARGB((_blinkAlpha * 255).round(), 255, 255, 255),
                BlendMode.modulate,
              )),
    );

    // if ((attackTime ?? 0) > 0 && !_attackDone) {
    //   final ratio =
    //       ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);
    //
    //   if (ratio <= 0.2) {
    //     canvas.drawPath(
    //       _wobblePath,
    //       Paint()
    //         ..color = dangerColor.withValues(alpha: _blinkAlpha * 0.5)
    //         ..style = PaintingStyle.fill
    //         ..blendMode = BlendMode.srcATop,
    //     );
    //   }
    // }

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
          ..color = _pulseColor.withValues(
            alpha: opacity * _pulseThicknessT * _blinkAlpha,
          );

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
              .withValues(alpha: _blinkAlpha);

      canvas.drawPath(
        ShapePathUtils.extractPartial(_attackBorderPath, _attackBorderPerimeter * ratio),
        _attackPaint,
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

    _hpTextComponent?.text = energy.toString();
  }

  @override
  void onTapUp(TapUpEvent e) {

    _isLongPressing = false;
    _frozenPosition = null;
    children.whereType<Effect>().forEach((effect) => effect.resume());
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

