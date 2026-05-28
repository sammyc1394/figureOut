import 'dart:math';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:figureout/src/functions/UserRemovable.dart';
import 'package:figureout/src/functions/blink_alpha_target.dart';
import '../config.dart';
import '../functions/OrderableShape.dart';
import '../functions/OverlapHighlightable.dart';
import '../effect/AttackExplosionEffect.dart';
import '../effect/CircleDisappearEffect.dart';
import 'shape_path_utils.dart';

class CircleShape extends PositionComponent
    with TapCallbacks, UserRemovable, HasGameRef, OverlapHighlightable, BlinkAlphaTarget
    implements OrderableShape {

  static final _images = Images(prefix: 'assets/');

  int count;
  final bool isDark;
  final bool isAttackable;
  final VoidCallback? onForbiddenTouch;
  final bool Function(OrderableShape shape)? onInteracted;
  final void Function()? onRemoved;

  final BlendMode blendMode;

  final double? attackTime;
  final VoidCallback? onExplode;
  @override
  final int? order;

  late PositionComponent _orderBadge;
  TextComponent? _hpTextComponent;

  late Sprite _sprite;
  late Path _wobblePath;

  double _attackElapsed = 0.0;
  bool _attackDone = false;
  bool _penaltyFired = false;
  bool isPaused = false;

  final Paint _attackPaint = Paint()
    ..color = Colors.orangeAccent
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6;

  final Color baseColor = const Color(0xFFED613D);
  final Color dangerColor = const Color(0xFFEE0505);

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

  CircleShape(
    Vector2 position,
    this.count, {
    this.isDark = false,
    this.isAttackable = false,
    this.onForbiddenTouch,
    this.attackTime,
    this.onExplode,
    this.order,
    this.onInteracted,
    this.onRemoved,
    this.blendMode = BlendMode.srcOver,
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

    if (order != null) {
      _addOrderBadge(order!);
    }

    if (!isDark && count >= 1) {
      _hpTextComponent = TextComponent(
        text: count.toString(),
        anchor: Anchor.center,
        position: size / 2,
        priority: 999,
        textRenderer: TextPaint(
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      );
      add(_hpTextComponent!);
    }

    _sprite = await Sprite.load('shapes/Circle_3x.png', images: _images);
    _wobblePath = ShapePathUtils.wobble(_buildCirclePath(), amplitude: size.x * 0.009);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isPaused) return;
    if (isDark) return;
    if (!isAttackable) return;

    // // ------------------------------------------------------------
    // // 즉시 공격 및 공격도형 제거 이펙트 적용
    // //
    // // 공격도형 제거 이펙트 현재 없음
    // // 공격시간 0의 경우 순서가 잘못입력되었거나, 금지도형 선택시에만 작동?
    // // ------------------------------------------------------------
    // if(attackTime == 0 && !_penaltyFired) {
    //   _penaltyFired = true;
    //   onExplode?.call(); // 시간 패널티
    //   wasRemovedByUser = false;
    //   removeFromParent();
    //   return;
    // }

    // ------------------------------------------------------------
    // 타이머 종료 시 자폭 처리
    // ------------------------------------------------------------
    if((attackTime?? 0) > 0 && isAttackable) {
      _attackElapsed += dt;

      if (!_attackDone && _attackElapsed >= attackTime!) {
        _attackDone = true;

        if (!_penaltyFired) {
          _penaltyFired = true;
          onExplode?.call(); // 시간 패널티
        }

        // 타이머 자폭
        wasRemovedByUser = false;

        parent?.add(
          AttackExplosionEffect(
            basePath: _buildCirclePath(),
            position: position.clone(),
            size: size.clone(),
            color: const Color(0xFFFF9D33),
          ),
        );

        removeFromParent();
      }
    }

    // ------------------------------------------------------------
    // 절반 이하 → 빨간 tint
    // ------------------------------------------------------------
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    final center = size / 2;
    final radius = size.x * 0.46;
    return point.distanceTo(center) <= radius;
  }

  @override
  void render(Canvas canvas) {
    _sprite.render(
      canvas,
      size: size,
      overridePaint: isDark
          ? (Paint()
              ..blendMode = blendMode
              ..colorFilter = ColorFilter.matrix([
                0.33, 0.33, 0.33, 0, 0,
                0.33, 0.33, 0.33, 0, 0,
                0.33, 0.33, 0.33, 0, 0,
                0, 0, 0, _blinkAlpha, 0,
              ]))
          : (Paint()
              ..blendMode = blendMode
              ..colorFilter = ColorFilter.mode(
                Color.fromARGB((_blinkAlpha * 255).round(), 255, 255, 255),
                BlendMode.modulate,
              )),
    );

    if (!_attackDone && _attackTimeCritical) {
      canvas.drawPath(
        _wobblePath,
        Paint()
          ..color = dangerColor.withValues(alpha: _blinkAlpha * 0.5)
          ..blendMode = BlendMode.srcATop,
      );
    }

    super.render(canvas);

    if ((attackTime ?? 0) > 0 && !_attackDone) {
      final ratio =
          ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);
      final sweep = 2 * pi * ratio;

      _attackPaint.color =
        (_attackTimeCritical ? dangerColor : Colors.orangeAccent)
            .withValues(alpha: _blinkAlpha);

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

  }

  Path _buildCirclePath() {
    final radius = size.x * 0.48;

    return Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.x / 2, size.y / 2),
          radius: radius,
        ),
      );
  }


  bool get _attackTimeCritical {
    if ((attackTime ?? 0) <= 0) return false;
    final ratio =
        ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);
    return ratio <= 0.2;
  }

  @override
  void onTapDown(TapDownEvent e) {
    e.continuePropagation = false;
    if (isDark) {
      onForbiddenTouch?.call();
      return;
    }

    final isValid = onInteracted?.call(this) ?? false;
    if (isValid) {
      applyValidInteraction();
    } else {
      onForbiddenTouch?.call();
      return;
    }
  }

  void applyValidInteraction() {
    count--;

    if (count >= 1) {
      _hpTextComponent?.text = count.toString();
    } else {
      _hpTextComponent?.removeFromParent();
      _hpTextComponent = null;
    }

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
        style: TextStyle(
          fontSize: 16,
          fontFamily: appFontFamily,
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
