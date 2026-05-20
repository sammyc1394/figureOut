import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:figureout/src/functions/UserRemovable.dart';
import 'package:figureout/src/functions/blink_alpha_target.dart';
import 'dart:math' as math;

import '../effect/AttackExplosionEffect.dart';
import '../functions/OverlapHighlightable.dart';
import 'shape_path_utils.dart';

enum HexagonState {
  normal,
  autoGrowing,
  disappearing,
}

class HexagonShape extends PositionComponent
    with DragCallbacks, TapCallbacks, UserRemovable, OverlapHighlightable, BlinkAlphaTarget {

  double dragScale = 1.0;
  double autoScale = 1.0;

  int energy = 0;
  TextComponent? _hpTextComponent;

  final bool isDark;
  final VoidCallback? onForbiddenTouch;

  final double? attackTime;
  final VoidCallback? onExplode;
  final int? order;
  final BlendMode blendMode;

  double _attackElapsed = 0.0;
  bool _attackDone = false;
  bool _penaltyFired = false;

  late Path _outlinePath;
  late double _outlineLength;

  final Paint _attackPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6
    ..color = const Color(0xFF398A63);

  static const Color outlineNormal = Color(0xFF398A63);
  static const Color outlineDanger = Color(0xFFEE0505);

  final Color dangerColor = const Color(0xFFEE0505);
  final Color baseColor   = const Color(0xFF398A63);

  final Paint _overlapOutlinePaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;

  HexagonState _state = HexagonState.normal;

  double _autoGrowT = 0.0;
  double _disappearT = 0.0;

  static const double triggerScale = 1.25;
  static const double maxAutoScale = 3.5;

  double _finalScale = 1.0;
  double _opacity = 1.0;

  static const double _hexAngleOffset = -math.pi / 30;
  static const double extraDisappearScale = 1.25;

  // ============================
  // BLINKING
  // ============================

  double _blinkAlpha = 1.0;

  void setBlinkAlpha(double alpha) {
    _blinkAlpha = alpha.clamp(0.0, 1.0);

    _hpTextComponent?.textRenderer = TextPaint(
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black.withValues(alpha: _blinkAlpha)),
    );
  }

  HexagonShape(
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

  @override
  Future<void> onLoad() async {

    priority = 100 + (1000 - size.x).toInt();

    await super.onLoad();

    _outlinePath = _buildHexagonPath(size.toSize());

    _outlineLength =
        _outlinePath.computeMetrics().fold(0.0, (s, m) => s + m.length);

    if (!isDark && energy >= 1) {
      _hpTextComponent = TextComponent(
        text: energy.toString(),
        anchor: Anchor.center,
        position: size / 2,
        priority: 999,
        textRenderer: TextPaint(
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      );
      add(_hpTextComponent!);
    }
  }

  Path _buildHexagonPath(Size s) {

    final center = Offset(s.width / 2, s.height / 2);

    final inset = (_attackPaint.strokeWidth / 2) + 10.0;

    final radius = (s.width / 2) - inset;

    final path = Path();

    for (int i = 0; i < 6; i++) {

      final angle = (math.pi / 3) * i + _hexAngleOffset;

      final p = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
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

  @override
  void onTapDown(TapDownEvent event) {
    event.continuePropagation = false;
    if (isDark) onForbiddenTouch?.call();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {

    if (isDark) {
      onForbiddenTouch?.call();
      return;
    }

    if (_state != HexagonState.normal) return;

    dragScale += 0.01;

    scale = Vector2.all(dragScale);
  }

  @override
  void onDragEnd(DragEndEvent event) {

    if (_state != HexagonState.normal) return;

    if (dragScale >= triggerScale) {

      _state = HexagonState.autoGrowing;

      wasRemovedByUser = true;
    }
  }

  @override
  void update(double dt) {

    super.update(dt);

    // ============================
    // ATTACK TIMER → 즉시 자폭
    // ============================

    if ((attackTime ?? 0) > 0 && !_attackDone) {

      _attackElapsed += dt;

      final ratio =
          ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);

      final isDanger = ratio <= 0.2;

      _attackPaint.color = isDanger ? outlineDanger : outlineNormal;

      if (_attackElapsed >= attackTime!) {

        _attackDone = true;

        if (!_penaltyFired) {
          _penaltyFired = true;
          onExplode?.call();
        }

        wasRemovedByUser = false;

        parent?.add(
          AttackExplosionEffect(
            basePath: _buildExplosionHexagonPath(),
            position: position.clone(),
            size: size.clone(),
            color: const Color(0xFF398A63),
          ),
        );

        removeFromParent();

        return;
      }
    }

    // ============================
    // USER REMOVE
    // ============================

    if (_state == HexagonState.autoGrowing) {

      _autoGrowT += dt / 0.4;

      final t = Curves.easeOut.transform(_autoGrowT.clamp(0.0, 1.0));

      autoScale = 1.0 + t * maxAutoScale;

      scale = Vector2.all(dragScale * autoScale);

      if (_autoGrowT >= 1.0) {

        _finalScale = dragScale * autoScale;

        _state = HexagonState.disappearing;
      }
    }

    if (_state == HexagonState.disappearing) {

      _disappearT += dt / 0.35;

      final t = _disappearT.clamp(0.0, 1.0);

      final extraT = (t / 0.25).clamp(0.0, 1.0);

      final extraScale =
          Curves.easeOut.transform(extraT) * (extraDisappearScale - 1.0);

      scale = Vector2.all(_finalScale * (1.0 + extraScale));

      _opacity = 1.0 - Curves.easeIn.transform(t);

      if (_disappearT >= 1.0) {

        // 일반 제거 explosion (zoom 제거)
        parent?.add(
          AttackExplosionEffect(
            basePath: _buildExplosionHexagonPath(),
            position: position.clone(),
            size: size.clone(),
            color: const Color(0xFF398A63),
          ),
        );

        removeFromParent();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final fillColor = isDark ? const Color(0xFF888888) : baseColor;
    final alpha = (_blinkAlpha * _opacity).clamp(0.0, 1.0);

    canvas.drawShadow(
      _outlinePath,
      Colors.black.withValues(alpha: 0.35),
      6,
      false,
    );

    canvas.drawPath(
      _outlinePath,
      Paint()
        ..color = fillColor.withValues(alpha: alpha)
        ..style = PaintingStyle.fill
        ..blendMode = blendMode,
    );

    canvas.drawPath(
      _outlinePath,
      Paint()
        ..color = fillColor.withValues(alpha: alpha * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..blendMode = blendMode,
    );

    if ((attackTime ?? 0) > 0 && !_attackDone) {
      final ratio =
          ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);

      if (ratio <= 0.2) {
        canvas.drawPath(
          _outlinePath,
          Paint()
            ..color = dangerColor.withValues(alpha: alpha * 0.5)
            ..style = PaintingStyle.fill
            ..blendMode = BlendMode.srcATop,
        );
      }
    }

    super.render(canvas);

    if ((attackTime ?? 0) > 0 && !_attackDone) {

      final ratio =
          ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);

      final drawLen = _outlineLength * ratio;

      final partial = ShapePathUtils.extractPartial(_outlinePath, drawLen);

      canvas.drawPath(partial, _attackPaint);
    }
  }

  @override
  Rect toRect() {

    return Rect.fromCenter(
      center: Offset(position.x, position.y),
      width: size.x * scale.x,
      height: size.y * scale.y,
    );
  }

  Path _buildExplosionHexagonPath() {

    final w = size.x;
    final h = size.y;

    return Path()
      ..moveTo(w * 0.25, 0)
      ..lineTo(w * 0.75, 0)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.75, h)
      ..lineTo(w * 0.25, h)
      ..lineTo(0, h * 0.5)
      ..close();
  }
}

