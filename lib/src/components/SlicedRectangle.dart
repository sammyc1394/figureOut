import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/src/game/notifying_vector2.dart';
import 'package:flutter/material.dart';

class SlicedRectangle extends PositionComponent with HasPaint {
  final List<Vector2> vertices;

  SlicedRectangle(Vector2 position, List<Vector2> vertices)
      : vertices = [
        // new Vector2(0, 0),
        // new Vector2(0, 0),
        // new Vector2(0, 0),
        // new Vector2(0, 0)
      ],
      super (
        position: position,
        anchor: Anchor.center,
      ) {
    paint: Paint()..color = const Color(0xFF673AB7);
    }

    @override
    void render(Canvas canvas) {
      Path slicedPath = Path();

      slicedPath.moveTo(vertices[0].x, vertices[0].y);

      for (int i = 1; i < vertices.length; i++) {
        slicedPath.lineTo(vertices[i].x, vertices[i].y);
      }

      slicedPath.close();

      canvas.drawPath(slicedPath, paint);

      Paint borderPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawPath(slicedPath, borderPaint);
    }
}