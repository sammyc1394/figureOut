import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';

class TriangleShape extends PositionComponent {
  late final SvgComponent svg;

  TriangleShape(Vector2 position)
    : super(position: position, size: Vector2.all(70), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final svgData = await Svg.load('triangle.svg');
    svg = SvgComponent(
      svg: svgData,
      size: size,
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y / 2),
    );
    add(svg);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
  }

  List<Vector2> getTriangleVertices() {
    final center = svg.absoluteCenter;
    final halfWidth = svg.size.x / 2;
    final halfHeight = svg.size.y / 2;

    final top = center + Vector2(0, -halfHeight);
    final bottomLeft = center + Vector2(-halfWidth, halfHeight);
    final bottomRight = center + Vector2(halfWidth, halfHeight);

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
