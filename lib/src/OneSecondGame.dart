//temp for debug: checking if the cursor is drawing circle correctly
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'components/CircleShape.dart';
import 'components/HexagonShape.dart';
import 'components/PentagonShape.dart';
import 'components/RectangleShape.dart';
import 'components/TriangleShape.dart';
import 'config.dart';

class OneSecondGame extends FlameGame with DragCallbacks, CollisionCallbacks {
  final math.Random _random = math.Random();

  Vector2? dragStart;
  Vector2? sliceStartPoint;
  Vector2? sliceEndPoint;
  List<Vector2> userPath = [];
  Vector2? currentCircleCenter;
  double? currentCircleRadius;

  Future<void> onLoad() async {
    super.onLoad();

    spawnShapes();

    debugMode = true;
  }

  Vector2 _calculateCentroid(List<Vector2> points) {
    final sum = points.fold<Vector2>(Vector2.zero(), (a, b) => a + b);
    return sum / points.length.toDouble();
  }

  @override
  void onDragStart(DragStartEvent event) {
    dragStart = event.canvasPosition;
    userPath.clear();
    userPath.add(event.canvasPosition);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (userPath.length < 3) {
      print("Drag too short: ${userPath.length} pts");
      userPath.clear();
      return;
    }

    if (userPath.first.distanceTo(userPath.last) > 10) {
      print("Not a closed shape");
      userPath.clear();
      return;
    }

    final center = _calculateCentroid(userPath);
    final radius = userPath.map((p) => p.distanceTo(center)).reduce(math.max);
    print("radius: $radius");

    for (final comp in children.whereType<TriangleShape>()) {
      final enclosed = comp.isFullyEnclosedByUserPath(userPath);
      print("isFullyEnclosedByUserPath: $enclosed");
      if (enclosed) {
        print('[REMOVE] Triangle at ${comp.position}');
        comp.removeFromParent();
      }
    }

    userPath.clear();
    currentCircleCenter = null;
    currentCircleRadius = null;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);

    userPath.add(event.canvasEndPosition);

    Vector2 startPoint = event.canvasStartPosition;
    Vector2 endPoint = event.canvasEndPosition;

    if (dragStart != null) {
      final end = event.canvasEndPosition;
      final radius = dragStart!.distanceTo(end);
      currentCircleCenter = dragStart!;
      currentCircleRadius = radius;
    }

    componentsAtPoint(event.canvasStartPosition).forEach((element) {
      if (element is RectangleShape) {
        double startX = startPoint.x;
        double startY = startPoint.y;
        double endX = endPoint.x;
        double endY = endPoint.y;

        print("startPoint : ($startX, $startY), endPoint : ($endX, $endY)");

        var splitsShapes = <PositionComponent>[];

        splitsShapes = element.touchAtPoint(startPoint, endPoint);
        Future.delayed(Duration(seconds: 1), () {
          removeAll(splitsShapes);
        });
      }
    });
  }

  void spawnShapes() {
    final size = this.size;
    final shapes = <PositionComponent>[];

    while (shapes.length < 10) {
      final type = _random.nextInt(4); // 0: circle, 1: rect, 2: pentagon
      final position = Vector2(
        _random.nextDouble() * (size.x - 100),
        _random.nextDouble() * (size.y - 100),
      );

      PositionComponent shape;
      switch (type) {
        case 0:
          shape = CircleShape(position, _random.nextInt(10) + 1);
          break;
        case 1:
          shape = RectangleShape(position);
          break;
        case 2:
          shape = PentagonShape(position, _random.nextInt(50));
          break;
        case 3:
          shape = TriangleShape(position);
          break;
        case 4:
          shape = HexagonShape(position);
          break;
        default:
          shape = CircleShape(position, _random.nextInt(10) + 1);
          ;
      }

      // 겹침 방지
      bool isOverlapping = shapes.any(
        (s) => s.toRect().overlaps(shape.toRect()),
      );
      if (!isOverlapping &&
          (position.x < gameWidth - 100 && position.y < gameHeight - 100)) {
        shapes.add(shape);
        add(shape);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 디버그용 원 보기
    if (userPath.length > 1) {
      final pathPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.lightGreenAccent
        ..strokeWidth = 2;

      final path = Path()..moveTo(userPath.first.x, userPath.first.y);
      for (final point in userPath.skip(1)) {
        path.lineTo(point.x, point.y);
      }
      canvas.drawPath(path, pathPaint);
    }
  }
}
