import 'dart:math';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';
import 'package:figureout/src/functions/UserRemovable.dart';

class CircleShape extends PositionComponent
    with TapCallbacks, UserRemovable, HasGameRef {
  int count;
  final bool isDark;
  final VoidCallback? onForbiddenTouch;

  final double? attackTime;
  final VoidCallback? onExplode;
  final int? order;

  double _attackElapsed = 0.0;
  bool _attackDone = false;
  bool _penaltyFired = false;
  bool isPaused = false;

  late SvgComponent _svg;         // 기본 도형(테두리 O)
  late SpriteComponent _png;      // 공격 타이머 도형(테두리 X)

  // arc paint
  final Paint _attackPaint = Paint()
    ..color = Colors.orangeAccent
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6;

  final Color dangerColor = const Color(0xFFEE0505);

  CircleShape(
    Vector2 position,
    this.count, {
    this.isDark = false,
    this.onForbiddenTouch,
    this.attackTime,
    this.onExplode,
    this.order,
  }) : super(position: position, size: Vector2.all(80), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // ------------------------------------------------------------
    // 1) 기본 SVG 로드
    // ------------------------------------------------------------
    final svgAsset = isDark ? 'DarkCircle.svg' : 'Circle (tap).svg';

    _svg = SvgComponent(
      svg: await Svg.load(svgAsset),
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );

    // ------------------------------------------------------------
    // 2) PNG (타이머용) 로드
    // ------------------------------------------------------------
    final images = Images(prefix: 'assets/');
    final img = await images.load('shapes/Circle.png');

    _png = SpriteComponent(
      sprite: Sprite(img),
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );

    // 기본 = PNG 숨김
    _png.opacity = 0;

    add(_svg);
    add(_png);

    // ------------------------------------------------------------
    // 3) attackTime 있으면 PNG 표시 / SVG 숨김
    // ------------------------------------------------------------
    if ((attackTime ?? 0) > 0) {
      _svg.opacity = 0;
      _png.opacity = 1;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isPaused) return;

    if ((attackTime ?? 0) <= 0) return;

    _attackElapsed += dt;

    // ------------------------------------------------------------
    // 타이머 종료
    // ------------------------------------------------------------
    if (!_attackDone && _attackElapsed >= attackTime!) {
      _attackDone = true;

      // PNG 숨기고 SVG 복귀
      _png.opacity = 0;
      _png.paint = Paint(); // tint 제거
      _svg.opacity = 1;

      if (!_penaltyFired) {
        _penaltyFired = true;
        onExplode?.call();
      }
    }

    // ------------------------------------------------------------
    // 절반 이하 → 빨간색 tint 적용
    // ------------------------------------------------------------
    if (!_attackDone && _attackTimeHalfLeft) {
      _png.paint = Paint()
        ..colorFilter = ColorFilter.mode(
          dangerColor,
          BlendMode.srcIn,
        );
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // ------------------------------------------------------------
    // Arc 타이머
    // ------------------------------------------------------------
    if ((attackTime ?? 0) > 0 && !_attackDone) {
      final ratio =
          ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);
      final sweep = 2 * pi * ratio;

      _attackPaint.color =
          _attackTimeHalfLeft ? dangerColor : Colors.orangeAccent;

      final center = Offset(size.x / 2, size.y / 2);
      final radius = size.x * 0.48;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        sweep,
        false,
        _attackPaint,
      );
    }

    // ------------------------------------------------------------
    // 숫자 렌더링
    // ------------------------------------------------------------
    if (!isDark && count > 0) {
      final tp = TextPainter(
        text: TextSpan(
          text: count.toString(),
          style: TextStyle(
            color:
                _attackTimeHalfLeft ? dangerColor : const Color(0xFFFF9D33),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas,
          Offset((size.x - tp.width) / 2, (size.y - tp.height) / 2));
    }
  }

  bool get _attackTimeHalfLeft {
    if ((attackTime ?? 0) <= 0) return false;
    final ratio =
        ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);
    return ratio <= 0.5;
  }

  @override
  void onTapDown(TapDownEvent e) {
    if (isDark) {
      onForbiddenTouch?.call();
      return;
    }

    count--;
    if (count <= 0) {
      wasRemovedByUser = true;
      removeFromParent();
    }
  }
}

