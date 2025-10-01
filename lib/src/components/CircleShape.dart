import 'dart:math';
import 'package:figureout/src/functions/UserRemovable.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/src/gestures/events.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';

class CircleShape extends PositionComponent with TapCallbacks, UserRemovable {
  int count;
  final bool isDark;
  final VoidCallback? onForbiddenTouch;


  late final SvgComponent svg;
  late final TextComponent label;
  bool _penaltyFired = false;

  CircleShape(Vector2 position, this.count,{
    this.isDark = false,
    this.onForbiddenTouch,
  })
    : super(position: position, size: Vector2.all(80), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final String asset = isDark ? 'DarkCircle.svg' : 'Circle (tap).svg';
    final svgData = await Svg.load(asset);
    svg = SvgComponent(
      svg: svgData,
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
    // add(svg);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    svg.render(canvas);

    if (!isDark && count > 0) {
      _drawText(canvas, count.toString());
    }
  }

  void _drawText(Canvas canvas, String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFFFF9D33),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final offset = Offset(
      (size.x - textPainter.width) / 2,
      (size.y - textPainter.height) / 2,
    );

    canvas.save();

    textPainter.paint(canvas, offset);
    canvas.restore();
  }

  @override
  void onTapDown(TapDownEvent e) {
    if (isDark) {
      onForbiddenTouch?.call();
      return;
    }
    count -= 1;
    if (count <= 0) {
      wasRemovedByUser = true;
      removeFromParent();
    }
  }
}
