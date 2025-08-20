import 'dart:async';
import 'dart:ui';
import 'package:figureout/src/components/UserRemovable.dart';
import 'package:figureout/src/AftermathScreen.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
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
import 'components/OrbitingComponent.dart';
import 'components/BlinkingBehavior.dart';
import 'components/TimerBarComponent.dart';

class OneSecondGame extends FlameGame with DragCallbacks, CollisionCallbacks {
  final math.Random _random = math.Random();

  // temporary function
  late RefreshButton refreshButton;

  // stage data
  late StageData initialStage;
  int _currentStageRunId = 0;
  List<StageData> _allStages = [];

  final SheetService sheetService = SheetService();

  // timer data
  Timer? countdownTimer;
  double remainingTime = 0;
  double missionTimeLimit = 0;
  bool isTimeCritical = false;
  late TimerBarComponent timerBar;
  late double _accumulator = 0;
  double _lastShownTime = -1;
  bool _timerEndedNotified = false;
  bool _timerPaused = false;

  final Map<PositionComponent, BlinkingBehaviorComponent> blinkingMap = {};

  // screen data
  late final screenWidth;
  late final screenHeight;

  // gestures
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

    PositionComponent cameraViewfinder = RectangleComponent(
      position: Vector2.zero(),
      size: size,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.transparent,
    );
    cameraViewfinder.flipVerticallyAroundCenter();

    print('center: ${cameraViewfinder.center.toString()}');
    print('topLeft: ${cameraViewfinder.absoluteTopLeftPosition.toString()}');

    // Add refresh button to top-right corner
    refreshButton = RefreshButton(
      position: Vector2(size.x - 60, 40),
      onPressed: refreshGame,
    );
    add(refreshButton);

    timerBar = TimerBarComponent(
      totalTime: 60, // 기본값, 나중에 startMissionTimer에서 정확히 설정됨
      position: Vector2(size.x / 2, 80),
    );
    add(timerBar);

    try {
      _allStages = await sheetService.fetchData();
      if (_allStages.isNotEmpty) {
        print('Fetched stages: ${_allStages.toString()}');
        runStageWithAftermath(_currentStageRunId);
      }
    } catch (e) {
      print('Sheet fetch error: $e');
    }

    debugMode = true;
  }

  // ==== running missions ======================================================================================

  // runStageWithAftermath -> runSingleMissions
  // 게임 구조 : stage 안에 자잘한 mission 들 존재, stage 끝나기 전 보스 존재
  Future<void> runStageWithAftermath(int stageIndex) async {
    if (stageIndex > _allStages.length) {
      print('all stages completed!');
      return;
    }

    final stage = _allStages[stageIndex];

    final result = await runSingleMissions(stage, stageIndex);

    final starRating = _calculateStarRating(result);
    // showAftermathScreen(result);
    showAftermathScreen(result, starRating, stageIndex);
  }

  Future<StageResult> runSingleMissions(StageData stage, int stageIndex) async {
    final centerOffset = size / 2;
    final runId = ++_currentStageRunId;

    if (runId != _currentStageRunId) {
      // print('Stage run $runId cancelled (current: $_currentStageRunId)');
      return StageResult.fail;
    }

    final parsedTime = _parseTimeLimitToSeconds(stage.timeLimit);
    if (parsedTime != null && parsedTime > 0) {
      startMissionTimer(parsedTime);
    } else {
      print(
        '[WARNING] Invalid or empty timeLimit: "${stage.timeLimit}" (timer not started)',
      );
    }

    print(
      'stage index = $stageIndex, and current stage index = $_currentStageRunId',
    );
    int stgLength = _allStages.length;
    print('stages length = $stgLength');

    final enemies = stage.missions[runId]!;

    final spawnedThisMission = <Component>{};

    for (final enemy in enemies) {
      if (enemy.command == 'wait') {
        final durationMatch = RegExp(r'(\d+\.?\d*)').firstMatch(enemy.shape);
        final duration = durationMatch != null
            ? double.tryParse(durationMatch.group(1)!) ?? 1.0
            : 1.0;
        print('[WAIT] $duration sec');
        await Future.delayed(Duration(milliseconds: (duration * 1000).toInt()));
        continue;
      }

      final posMatch = RegExp(
        r'\((-?\d+),\s*(-?\d+)\)',
      ).firstMatch(enemy.position);
      if (posMatch == null) continue;
      final x = double.parse(posMatch.group(1)!);
      final y = double.parse(posMatch.group(2)!);
      final position = centerOffset + flipY(Vector2(x, y));
      print('Spawning enemy at $position: ${enemy.shape}');

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

          // Movement
          final moveMatch = RegExp(
            r'\((-?\d+),\s*(-?\d+),\s*(-?\d+),\s*(-?\d+),\s*(\d+)\)',
          ).firstMatch(enemy.movement);
          print('Move match: ${enemy.movement}');
          if (moveMatch != null) {
            final x1 = double.parse(moveMatch.group(1)!);
            final y1 = double.parse(moveMatch.group(2)!);
            final x2 = double.parse(moveMatch.group(3)!);
            final y2 = double.parse(moveMatch.group(4)!);
            final speed = double.parse(moveMatch.group(5)!);

            final startPos = centerOffset + flipY(Vector2(x1, y1));
            final endPos = centerOffset + flipY(Vector2(x2, y2));
            shape.position = startPos;

            final distance = startPos.distanceTo(endPos);
            final travelTime = distance / speed;

            shape.add(
              MoveEffect.to(
                endPos,
                EffectController(
                  duration: travelTime,
                  alternate: true,
                  infinite: true,
                ),
              ),
            );
            continue;
          }

          // Movement
          final cMatch = RegExp(
            r'C\((-?\d+),\s*(-?\d+),\s*(\d+),\s*(\d+)\)',
          ).firstMatch(enemy.movement);
          if (cMatch != null) {
            final cx = double.parse(cMatch.group(1)!);
            final cy = double.parse(cMatch.group(2)!);
            final r = double.parse(cMatch.group(3)!);
            final s = double.parse(cMatch.group(4)!); // degree per second

            final center = centerOffset + flipY(Vector2(cx, cy));
            final angularSpeed = s * math.pi / 180;

            shape.position = center + Vector2(r, 0); // 초기 위치

            shape.add(
              OrbitingComponent(
                target: shape,
                center: center,
                radius: r,
                angularSpeed: angularSpeed,
              ),
            );
            continue;
          }

          // Movement
          final dMatch = RegExp(r'D\((\d+),(\d+)\)').firstMatch(enemy.movement);
          if (dMatch != null && shape != null) {
            final a = double.parse(dMatch.group(1)!);
            final b = double.parse(dMatch.group(2)!);

            await add(shape); // 초기 visible 상태로 추가
            await shape.loaded;

            final blinking = BlinkingBehaviorComponent(
              shape: shape,
              visibleDuration: a,
              invisibleDuration: b,
            );

            blinkingMap[shape] = blinking;

            shape.parent?.add(blinking); // 같은 parent에 붙여줘야 shape 제어 가능
          }

          // Movement
          // DR(a,b): 깜빡이며 랜덤 위치로 재등장
          final drMatch = RegExp(
            r'DR\((\d+),(\d+)\)',
          ).firstMatch(enemy.movement);
          if (drMatch != null && shape != null) {
            final a = double.parse(drMatch.group(1)!);
            final b = double.parse(drMatch.group(2)!);

            await add(shape); // 초기에 등장
            await shape.loaded;

            final blinking = BlinkingBehaviorComponent(
              shape: shape,
              visibleDuration: a,
              invisibleDuration: b,
              isRandomRespawn: true,
              bounds: size,
            );

            blinkingMap[shape] = blinking;

            add(blinking);
            continue;
          }

          await Future.delayed(Duration(milliseconds: 100));
        }
      }
    }

    StageResult ret = await waitUntilMissionCleared(spawnedThisMission);

    return StageResult.success;
  }

  Future<void> runStageMissions(StageData stage) async {
    final centerOffset = size / 2;
    final runId = ++_currentStageRunId;

    final sortedMissions = stage.missions.keys.toList()..sort();

    for (final missionNum in sortedMissions) {
      if (runId != _currentStageRunId) {
        // print('Stage run $runId cancelled (current: $_currentStageRunId)');
        return;
      }

      final parsedTime = _parseTimeLimitToSeconds(stage.timeLimit);
      if (parsedTime != null && parsedTime > 0) {
        startMissionTimer(parsedTime);
      } else {
        print(
          '[WARNING] Invalid or empty timeLimit: "${stage.timeLimit}" (timer not started)',
        );
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
        final position = centerOffset + flipY(Vector2(x, y));
        print('Spawning enemy at $position: ${enemy.shape}');

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

            // Movement
            final moveMatch = RegExp(
              r'\((-?\d+),\s*(-?\d+),\s*(-?\d+),\s*(-?\d+),\s*(\d+)\)',
            ).firstMatch(enemy.movement);
            print('Move match: ${enemy.movement}');
            if (moveMatch != null) {
              final x1 = double.parse(moveMatch.group(1)!);
              final y1 = double.parse(moveMatch.group(2)!);
              final x2 = double.parse(moveMatch.group(3)!);
              final y2 = double.parse(moveMatch.group(4)!);
              final speed = double.parse(moveMatch.group(5)!);

              final startPos = centerOffset + flipY(Vector2(x1, y1));
              final endPos = centerOffset + flipY(Vector2(x2, y2));
              shape.position = startPos;

              final distance = startPos.distanceTo(endPos);
              final travelTime = distance / speed;

              shape.add(
                MoveEffect.to(
                  endPos,
                  EffectController(
                    duration: travelTime,
                    alternate: true,
                    infinite: true,
                  ),
                ),
              );
              continue;
            }

            // Movement
            final cMatch = RegExp(
              r'C\((-?\d+),\s*(-?\d+),\s*(\d+),\s*(\d+)\)',
            ).firstMatch(enemy.movement);
            if (cMatch != null) {
              final cx = double.parse(cMatch.group(1)!);
              final cy = double.parse(cMatch.group(2)!);
              final r = double.parse(cMatch.group(3)!);
              final s = double.parse(cMatch.group(4)!); // degree per second

              final center = centerOffset + flipY(Vector2(cx, cy));
              final angularSpeed = s * math.pi / 180;

              shape.position = center + Vector2(r, 0); // 초기 위치

              shape.add(
                OrbitingComponent(
                  target: shape,
                  center: center,
                  radius: r,
                  angularSpeed: angularSpeed,
                ),
              );
              continue;
            }

            // Movement
            final dMatch = RegExp(
              r'D\((\d+),(\d+)\)',
            ).firstMatch(enemy.movement);
            if (dMatch != null && shape != null) {
              final a = double.parse(dMatch.group(1)!);
              final b = double.parse(dMatch.group(2)!);

              await add(shape); // 초기 visible 상태로 추가
              await shape.loaded;

              final blinking = BlinkingBehaviorComponent(
                shape: shape,
                visibleDuration: a,
                invisibleDuration: b,
              );

              blinkingMap[shape] = blinking;

              shape.parent?.add(blinking); // 같은 parent에 붙여줘야 shape 제어 가능
            }

            // Movement
            // DR(a,b): 깜빡이며 랜덤 위치로 재등장
            final drMatch = RegExp(
              r'DR\((\d+),(\d+)\)',
            ).firstMatch(enemy.movement);
            if (drMatch != null && shape != null) {
              final a = double.parse(drMatch.group(1)!);
              final b = double.parse(drMatch.group(2)!);

              await add(shape); // 초기에 등장
              await shape.loaded;

              final blinking = BlinkingBehaviorComponent(
                shape: shape,
                visibleDuration: a,
                invisibleDuration: b,
                isRandomRespawn: true,
                bounds: size,
              );

              blinkingMap[shape] = blinking;

              add(blinking);
              continue;
            }

            await Future.delayed(Duration(milliseconds: 100));
          }
        }
      }

      await waitUntilMissionCleared(spawnedThisMission);
    }
  }

  // 그냥 도형 다 죽였는지 여부
  // 추후 시간 제한 체크 여기에 추가...
  Future<StageResult> waitUntilMissionCleared(Set<Component> targets) async {
    while (true) {
      final remaining = targets.where((c) {
        final blinking = blinkingMap[c];

        if (c.isMounted) {
          return true;
        }
        if (!c.isMounted) {
          if (blinking != null && !blinking.isRemoving) {
            blinkingMap.remove(c);
            return true;
          }
        }

        if (c is UserRemovable && !(c as UserRemovable).wasRemovedByUser) {
          return true;
        }

        // 3. 그 외는 제거됨
        return false;
      }).toList();

      if (remaining.isEmpty) {
        print('Mission cleared');
        break;
      }

      await Future.delayed(Duration(milliseconds: 300));
    }

    return StageResult.success;
  }

  int _calculateStarRating(StageResult stgResult) {
    return 3;
  }

  double? _parseTimeLimitToSeconds(String raw) {
    if (raw.trim().isEmpty) return null;
    final s = raw.trim();

    // 1) MM:SS
    final mmss = RegExp(r'^(\d{1,2}):([0-5]?\d)$').firstMatch(s);
    if (mmss != null) {
      final m = int.parse(mmss.group(1)!);
      final sec = int.parse(mmss.group(2)!);
      return (m * 60 + sec).toDouble();
    }

    // 2) X분Y초 / X분
    final kr = RegExp(r'^(\d+)\s*분(?:\s*(\d+)\s*초)?$').firstMatch(s);
    if (kr != null) {
      final m = int.parse(kr.group(1)!);
      final sec = kr.group(2) != null ? int.parse(kr.group(2)!) : 0;
      return (m * 60 + sec).toDouble();
    }

    // 3) XmYs / Xm / Xs
    final en = RegExp(r'^(?:(\d+)\s*m)?\s*(?:(\d+)\s*s)?$').firstMatch(s);
    if (en != null && (en.group(1) != null || en.group(2) != null)) {
      final m = en.group(1) != null ? int.parse(en.group(1)!) : 0;
      final sec = en.group(2) != null ? int.parse(en.group(2)!) : 0;
      return (m * 60 + sec).toDouble();
    }

    // 4) 숫자만 → 초로 간주 (정수/실수)
    final numOnly = RegExp(
      r'^\d+(?:\.\d+)?$',
    ).firstMatch(s.replaceAll(' ', '').replaceAll('초', ''));
    if (numOnly != null) {
      return double.parse(numOnly.group(0)!);
    }

    // 못 읽음
    return null;
  }

  void startMissionTimer(double seconds) {
    missionTimeLimit = seconds;
    remainingTime = seconds;
    isTimeCritical = false;

    _timerPaused = false;
    _timerEndedNotified = false;
    _accumulator = 0;
    _lastShownTime = -1;

    timerBar.totalTime = seconds;
    timerBar.updateTime(remainingTime); // 초기 상태 반영
    print('[TIMER] startMissionTimer -> $seconds sec');
  }

  // timer update
  @override
  void update(double dt) {
    super.update(dt);

    if (_timerPaused) {
      return;
    }

    if (remainingTime > 0) {
      _accumulator += dt;
      if (_accumulator >= 1.0) {
        _accumulator -= 1.0;
        remainingTime -= 1;

        if (remainingTime != _lastShownTime) {
          _lastShownTime = remainingTime;
          // 필요할 때만 로그
          print('remainingTime: $remainingTime');
          timerBar.updateTime(remainingTime);
        }

        if (remainingTime <= 10) isTimeCritical = true;

        if (remainingTime <= 0 && !_timerEndedNotified) {
          _timerEndedNotified = true;
          // 마지막으로 0초 반영 후 더 이상 건드리지 않음
          timerBar.updateTime(0);
          // TODO: 타임오버 처리(스테이지 실패 등) 넣을 곳
          // print("Time's up!");
        }
      }
    }
  }

  void showAftermathScreen(StageResult result, int starCount, int stgIndex) {
    _timerPaused = true;

    final aftermath = AftermathScreen(
      result: result,
      starCount: starCount,
      stgIndex: stgIndex,
      screenSize: size,
      onContinue: () {
        // Move to next stage
        final nextIndex = stgIndex + 1;
        if (nextIndex < _allStages.length) {
          removeAll(children.where((c) => c is AftermathScreen).toList());
          runStageWithAftermath(nextIndex);
        } else {
          print("No more stages left!");
          // Optionally show game end screen
        }
      },
      onRetry: () {
        removeAll(children.where((c) => c is AftermathScreen).toList());
        runStageWithAftermath(stgIndex);
      },
      onPlay: () {
        removeAll(children.where((c) => c is AftermathScreen).toList());
        // Could start from stage 0 or a chosen stage
        runStageWithAftermath(stgIndex);
      },
      onMenu: () {
        print("Go to menu screen");
        // TODO: implement menu navigation
      },
    );

    add(aftermath);
  }
  // ===========================================================================================================

  Vector2 flipY(Vector2 point) {
    return Vector2(point.x, -point.y);
  }

  Vector2 _calculateCentroid(List<Vector2> points) {
    final sum = points.fold<Vector2>(Vector2.zero(), (a, b) => a + b);
    return sum / points.length.toDouble();
  }

  // ==== gestures detect ======================================================================================
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
        comp.wasRemovedByUser = true;
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

  // ===========================================================================================================

  // ==== temporary functions ======================================================================================
  void refreshGame() {
    print("Refreshing game!");

    // Clear user path
    userPath.clear();
    currentCircleCenter = null;
    currentCircleRadius = null;
    print('${children} before shape removal');
    blinkingMap.clear();
    children.whereType<BlinkingBehaviorComponent>().forEach((blinking) {
      blinking.removeFromParent();
    });

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
  // ===============================================================================================================

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
