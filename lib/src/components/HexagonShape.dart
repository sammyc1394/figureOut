import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';
import 'package:figureout/src/functions/UserRemovable.dart';
import 'dart:math' as math;

enum HexagonState {
  normal,
  autoGrowing,
  disappearing,
}

class HexagonShape extends PositionComponent
    with DragCallbacks, TapCallbacks, UserRemovable {

  double dragScale = 1.0;
  double autoScale = 1.0;

  late final SvgComponent svg;
  late final SpriteComponent _png;
  int energy = 0;

  final bool isDark;
  final VoidCallback? onForbiddenTouch;

  final double? attackTime;
  final VoidCallback? onExplode;

  double _attackElapsed = 0.0;
  bool _attackDone = false;
  bool _penaltyFired = false; 

  late Path _outlinePath;
  late double _outlineLength;

  final Paint _attackPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6
    ..color = const Color(0xFF9BEE3B);

  static const Color outlineNormal = Color(0xFF9BEE3B);
  static const Color outlineDanger = Color(0xFFEE0505);

  final Color dangerColor = const Color(0xFFEE0505);
  final Color baseColor   = const Color(0xFF9BEE3B);

  HexagonState _state = HexagonState.normal;

  double _autoGrowT = 0.0;
  double _disappearT = 0.0;

  static const double triggerScale = 1.25;
  static const double maxAutoScale = 3.5;

  double _finalScale = 1.0;
  double _opacity = 1.0;

  static const double _hexAngleOffset = -math.pi / 30;
  static const double extraDisappearScale = 1.25;

  HexagonShape(
    Vector2 position,
    this.energy, {
    this.isDark = false,
    this.onForbiddenTouch,
    this.attackTime,
    this.onExplode,
  }) : super(
          position: position,
          size: Vector2.all(100),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final asset = isDark ? 'DarkHexagon.svg' : 'hexagon.svg';
    final svgData = await Svg.load(asset);

    svg = SvgComponent(
      svg: svgData,
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
    add(svg);

    final img = await Images(prefix: 'assets/').load('shapes/hexagon.png');
    _png = SpriteComponent(
      sprite: Sprite(img),
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    )
      ..opacity = 0.8
      ..paint.colorFilter = ColorFilter.mode(baseColor, BlendMode.srcATop);
    add(_png);

    if ((attackTime ?? 0) > 0) {
      svg.opacity = 0;
      _png.opacity = 1;
    }

    _outlinePath = _buildHexagonPath(size.toSize());
    _outlineLength =
        _outlinePath.computeMetrics().fold(0.0, (s, m) => s + m.length);
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
      if (i == 0) path.moveTo(p.dx, p.dy);
      else path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  Path _extractPartialPath(Path path, double length) {
    final result = Path();
    double remaining = length;
    for (final metric in path.computeMetrics()) {
      if (remaining <= 0) break;
      final len = remaining.clamp(0.0, metric.length);
      result.addPath(metric.extractPath(0, len), Offset.zero);
      remaining -= len;
    }
    return result;
  }

  @override
  void onTapDown(TapDownEvent event) {
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

      _png.paint.colorFilter = ColorFilter.mode(
        isDanger ? dangerColor : baseColor,
        BlendMode.srcATop,
      );
      _attackPaint.color = isDanger ? outlineDanger : outlineNormal;

      if (_attackElapsed >= attackTime!) {
        _attackDone = true;

        if (!_penaltyFired) {
          _penaltyFired = true;
          onExplode?.call(); // 시간 패널티
        }

        wasRemovedByUser = false;
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
      svg.opacity = _opacity;

      if (_disappearT >= 1.0) {
        removeFromParent();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if ((attackTime ?? 0) > 0 && !_attackDone) {
      final ratio =
          ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);
      final drawLen = _outlineLength * ratio;
      final partial = _extractPartialPath(_outlinePath, drawLen);
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
}
