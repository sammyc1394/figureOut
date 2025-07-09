//temp for debug: checking if the cursor is drawing circle correctly

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

  @override
  Future<void> onLoad() async {
    super.onLoad();

    spawnShapes();

    debugMode = true;
  }

  Vector2 _calculateCentroid(List<Vector2> points) {
    final sum = points.fold<Vector2>(Vector2.zero(), (a, b) => a + b);
    return sum / points.length.toDouble();
  }

  bool _doesPathCrossLine(Vector2 start, Vector2 end, List<Vector2> path) {
    for (int i = 0; i < path.length - 1; i++) {
      if (_doLinesIntersect(start, end, path[i], path[i + 1])) {
        return true;
      }
    }
    return false;
  }

  bool _doLinesIntersect(Vector2 p1, Vector2 p2, Vector2 q1, Vector2 q2) {
    double ccw(Vector2 a, Vector2 b, Vector2 c) {
      return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
    }

    return (ccw(p1, p2, q1) * ccw(p1, p2, q2) < 0) &&
        (ccw(q1, q2, p1) * ccw(q1, q2, p2) < 0);
  }

  bool _isPathClosed(List<Vector2> path) {
    if (path.length < 3) return false;

    const double maxStartEndDistance = 10;
    const double minLength = 300;
    const double minArea = 1000;

    final start = path.first;
    final end = path.last;

    final bool isShortLoop = start.distanceTo(end) < maxStartEndDistance;
    final bool pathCrosses = _doesPathCrossLine(start, end, path);

    if (!(isShortLoop || pathCrosses)) {
      print("Path is not considered closed: no short loop or crossing");
      return false;
    }

    // 추가적으로 최소 길이, 최소 면적 조건도 적용 가능
    double length = 0;
    for (int i = 0; i < path.length - 1; i++) {
      length += path[i].distanceTo(path[i + 1]);
    }
    if (length < minLength) return false;

    final double area = _calculatePolygonArea(path);
    if (area < minArea) return false;

    return true;
  }

  double _calculatePolygonArea(List<Vector2> path) {
    double area = 0;
    for (int i = 0; i < path.length; i++) {
      final p1 = path[i];
      final p2 = path[(i + 1) % path.length];
      area += (p1.x * p2.y) - (p2.x * p1.y);
    }
    return area.abs() / 2.0;
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

    if (!_isPathClosed(userPath)) {
      print("Not a closed circular path");
      userPath.clear();
      return;
    }

    for (final comp in children.whereType<TriangleShape>()) {
      final enclosed = comp.isFullyEnclosedByUserPath(userPath);
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

    if (dragStart != null) {
      final end = event.canvasEndPosition;
      final radius = dragStart!.distanceTo(end);
      currentCircleCenter = dragStart!;
      currentCircleRadius = radius;
    }

    componentsAtPoint(event.canvasStartPosition).forEach((element) {
      if (element is RectangleShape) {
        element.touchAtPoint(userPath);
      }
    });
  }

  void spawnShapes() {
    final size = this.size;
    final shapes = <PositionComponent>[];

    while (shapes.length < 10) {
      final type = _random.nextInt(5); // 0: circle, 1: rect, 2: pentagon
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
