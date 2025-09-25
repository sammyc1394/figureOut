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
  late final SvgComponent svg;
  late final TextComponent label;

  CircleShape(Vector2 position, this.count)
    : super(position: position, size: Vector2.all(80), anchor: Anchor.center);

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
    // add(svg);
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
    count -= 1;
    if (count <= 0) {
      wasRemovedByUser = true;
      removeFromParent();
    }
  }
}
