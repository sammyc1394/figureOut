import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class TriangleShape extends PositionComponent {
  TriangleShape(Vector2 position)
    : super(position: position, size: Vector2.all(60));

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.amber.shade100;
    final path = Path()
      ..moveTo(size.x / 2, 0)
      ..lineTo(0, size.y)
      ..lineTo(size.x, size.y)
      ..close();

    canvas.save();
    canvas.translate(0, 0);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  List<Vector2> getTriangleVertices() {
    final top = Vector2(position.x + size.x / 2, position.y);
    final bottomLeft = Vector2(position.x, position.y + size.y);
    final bottomRight = Vector2(position.x + size.x, position.y + size.y);
    return [top, bottomLeft, bottomRight];
  }
}
