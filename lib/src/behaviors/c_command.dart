import 'dart:math' as math;

import 'package:figureout/src/behaviors/shape_behavior.dart';
import 'package:flame/components.dart';

import 'package:figureout/src/behaviors/orbiting_component.dart';

class CCommand implements ShapeBehavior {
  late final double radius;
  late final double degreePerSec;
  final bool clockwise;

  late final Vector2 actPosition;

  late final Vector2 Function(Vector2) flipY;
  late final Vector2 Function(Vector2, double, {bool clampInside}) toPlayArea;

  CCommand({
    required this.radius,
    required this.degreePerSec,
    required this.actPosition,
    required this.flipY,
    required this.toPlayArea,
    this.clockwise = true,
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

    // 화면의 Y축은 아래로 증가하므로 양의 각속도가 시계방향이다.
    // 속도는 크기만 사용하고, 회전 방향은 C/CC 명령으로 결정한다.
    final angularSpeed = degreePerSec.abs() * math.pi / 180 *
        (clockwise ? 1 : -1);

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
  String get command => clockwise ? 'C' : 'CC';
}
