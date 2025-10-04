import 'package:flame/components.dart';

import 'dart:async';
import 'dart:ui';
import 'package:figureout/src/functions/UserRemovable.dart';
import 'package:figureout/src/routes/AftermathScreen.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:figureout/src/temp/RefreshButton.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:figureout/src/components/CircleShape.dart';
import 'package:figureout/src/components/HexagonShape.dart';
import 'package:figureout/src/components/PentagonShape.dart';
import 'package:figureout/src/components/RectangleShape.dart';
import 'package:figureout/src/components/TriangleShape.dart';
import 'package:figureout/src/components/GameTimerComponent.dart';

import 'package:figureout/src/config.dart';

import 'package:figureout/src/functions/sheet_service.dart';
import 'package:figureout/src/functions/OrbitingComponent.dart';
import 'package:figureout/src/functions/BlinkingBehavior.dart';
import 'package:figureout/src/components/PauseButton.dart';
import 'PausedScreen.dart';

class OneSecondGame extends FlameGame with DragCallbacks, CollisionCallbacks, TapCallbacks {
  final math.Random _random = math.Random();

  // temporary function
  late RefreshButton refreshButton;
  // bool debugYN = true;
  
  //pause
  late PauseButton pauseButton;
  PausedScreen? pausedScreen;

  //stage data
  late StageData initialStage;

  int _currentStageIndex = 0;
  int _currentMissionIndex = 1;

  List<StageData> _allStages = [];

  // temp data
  int maxMissionIndex = 8;
  int maxStageIndex = 10;

  final SheetService sheetService = SheetService();

  //timer data
  Timer? countdownTimer;
  double remainingTime = 0;
  double missionTimeLimit = 0;
  bool isTimeCritical = false;
  late GameTimerComponent timerBar;
  late double _accumulator = 0;
  double _lastShownTime = -1;
  bool _timerEndedNotified = false;

  bool _timerPaused = false;
  bool _isTimeOver = false;

  double get _minPlayY => (timerBar.position.y + timerBar.size.y + 8.0);

  final Map<PositionComponent, BlinkingBehaviorComponent> blinkingMap = {};

  // screen data
  late final screenWidth;
  late final screenHeight;

  late PositionComponent screenArea;
  late PositionComponent playArea;

  late double playAreaScaleX;
  late double playAreaScaleY;

  // gestures
  Vector2? dragStart;
  Vector2? sliceStartPoint;
  Vector2? sliceEndPoint;
  List<Vector2> userPath = [];
  Vector2? currentCircleCenter;
  double? currentCircleRadius;
  
  //toggle debug
  int _debugTapCount = 0;
  double _lastTapTime = 0;

  void _applyDebugToTree(Component root, bool value) {
    root.debugMode = value;
    for (final child in root.children) {
      _applyDebugToTree(child, value);
    }
  }

  @override
  void onChildrenChanged(Component child, ChildrenChangeType type) {
    super.onChildrenChanged(child, type);
    // 새 컴포넌트가 추가될 때마다 현재 디버그 상태를 그대로 적용
    if (type == ChildrenChangeType.added) {
      _applyDebugToTree(child, debugMode);
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    screenWidth = size.x;
    screenHeight = size.y;

    screenArea = RectangleComponent(
      position: Vector2(size.x / 2, size.y / 2),
      size: size,
      anchor: Anchor.center,
      paint: Paint()..color = Colors.transparent,
    );
    add(screenArea);

    final availWidth = size.x - (UIsidePadding * 2);
    final availHeight = size.y - (UItopPadding);

    double playWidth, playHeight;

    if (size.x > rangeX) {
      double actualRatio = availWidth / availHeight;
      print("actual ratio = $actualRatio, aspectRatio = $aspectRatio");
      if(availWidth / availHeight > aspectRatio) {
        playHeight = availHeight;
        playWidth = playHeight * aspectRatio;
      } else {
        playWidth = availWidth;
        playHeight = playWidth / aspectRatio;
      }
    } else {
      if(availWidth / availHeight > aspectRatio) {
        playHeight = availHeight;
        playWidth = playHeight * aspectRatio;
      } else {
        playWidth = availWidth;
        playHeight = playWidth / aspectRatio;
      }
    }

    playWidth = math.min(playWidth, targetPlayWidth);
    playHeight = math.min(playHeight, targetPlayHeight);

    double playCenterX = ((size.x - playWidth) / 2) + (playWidth / 2);
    double playCenterY = UItopPadding + (playHeight / 2);

    // print('play area = ($playWidth, $playHeight)');
    playArea = RectangleComponent(
      position: Vector2(playCenterX, playCenterY),
      size: Vector2(playWidth, playHeight),
      anchor: Anchor.center,
      paint: Paint()..color = Colors.transparent,
    );
    add(playArea);

    // 로그 s
    double playX = playArea.width;
    double playY = playArea.height;

    print("playArea size = ($playX, $playY)");
    // 로그 e

    playAreaScaleX = playWidth / targetPlayWidth;
    playAreaScaleY = playHeight / targetPlayHeight;

    // Add refresh button to top-right corner
    refreshButton = RefreshButton(
      position: Vector2(size.x - 60, 40),
      onPressed: onRefresh,
    );
    add(refreshButton);
    
    pauseButton = PauseButton(
      position: Vector2(size.x*0.11, 40),
      onPressed: pauseGame,
    );
    add(pauseButton);

    timerBar = GameTimerComponent(
      totalTime: 60, // 기본값, 나중에 startMissionTimer에서 정확히 설정됨
      position: Vector2((size.x / 2) + 16, 80),
    );
    add(timerBar);

    try {
      // final stages = await sheetService.fetchData();
      _allStages = await sheetService.fetchData();
      if (_allStages.isNotEmpty) {
        print('Fetched stages: ${_allStages.toString()}');

        runStageWithAftermath(_currentStageIndex, _currentMissionIndex);
      }
    } catch (e) {
      print('Sheet fetch error: $e');
    }

    // TODO : make this as button
    debugMode = false;
  }

  @override
  void onMount() {
    // TODO: implement onMount
    super.onMount();

    // _clearAllShapes();
    // _spawnAllShapes();

    toggleDebug();
  }
  
  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    final tapPos = event.canvasPosition;
    final now = DateTime.now().millisecondsSinceEpoch.toDouble();

    // 오른쪽 위 구석 감지 (화면 폭/높이의 일부 영역)
    if (tapPos.x > size.x * 0.8 && tapPos.y < size.y * 0.2) {
      if (now - _lastTapTime < 1500) {
        print('tapped');
        _debugTapCount++;
      } else {
        _debugTapCount = 1;
      }
      _lastTapTime = now;

      if (_debugTapCount >= 5) {
        toggleDebug();
        _debugTapCount = 0;
      }
    }
  }
  
  //시간 패널티
  void applyTimePenalty(double seconds) {
    if (_isTimeOver) return;
    remainingTime = math.max(0, remainingTime - seconds);
    timerBar.updateTime(remainingTime);
    timerBar.flashPenalty();
    if (remainingTime <= 0 && !_timerEndedNotified) {
      _timerEndedNotified = true;
      _isTimeOver = true;
      timerBar.updateTime(0);
    }
  }

  //스폰 중단
  void _stopEnemyBehaviors() {
    for (final b in children.whereType<BlinkingBehaviorComponent>()) {
      b.removeFromParent();
    }
    blinkingMap.clear();
  }

  void _clearAllShapes() {
    children.whereType<CircleShape>().toList().forEach(
      (e) => e.removeFromParent(),
    );
    children.whereType<HexagonShape>().toList().forEach(
      (e) => e.removeFromParent(),
    );
    children.whereType<PentagonShape>().toList().forEach(
      (e) => e.removeFromParent(),
    );
    children.whereType<RectangleShape>().toList().forEach(
      (e) => e.removeFromParent(),
    );
    children.whereType<TriangleShape>().toList().forEach(
      (e) => e.removeFromParent(),
    );
  }

  void _onTimeOver() {
    if (_isTimeOver) return;
    _isTimeOver = true;
    _timerPaused = true; // 타이머 틱 중단
    _stopEnemyBehaviors(); // 깜빡임 중단
    _clearAllShapes(); // 화면 도형 즉시 클리어(반짝 없음)
  }

  // ==== running missions ======================================================================================

  // runStageWithAftermath -> runSingleMissions
  // 게임 구조 : stage 안에 자잘한 mission 들 존재, stage 끝나기 전 보스 존재
  Future<void> runStageWithAftermath(int stageIndex, int missionIndex) async {
    print("mission index = $missionIndex");

    if (stageIndex > _allStages.length) {
      print('all stages completed!');
      return;
    }

    final stage = _allStages[stageIndex];

    final result = await runSingleMissions(stage, missionIndex);

    final starRating = _calculateStarRating(result);
    // showAftermathScreen(result);
    showAftermathScreen(result, starRating, stageIndex);
  }

  Future<StageResult> runSingleMissions(StageData stage, int missionIndex) async {
    final centerOffset = playArea.size / 2;
    int runId = missionIndex;
    
    _stopEnemyBehaviors();
    _clearAllShapes();

    double? missionSeconds = stage.missionTimeLimits[runId];

    String tl = stage.timeLimit;
    double? stageSeconds;
    if (missionSeconds == null) {
      stageSeconds = _parseTimeLimitToSeconds(stage.timeLimit);
    }
    final chosen = missionSeconds ?? stageSeconds;
    if (chosen != null && chosen > 0) {
      startMissionTimer(chosen);
    } else {
      print(
        '[WARNING] Invalid or empty timeLimit: "${stage.timeLimit}" (timer not started)',
      );
    }

    print('current stage index = $runId');
    int stgLength = _allStages.length;
    maxMissionIndex = stage.missions.length;
    print('mission length = $maxMissionIndex');

    final enemies = stage.missions[runId]!;
    print(enemies);

    final spawnedThisMission = <Component>{};
    final currentWave = <Component>{};

    for (final enemy in enemies) {
      if (_isTimeOver) return StageResult.fail;
      if (_timerPaused) {
        // 게임이 resume될 때까지 기다림
        while (_timerPaused) {
          await Future.delayed(Duration(milliseconds: 100));
        }
      }
      if (enemy.command == 'wait') {
        final durationMatch = RegExp(r'(\d+\.?\d*)').firstMatch(enemy.shape);

        final duration = durationMatch != null
            ? double.tryParse(durationMatch.group(1)!) ?? 0.0
            : 0.0;

        if (duration == 0) {
          // wait 0: 지금까지 나온 도형들이 전부 없어질 때까지 대기
          if (currentWave.isNotEmpty) {
            await waitUntilMissionCleared(currentWave);
            currentWave.clear();
          }
        } else {
          // wait N: N초 지연만, 도형들은 계속 살아있음(동시 진행)
          await Future.delayed(
            Duration(milliseconds: (duration * 1000).toInt()),
          );
        }
        continue;
      }

      final posMatch = RegExp(
        r'\((-?\d+),\s*(-?\d+)\)',
      ).firstMatch(enemy.position);
      if (posMatch == null) continue;
      final x = double.parse(posMatch.group(1)!);
      final y = double.parse(posMatch.group(2)!);
      Vector2 position = Vector2(x, y);

      print('Spawning enemy at $position: ${enemy.shape}');

      PositionComponent? shape = spawnShape(enemy, position);

      if (shape != null) {

        double halfSizeX = shape.size.x;

        Vector2 actPosition = toPlayArea(flipY(Vector2(x, y)), halfSizeX, clampInside: true);

        shape.position = actPosition;

        final shapeRect = shape.toRect();
        final isWithinBounds =
            shapeRect.left >= 0 &&
            shapeRect.top >= 0 &&
            shapeRect.right <= screenWidth &&
            shapeRect.bottom <= screenHeight;

        print("is within bounds? = $isWithinBounds");

        if (isWithinBounds) {
          await add(shape);
          await shape.loaded;
          print('shape spawned: ${shape.position.toString()}');
          spawnedThisMission.add(shape);
          if(!_isDarkShape(shape)){
            currentWave.add(shape);
          }
          // Movement
          final moveMatch = RegExp(
            r'\((-?\d+),\s*(-?\d+),\s*(-?\d+),\s*(-?\d+),\s*(\d+)\)',
          ).firstMatch(enemy.movement);

          if (moveMatch != null) {
            final dx1 = double.parse(moveMatch.group(1)!);
            final dy1 = double.parse(moveMatch.group(2)!);
            final dx2 = double.parse(moveMatch.group(3)!);
            final dy2 = double.parse(moveMatch.group(4)!);
            final speed = double.parse(moveMatch.group(5)!); // px/sec

            // 스폰 위치(H열) 기준 상대 좌표(네가 쓰는 위가 +Y 좌표계라 flipY 유지)
            // 도형 화면 밖으로 안나가도록
            final p1 = toPlayArea(flipY(Vector2(dx1, dy1)), halfSizeX, clampInside: true);
            final p2 = toPlayArea(flipY(Vector2(dx2, dy2)), halfSizeX, clampInside: true);

            // shape는 nullable이므로 non-null 로컬로 캡쳐해서 클로저 경고 제거
            final comp = shape!;

            // 이전 이펙트 있으면 제거
            for (final e in List.of(comp.children.whereType<Effect>())) {
              e.removeFromParent();
            }

            // 1) 스폰: H열 위치에서 잠깐 보임
            comp.position = position;

            // 2) 사라졌다가(p1로 재스폰) → 3) p1<->p2 왕복
            const showDelay = 0.25; // 최초 노출 시간 (필요시 조절)
            final originalScale = comp.scale.clone();

            // (a) showDelay 후 0까지 축소하여 "사라짐" (DelayEffect 대신 startDelay 사용)
            comp.add(
              ScaleEffect.to(
                Vector2.zero(),
                EffectController(duration: 0.10, startDelay: showDelay),
                onComplete: () {
                  // (b) p1에서 재스폰(위치 이동) 후 다시 보이게(확대)
                  comp.position = p1;

                  comp.add(
                    ScaleEffect.to(
                      originalScale,
                      EffectController(duration: 0.50),
                      onComplete: () {
                        // (c) 본 이동: p1 <-> p2 왕복 (무한)
                        final segTime = p1.distanceTo(p2) / speed;
                        comp.add(
                          MoveEffect.to(
                            p2,
                            EffectController(
                              duration: segTime,
                              alternate: true,
                              infinite: true,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
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

          Rect _timerRectWorld() => timerBar.toRect();

          // Movement
          final dMatch = RegExp(
            r'D\(\s*(\d+)\s*,\s*(\d+)\s*\)',
          ).firstMatch(enemy.movement);
          if (dMatch != null && shape != null) {
            final a = double.parse(dMatch.group(1)!);
            final b = double.parse(dMatch.group(2)!);

            await add(shape); // 초기 visible 상태로 추가
            await shape.loaded;

            final r = _timerRectWorld();
            const pad = 8.0;
            const margin = 50.0;

            final halfW = shape.size.x / 2;
            final halfH = shape.size.y / 2;
            // 타이머바 "아래" 영역 (Y는 아래로 증가)
            final minYCenter = r.bottom + pad + halfH;
            final maxYCenter = size.y - margin - halfH;

            // 화면 좌우 여백 고려
            final minXCenter = margin + halfW;
            final maxXCenter = size.x - margin - halfW;

            // 시작 위치도 즉시 범위 안으로
            shape.position = Vector2(
              shape.position.x.clamp(minXCenter, maxXCenter),
              shape.position.y.clamp(minYCenter, maxYCenter),
            );

            final blinking = BlinkingBehaviorComponent(
              shape: shape,
              visibleDuration: a,
              invisibleDuration: b,
              isRandomRespawn: false,
              xMin: minXCenter,
              xMax: maxXCenter,
              yMin: minYCenter,
              yMax: maxYCenter,
            );

            blinkingMap[shape] = blinking;

            // shape.parent?.add(blinking); // 같은 parent에 붙여줘야 shape 제어 가능
            add(blinking);
            continue;
          }

          // Movement
          // DR(a,b): 깜빡이며 랜덤 위치로 재등장
          final drMatch = RegExp(
            r'DR\(\s*(\d+)\s*,\s*(\d+)\s*\)',
          ).firstMatch(enemy.movement);
          if (drMatch != null && shape != null) {
            final a = double.parse(drMatch.group(1)!);
            final b = double.parse(drMatch.group(2)!);

            await add(shape); // 초기에 등장
            await shape.loaded;

            final r = _timerRectWorld();
            const pad = 8.0;
            const margin = 50.0;

            final halfW = shape.size.x / 2;
            final halfH = shape.size.y / 2;

            // 타이머바 "아래" 영역 (Y는 아래로 증가)
            final minYCenter = r.bottom + pad + halfH;
            final maxYCenter = size.y - margin - halfH;

            // 화면 좌우 여백 고려
            final minXCenter = margin + halfW;
            final maxXCenter = size.x - margin - halfW;

            // 시작 위치도 즉시 범위 안으로
            shape.position = Vector2(
              shape.position.x.clamp(minXCenter, maxXCenter),
              shape.position.y.clamp(minYCenter, maxYCenter),
            );

            final blinking = BlinkingBehaviorComponent(
              shape: shape,
              visibleDuration: a,
              invisibleDuration: b,
              isRandomRespawn: true,
              xMin: minXCenter,
              xMax: maxXCenter,
              yMin: minYCenter,
              yMax: maxYCenter,
            );

            blinkingMap[shape] = blinking;

            add(blinking);

            continue;
          }

          // Movement: M(angle, speed, stopX, stopY)
          final MMatch = RegExp(
            r'M\((-?\d+)\s*,\s*(\d+)\s*,\s*([A-Za-z0-9\-.]+)\)',
          ).firstMatch(enemy.movement);

          if (MMatch != null) {
            print("Mmatch");

            final angleDeg = double.parse(MMatch.group(1)!);
            final speed = double.parse(MMatch.group(2)!); // px/sec
            final stopY = MMatch.group(3)!;

            print("stopY = $stopY");
            double yCoord = position.y;
            if(stopY.contains("Y")) {
              yCoord = size.y;
            } else {
              yCoord = double.parse(stopY);
            }

            // 목표 지점 (에디터 좌표 → 실제 플레이좌표)
            final target = toPlayArea(flipY(Vector2(position.x, yCoord)), halfSizeX, clampInside: false);

            print("target = (${target.x}, ${target.y})");

            // shape는 nullable이므로 non-null 로컬 변수로 캡쳐
            final comp = shape!;

            // 이전 이펙트 제거
            for (final e in List.of(comp.children.whereType<Effect>())) {
              e.removeFromParent();
            }

            // 1) 스폰 위치에서 잠깐 보임
            comp.position = position;

            const showDelay = 0.25;
            final originalScale = comp.scale.clone();

            // (a) 잠깐 있다가 축소
            comp.add(
              ScaleEffect.to(
                Vector2.zero(),
                EffectController(duration: 0.10, startDelay: showDelay),
                onComplete: () {
                  // (b) target 방향에서 다시 스폰 후 확대
                  comp.position = position; // 처음 위치에서 시작
                  comp.add(
                    ScaleEffect.to(
                      originalScale,
                      EffectController(duration: 0.50),
                      onComplete: () {
                        // (c) target 으로 이동 → 도착하면 멈춤
                        final distance = comp.position.distanceTo(target);
                        final duration = distance / speed;

                        comp.add(
                          MoveEffect.to(
                            target,
                            EffectController(
                              duration: duration,
                              curve: Curves.linear,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            );

            continue;
          }


          await Future.delayed(Duration(milliseconds: 100));
        }
      }
    }

    StageResult ret = await waitUntilMissionCleared(spawnedThisMission);
    await waitUntilMissionCleared(currentWave);
    // return StageResult.success;
    return ret;
  }

  PositionComponent? spawnShape(EnemyData enemy, Vector2 position) {
    PositionComponent? shape;
    
    // 다크 도형 여부: (-1) 인식(띄어쓰기 허용)
    final bool isDark = RegExp(r'\(\s*-1\s*\)').hasMatch(enemy.shape);
    // 일반 에너지 파싱(양수). 다크면 굳이 쓰지 않음.
    int _parseEnergy(String s, int def) {
      final m = RegExp(r'\(\s*(\d+)\s*\)').firstMatch(s);
      return m != null ? int.parse(m.group(1)!) : def;
    }

    void Function()? penalty = () => applyTimePenalty(5);

    if (enemy.shape.startsWith('Circle')) {
      final energy = isDark ? 0 : _parseEnergy(enemy.shape, 1);
      shape = CircleShape(position, energy, isDark: isDark, onForbiddenTouch: penalty);
    } else if (enemy.shape.startsWith('Rectangle')) {
      final energy = isDark ? 0 : _parseEnergy(enemy.shape, 1);
      shape = RectangleShape(position, energy, isDark: isDark, onForbiddenTouch: penalty);
    } else if (enemy.shape.startsWith('Pentagon')) {
      final energy = isDark ? 0 : _parseEnergy(enemy.shape, 10);
      shape = PentagonShape(position, energy, isDark: isDark, onForbiddenTouch: penalty);
    } else if (enemy.shape.startsWith('Triangle')) {
      final energy = isDark ? 0 : _parseEnergy(enemy.shape, 1);
      shape = TriangleShape(position, energy, isDark: isDark, onForbiddenTouch: penalty);
    } else if (enemy.shape.startsWith('Hexagon')) {
      final energy = isDark ? 0 : _parseEnergy(enemy.shape, 1);
      shape = HexagonShape(position, energy, isDark: isDark, onForbiddenTouch: penalty);
    }

    return shape;
  }

  bool _isDarkShape(Component c) {
    if (c is CircleShape) return c.isDark;
    if (c is RectangleShape) return c.isDark;
    if (c is PentagonShape) return c.isDark;
    if (c is TriangleShape) return c.isDark;
    if (c is HexagonShape) return c.isDark;
    return false;
  }

  // 그냥 도형 다 죽였는지 여부
  Future<StageResult> waitUntilMissionCleared(Set<Component> targets) async {
    while (true) {
      if (_isTimeOver) {
        _stopEnemyBehaviors();
        _clearAllShapes();
        return StageResult.fail;
      }
      final remaining = targets.where((c) {
        if (_isDarkShape(c)) return false;
        final blinking = blinkingMap[c];

        if (c.isMounted) {
          return true;
        }
        if (blinking != null) {
          if (!blinking.isRemoving && blinking.willReappear) {
            // blinkingMap.remove(c);
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

  // Convert from your coordinate system to play area coordinates
  Vector2 toPlayArea(Vector2 yourCoordinates, double actShapePading, {bool clampInside = true}) {
    double playX;
    double playY;

    print("my coordinate = (${yourCoordinates.x}, ${yourCoordinates.y}), shape size = $actShapePading");
    // print("x axis : ${playArea.width / 2}, y axis : ${playArea.height / 2}");
    // print("min : ${playArea.topLeftPosition}, max : ${playArea.toRect().bottomRight}");

    double normalizedX = (yourCoordinates.x - minX) / rangeX;
    double normalizedY = (yourCoordinates.y - minY) / rangeY;

    playX = (normalizedX * playArea.width);
    playY = (normalizedY * playArea.height);

    if (clampInside) {
      // 화면 안에 들어오도록 강제 (스폰 시점)
      playX = playX.clamp(shapePadding / 2, playArea.width - shapePadding / 2);
      playY = playY.clamp(shapePadding / 2, playArea.height - shapePadding / 2);
    }

    print("X = $playX, Y = $playY");

    return Vector2(playX, playY);
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

  void toggleDebug() {
    debugMode = !debugMode; // Toggle debugMode
    _applyDebugToTree(this, debugMode);
    if (debugMode) {
      print('Debug mode is now ON');
    } else {
      print('Debug mode is now OFF');
    }
  }

  void onRefresh() {
    print("Refreshing Game...");
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

    runStageWithAftermath(_currentStageIndex, _currentMissionIndex);
  }

  void startMissionTimer(double seconds) {
    missionTimeLimit = seconds;
    remainingTime = seconds;
    isTimeCritical = false;

    _timerPaused = false;
    _timerEndedNotified = false;
    _accumulator = 0;
    _lastShownTime = -1;
    _isTimeOver = false;

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
          _isTimeOver = true;
        }
      }
    }
  }

  void showAftermathScreen(StageResult result, int starCount, int stgIndex) {
    _timerPaused = true;
    
    _stopEnemyBehaviors();
    _clearAllShapes();

    print("stage result is = $result");
    final aftermath = AftermathScreen(
      result: result,
      starCount: starCount,
      stgIndex: stgIndex,
      screenSize: size,
      onContinue: () {
        // move to next stage
        if(_currentStageIndex < maxStageIndex) {
          if(_currentMissionIndex < maxMissionIndex) {
            _currentMissionIndex = _currentMissionIndex + 1;
          } else {
            print("last mission - move to next stage");
            _currentStageIndex = _currentStageIndex + 1;
            _currentMissionIndex = 0;
          }

          print("stage index = $_currentStageIndex, mission index = $_currentMissionIndex");
          print("playing next stage/mission");
          removeAll(children.where((c) => c is AftermathScreen).toList());
          runStageWithAftermath(_currentStageIndex, _currentMissionIndex);

        } else {
          print("No more stages left!");
        }
      },
      onRetry: () {
        removeAll(children.where((c) => c is AftermathScreen).toList());
        runStageWithAftermath(_currentStageIndex, _currentMissionIndex);
      },
      onPlay: () { // play next stage
        removeAll(children.where((c) => c is AftermathScreen).toList());
        // Could start from stage 0 or a chosen stage
// move to next stage
        if(_currentStageIndex < maxStageIndex) {
          if(_currentMissionIndex < maxMissionIndex) {
            _currentMissionIndex = _currentMissionIndex + 1;
          } else {
            print("last mission - move to next stage");
            _currentStageIndex = _currentStageIndex + 1;
            _currentMissionIndex = 0;
          }

          print("stage index = $_currentStageIndex, mission index = $_currentMissionIndex");
          print("playing next stage/mission");
          removeAll(children.where((c) => c is AftermathScreen).toList());
          runStageWithAftermath(_currentStageIndex, _currentMissionIndex);

        } else {
          print("No more stages left!");
        }
      },
      onMenu: () {
        print("Go to menu screen");
        // TODO: implement menu navigation
      },
    );
    print("aftermath Screen defined");
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
        if (comp.isDark) {
          // 다크 삼각형: 제거 금지 + 패널티
          applyTimePenalty(5);
          print('[PENALTY] Dark Triangle touched');
        } else {
          print('[REMOVE] Triangle at ${comp.position}');
          comp.wasRemovedByUser = true;
          comp.removeFromParent();
        }
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



  // @override
  // void update(double dt) {
  //   super.update(dt);

  //   if (remainingTime > 0) {
  //     _accumulator += dt;
  //     if (_accumulator >= 1.0) {
  //       _accumulator -= 1.0;
  //       remainingTime -= 1;

  //       if (remainingTime != _lastShownTime) {
  //         _lastShownTime = remainingTime;
  //         // 필요할 때만 로그
  //         print('remainingTime: $remainingTime');
  //         timerBar.updateTime(remainingTime);
  //       }

  //       if (remainingTime <= 10) isTimeCritical = true;

  //       if (remainingTime <= 0 && !_timerEndedNotified) {
  //         _timerEndedNotified = true;
  //         // 마지막으로 0초 반영 후 더 이상 건드리지 않음
  //         timerBar.updateTime(0);
  //         // TODO: 타임오버 처리(스테이지 실패 등) 넣을 곳
  //         // print("Time's up!");
  //       }
  //       // if (remainingTime <= 10) isTimeCritical = true;
  //       // if (remainingTime <= 0) {
  //       //   remainingTime = 0;
  //       //   print("Time's up!");
  //       // }
  //       // timerBar.updateTime(remainingTime);
  //     }
  //   }
  // }

  void pauseGame() {
    print("blinkingMap:${blinkingMap.values}");
    if (pausedScreen != null && pausedScreen!.isMounted) return;

    _timerPaused = true;

    for (final b in blinkingMap.values) {
      print('Pausing ${b.shape}');
      b.isPaused = true;
    }

    pausedScreen = PausedScreen(
      screenSize: size,
      onResume: () {
        resumeGame();
      },
      onRetry: () {
        resumeGame();
        refreshGame();
      },
      onMenu: () {
        print("Go to menu");
      },
    );

    add(pausedScreen!);
  }

  void resumeGame() {
    print("resumed");
    _timerPaused = false;

    for (final b in blinkingMap.values) {
      b.isPaused = false;
      
    }

    if (pausedScreen != null) {
      pausedScreen!.removeFromParent();
      pausedScreen = null;
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
