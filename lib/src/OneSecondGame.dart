import 'package:flame/camera.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'components/RefreshButton.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'components/CircleShape.dart';
import 'components/HexagonShape.dart';
import 'components/PentagonShape.dart';
import 'components/RectangleShape.dart';

import 'components/TriangleShape.dart';
import 'config.dart';

import 'components/sheet_service.dart';

class OneSecondGame extends FlameGame with DragCallbacks, CollisionCallbacks {
  final math.Random _random = math.Random();
  late RefreshButton refreshButton;
  late StageData initialStage;

  int _currentStageRunId = 0;

  late final screenWidth;
  late final screenHeight;
  final SheetService sheetService = SheetService();

  Vector2? dragStart;
  Vector2? sliceStartPoint;
  Vector2? sliceEndPoint;
  List<Vector2> userPath = [];
  Vector2? currentCircleCenter;
  double? currentCircleRadius;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    screenWidth = size.x;
    screenHeight = size.y;

    // Add refresh button to top-right corner
    refreshButton = RefreshButton(
      position: Vector2(size.x - 60, 40),
      onPressed: refreshGame,
    );
    add(refreshButton);

    try {
      final stages = await sheetService.fetchData();
      if (stages.isNotEmpty) {
        print('Fetched stages: ${stages.toString()}');
        initialStage = stages[0];
        runStageMissions(initialStage!);
      }
    } catch (e) {
      print('Sheet fetch error: $e');
    }

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

    const double maxStartEndDistance = 80;
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

  Future<void> runStageMissions(StageData stage) async {
    final centerOffset = size / 2;
    final runId = ++_currentStageRunId;

    final sortedMissions = stage.missions.keys.toList()..sort();

    for (final missionNum in sortedMissions) {
      if (runId != _currentStageRunId) {
        print('Stage run $runId cancelled (current: $_currentStageRunId)');
        return;
      }

      final enemies = stage.missions[missionNum]!;
      print('Starting Mission $missionNum');

      final spawnedThisMission = <Component>{};

      for (final enemy in enemies) {
        if (enemy.command == 'wait') {
          final durationMatch = RegExp(r'(\d+\.?\d*)').firstMatch(enemy.shape);
          final duration = durationMatch != null
              ? double.tryParse(durationMatch.group(1)!) ?? 1.0
              : 1.0;
          print('[WAIT] $duration sec');
          await Future.delayed(
            Duration(milliseconds: (duration * 1000).toInt()),
          );
          continue;
        }

        final posMatch = RegExp(
          r'\((-?\d+),\s*(-?\d+)\)',
        ).firstMatch(enemy.position);
        if (posMatch == null) continue;
        final x = double.parse(posMatch.group(1)!);
        final y = double.parse(posMatch.group(2)!);
        final position = centerOffset + Vector2(x, y);

        PositionComponent? shape;
        if (enemy.shape.startsWith('Circle')) {
          final radiusMatch = RegExp(
            r'Circle\s*\((\d+)\)',
          ).firstMatch(enemy.shape);
          final radius = radiusMatch != null
              ? int.parse(radiusMatch.group(1)!)
              : 10;
          shape = CircleShape(position, radius);
        } else if (enemy.shape == 'Rectangle') {
          shape = RectangleShape(position);
        } else if (enemy.shape.startsWith('Pentagon')) {
          final energyMatch = RegExp(
            r'Pentagon\s*\((\d+)\)',
          ).firstMatch(enemy.shape);
          final energy = energyMatch != null
              ? int.parse(energyMatch.group(1)!)
              : 10;
          shape = PentagonShape(position, energy);
        } else if (enemy.shape == 'Triangle') {
          shape = TriangleShape(position);
        } else if (enemy.shape == 'Hexagon') {
          shape = HexagonShape(position);
        }

        if (shape != null) {
          final shapeRect = shape.toRect();
          final isWithinBounds =
              shapeRect.left >= 0 &&
              shapeRect.top >= 0 &&
              shapeRect.right <= screenWidth &&
              shapeRect.bottom <= screenHeight;

          if (isWithinBounds) {
            await add(shape);
            await shape.loaded;
            print('shape spawned: ${shape.position.toString()}');
            spawnedThisMission.add(shape);
            await Future.delayed(Duration(milliseconds: 100));
          }
        }
      }

      await waitUntilMissionCleared(spawnedThisMission);
    }
  }

  Future<void> waitUntilMissionCleared(Set<Component> targets) async {
    while (true) {
      // 아직 화면에 남아있는 도형이 있는지 확인
      final remaining = targets.where((c) => c.isMounted).toList();
      if (remaining.isEmpty) {
        print('Mission cleared');
        break;
      }
      await Future.delayed(Duration(milliseconds: 300));
    }
  }

  void refreshGame() {
    print("Refreshing game!");

    // Clear user path
    userPath.clear();
    currentCircleCenter = null;
    currentCircleRadius = null;
    print('${children} before shape removal');

    // Remove all existing shapes (but keep the refresh button)
    children.whereType<CircleShape>().forEach((shape) {
      shape.removeFromParent();
    });
    children.whereType<RectangleShape>().forEach((shape) {
      shape.removeFromParent();
    });
    children.whereType<PentagonShape>().forEach((shape) {
      shape.removeFromParent();
    });
    children.whereType<TriangleShape>().forEach((shape) {
      shape.removeFromParent();
    });
    children.whereType<HexagonShape>().forEach((shape) {
      shape.removeFromParent();
    });

    // Spawn new shapes
    print('${children} after shape removal');
    print('Initial stage: ${initialStage.name}');
    runStageMissions(initialStage);
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
