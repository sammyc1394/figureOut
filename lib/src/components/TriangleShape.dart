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
    final topLeft = absoluteTopLeftPosition;
    final top = topLeft + Vector2(size.x / 2, 0);
    final bottomLeft = topLeft + Vector2(0, size.y);
    final bottomRight = topLeft + Vector2(size.x, size.y);

    return [top, bottomLeft, bottomRight];
  }

  bool isFullyEnclosedByUserPath(List<Vector2> userPath) {
    // 사용자가 그린 경로가 삼각형 꼭짓점을 모두 포함하는지 검사
    for (final v in getTriangleVertices()) {
      if (!isPointInPolygon(v, userPath)) return false;
    }
    return true;
  }

  bool isPointInPolygon(Vector2 point, List<Vector2> polygon) {
    int intersectCount = 0;
    for (int i = 0; i < polygon.length; i++) {
      Vector2 a = polygon[i];
      Vector2 b = polygon[(i + 1) % polygon.length];

      if (((a.y > point.y) != (b.y > point.y)) &&
          (point.x <
              (b.x - a.x) * (point.y - a.y) / (b.y - a.y + 0.0001) + a.x)) {
        intersectCount++;
      }
    }
    return intersectCount % 2 == 1;
  }
}
