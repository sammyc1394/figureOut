import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/src/gestures/events.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';

class CircleShape extends PositionComponent with TapCallbacks {
  int count;
  late final SvgComponent svg;
  late final TextComponent label;

  CircleShape(Vector2 position, this.count)
    : super(position: position, size: Vector2.all(80));

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final svgData = await Svg.load('Circle (tap).svg');
    svg = SvgComponent(
      svg: svgData,
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    svg.render(canvas);

    if (count > 0) {
      _drawText(canvas, count.toString());
    }
  }

  void _drawText(Canvas canvas, String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Color(0xFFF9C58D), fontSize: 20),
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
    count -= 1;
    if (count <= 0) {
      removeFromParent();
    }
  }
}
