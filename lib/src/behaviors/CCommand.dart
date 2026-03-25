import 'dart:math' as math;

import 'package:figureout/src/behaviors/shapeBehavior.dart';
import 'package:flame/components.dart';

import '../functions/OrbitingComponent.dart';

class CCommand implements ShapeBehavior {
  late final double radius;
  late final double degreePerSec;

  late final Vector2 actPosition;

  late final Vector2 Function(Vector2) flipY;
  late final Vector2 Function(Vector2, double, {bool clampInside}) toPlayArea;

  CCommand({
    required this.radius,
    required this.degreePerSec,
    required this.actPosition,
    required this.flipY,
    required this.toPlayArea,
  });

  @override
  Future<void> apply(PositionComponent shape) async {
    final halfSizeX = shape.size.x / 2;

    final centerWorld = actPosition;

    final originWorld = toPlayArea(
      flipY(Vector2(0, 0)),
      halfSizeX,
      clampInside: false,
    );

    final eastWorld = toPlayArea(
      flipY(Vector2(radius, 0)),
      halfSizeX,
      clampInside: false,
    );

    final northWorld = toPlayArea(
      flipY(Vector2(0, radius)),
      halfSizeX,
      clampInside: false,
    );

    final radiusWorldX = (eastWorld.x - originWorld.x).abs();
    final radiusWorldY = (northWorld.y - originWorld.y).abs();

    final angularSpeed = degreePerSec * math.pi / 180;

    // 시작 위치: 원의 오른쪽
    shape.position = Vector2(
      centerWorld.x + radiusWorldX,
      centerWorld.y,
    );

    shape.add(
      OrbitingComponent(
        target: shape,
        center: centerWorld,
        radiusX: radiusWorldX,
        radiusYParam: radiusWorldY,
        angularSpeed: angularSpeed,
      ),
    );
  }

  @override
  String get command => throw UnimplementedError();
}