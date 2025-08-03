import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';
import 'UserRemovable.dart';
import 'dart:math' as math;

class HexagonShape extends PositionComponent with DragCallbacks, UserRemovable {
  double cumulativeScale = 1.0;
  late final SvgComponent svg;

  HexagonShape(Vector2 position)
    : super(position: position, size: Vector2.all(100), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final svgData = await Svg.load('hexagon.svg');
    svg = SvgComponent(
      svg: svgData,
      size: size,
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y / 2),
    );
    add(svg);
  }

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
  void onDragUpdate(DragUpdateEvent event) {
    cumulativeScale += 0.01;

    if (cumulativeScale >= 1.25) {
      removeFromParent();
      wasRemovedByUser = true;
    } else {
      scale = Vector2.all(cumulativeScale);
    }
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
