import 'package:flame/components.dart';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class HexagonShape extends PositionComponent {
  HexagonShape(Vector2 position)
    : super(position: position, size: Vector2.all(60), anchor: Anchor.center);

  List<Vector2> _generateHexagonPoints() {
    final center = size / 2;
    final radius = size.x / 2;

    final List<Vector2> points = [];
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i;
      final x = center.x + radius * math.cos(angle);
      final y = center.y + radius * math.sin(angle);
      points.add(Vector2(x, y));
    }
    return points;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final path = Path();
    final points = _generateHexagonPoints();

    path.moveTo(points.first.x, points.first.y);
    for (final p in points.skip(1)) {
      path.lineTo(p.x, p.y);
    }
    path.close();

    final paint = Paint()..color = Colors.blue.shade100;
    canvas.drawPath(path, paint);
  }

  @override
  Rect toRect() {
    return Rect.fromCenter(
      center: Offset(position.x, position.y),
      width: size.x,
      height: size.y,
    );
  }
}
