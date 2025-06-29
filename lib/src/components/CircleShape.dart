import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/src/gestures/events.dart';
import 'package:flutter/material.dart';

class CircleShape extends PositionComponent with TapCallbacks {
  int count;
  CircleShape(Vector2 position, this.count)
      : super(position: position, size: Vector2.all(60),
  );

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.amber.shade100;
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, paint);
    if(count != 0) {
      _drawText(canvas, count.toString());
    }
  }

  void _drawText(Canvas canvas, String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.black, fontSize: 20),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size.x - textPainter.width) / 2, (size.y - textPainter.height) / 2),
    );
  }
  @override
  void onTapDown(TapDownEvent e) {
    count -= 1;
    if (count <= 0) {
      removeFromParent();
    }
  }
}