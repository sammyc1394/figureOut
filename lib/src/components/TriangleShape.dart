import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class TriangleShape extends PositionComponent {
  TriangleShape(Vector2 position) : super(position: position);

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Colors.amber.shade100;
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, paint);

  }
}