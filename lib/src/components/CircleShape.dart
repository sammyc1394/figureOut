import 'dart:math';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';
import 'package:figureout/src/functions/UserRemovable.dart';
import '../functions/OrderableShape.dart';
import 'CircleDisappearEffect.dart';

class CircleShape extends PositionComponent
    with TapCallbacks, UserRemovable, HasGameRef
    implements OrderableShape {

  int count;
  final bool isDark;
  final VoidCallback? onForbiddenTouch;
  final bool Function(OrderableShape shape)? onInteracted;
  final void Function()? onRemoved;

  final double? attackTime;
  final VoidCallback? onExplode;
  final int? order;

  late PositionComponent _orderBadge;

  double _attackElapsed = 0.0;
  bool _attackDone = false;
  bool _penaltyFired = false;
  bool isPaused = false;

  late SvgComponent _svg;
  late SpriteComponent _png;

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
    this.onInteracted,
    this.onRemoved,
    Vector2? customSize,
  }) : super(
          position: position,
          size: customSize ?? Vector2.all(80),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    priority = 100 + (1000 - size.x).toInt();
    await super.onLoad();

    late final String svgAsset;

    if (isDark) {
      svgAsset = 'Circle_dark.svg';
    } else if (order != null) {
      svgAsset = 'Circle_sequence.svg';
    } else {
      svgAsset = 'Circle_basic.svg';
    }

    _svg = SvgComponent(
      svg: await Svg.load(svgAsset),
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );

    final images = Images(prefix: 'assets/');
    final img = await images.load('shapes/Circle.png');

    _png = SpriteComponent(
      sprite: Sprite(img),
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    )..opacity = 0;

    add(_svg);
    add(_png);

    if (order != null) {
      _addOrderBadge(order!);
    }

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
    // 타이머 종료 시 자폭 처리
    // ------------------------------------------------------------
    if (!_attackDone && _attackElapsed >= attackTime!) {
      _attackDone = true;

      if (!_penaltyFired) {
        _penaltyFired = true;
        onExplode?.call(); // 시간 패널티
      }

      // 타이머 자폭
      wasRemovedByUser = false;

      removeFromParent();
    }

    // ------------------------------------------------------------
    // 절반 이하 → 빨간 tint
    // ------------------------------------------------------------
    if (!_attackDone && _attackTimeCritical) {
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

    if ((attackTime ?? 0) > 0 && !_attackDone) {
      final ratio =
          ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);
      final sweep = 2 * pi * ratio;

      _attackPaint.color =
          _attackTimeCritical ? dangerColor : Colors.orangeAccent;

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

    if (!isDark && count > 0) {
      final tp = TextPainter(
        text: TextSpan(
          text: count.toString(),
          style: TextStyle(
            color:
                _attackTimeCritical ? dangerColor : const Color(0xFFFF9D33),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        Offset(
          (size.x - tp.width) / 2,
          (size.y - tp.height) / 2,
        ),
      );
    }
  }

  bool get _attackTimeCritical {
    if ((attackTime ?? 0) <= 0) return false;
    final ratio =
        ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);
    return ratio <= 0.2;
  }

  @override
  void onTapDown(TapDownEvent e) {
    if (isDark) {
      onForbiddenTouch?.call();
      return;
    }

    final isValid = onInteracted?.call(this) ?? false;
    if (isValid) {
      applyValidInteraction();
    }
  }

  void applyValidInteraction() {
    count--;

    if (count <= 0) {
      wasRemovedByUser = true;

      
      // 원 사라질 때 이펙트
      parent?.add(
        CircleDisappearEffect(
          position: position.clone(),
          radius: size.x * 0.48,
          color: const Color(0xFFFF9D33),
        ),
      );

      onRemoved?.call();
      removeFromParent();
    }
  }

  void _addOrderBadge(int order) {
    const badgeSizeRatio = 0.32;
    final badgeSize = size.x * badgeSizeRatio;

    _orderBadge = PositionComponent(
      size: Vector2.all(badgeSize),
      anchor: Anchor.center,
      position: Vector2(
        badgeSize * 0.6,
        badgeSize * 0.6,
      ),
    );

    final bg = CircleComponent(
      radius: badgeSize / 2,
      paint: Paint()..color = const Color(0xFFFFA94D),
      anchor: Anchor.center,
      position: _orderBadge.size / 2,
    );

    final text = TextComponent(
      text: order.toString(),
      anchor: Anchor.center,
      position: _orderBadge.size / 2,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 16,
          fontFamily: 'Moulpali',
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );

    _orderBadge.add(bg);
    _orderBadge.add(text);
    add(_orderBadge);
  }
}