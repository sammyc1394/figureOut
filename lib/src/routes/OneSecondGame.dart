import 'package:figureout/src/behaviors/BCommand.dart';
import 'package:figureout/src/behaviors/MCommand.dart';
import 'package:figureout/src/behaviors/ZCommand.dart';
import 'package:figureout/src/routes/MainMenu.dart';
import 'package:figureout/src/routes/StageSelect.dart';
import 'package:flame/components.dart';

import 'dart:async';
import 'dart:ui';
import 'package:figureout/src/functions/UserRemovable.dart';
import 'package:figureout/src/routes/AftermathScreen.dart';
import 'package:flame/collisions.dart';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:figureout/src/temp/RefreshButton.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:figureout/main.dart';

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
import 'package:go_router/go_router.dart';
import '../behaviors/CCommand.dart';
import '../behaviors/DDrCommand.dart';
import '../behaviors/LCommand.dart';
import '../behaviors/shapeBehavior.dart';
import '../components/PreparedEnemy.dart';
import '../functions/OrderableShape.dart';
import 'MissionSelect.dart';
import 'PausedScreen.dart';
import '../functions/DepthAware.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OneSecondGame extends FlameGame
    with DragCallbacks, CollisionCallbacks, TapCallbacks {
  // ← 이것 추가 {
  final BuildContext navigatorContext;
  final List<StageData> stages;
  final int stageIndex;
  final int missionIndex;

  OneSecondGame({
    required this.navigatorContext,
    required this.stages,
    required this.stageIndex,
    required this.missionIndex,
  });

  final math.Random _random = math.Random();

  //Mission execution lock
  bool _isMissionRunning=false;

  // temporary function
  late RefreshButton refreshButton;
  // bool debugYN = true;

  //pause
  late PauseButton pauseButton;
  PausedScreen? pausedScreen;

  //stage data
  late StageData initialStage;

  late int _selectedStageIndex;
  late int _selectedMissionIndex;

  int _runToken = 0;

  List<StageData> _allStages = [];

  // temp data
  late int maxMissionIndex;
  late int maxStageIndex;

  // for Refresh
  Completer<void>? _refreshCompleter;

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
  bool _isPausedGlobally = false;

  bool _isTimeOver = false;
  
  // For Continue feature
  static const double minTimeLimit = 10.0;
  double initialMaxTime = 0.0;
  double currentMissionTime = 0.0;
  double _lastRoundStartTime = 0.0;
  int _lastRoundStartIndex = 0;
  bool _isContinuing = false;

  double get _minPlayY => (timerBar.position.y + timerBar.size.y + 8.0);

  final Map<PositionComponent, BlinkingBehaviorComponent> blinkingMap = {};

  // screen data
  late final screenWidth;
  late final screenHeight;

  late PositionComponent screenArea;
  late PositionComponent playArea;

  late double playAreaScaleX;
  late double playAreaScaleY;
  double _lastValidRangeX = 1;
  double _lastValidRangeY = 1;


  // order (circle / other shapes)
  List<OrderableShape> _orderedShapes = [];
  int _currentOrderIndex = 0;
  bool _hasOrder = false;


  // gestures
  Vector2? dragStart;
  Vector2? sliceStartPoint;
  Vector2? sliceEndPoint;
  List<Vector2> userPath = [];
  Vector2? currentCircleCenter;
  double? currentCircleRadius;

  int _globalSpawnCounter = 100;
  void _syncRelativeDepthVisuals() {
    final depthShapes = children.whereType<DepthAware>().toList();
    if (depthShapes.isEmpty) return;

    // Sort by priority: Bottom (lowest) to Top (highest)
    // Later spawned shapes have higher priority
    depthShapes.sort((a, b) => a.priority.compareTo(b.priority));

    final n = depthShapes.length;
    // We sort bottom-to-top (priority increasing)
    depthShapes.sort((a, b) => a.priority.compareTo(b.priority));

    for (int i = 0; i < n; i++) {
        final shapeA = depthShapes[i];
        int overlapsOnTop = 0;

        // Check only shapes ABOVE shapeA (index > i) that physically overlap
        for (int j = i + 1; j < n; j++) {
            final shapeB = depthShapes[j];
            if (shapeB.toRect().overlaps(shapeA.toRect())) {
                overlapsOnTop++;
            }
        }

        // Rank calculation: Subtle 0.05 decrease per overlapping layer on top.
        // Clamped at 0.85 (min darkness).
        final double rank = (1.0 - (overlapsOnTop * 0.05)).clamp(0.85, 1.0);
        shapeA.updateVisualsByRank(rank);
    }
  }

  @override
  void onChildrenChanged(Component child, ChildrenChangeType type) {
    super.onChildrenChanged(child, type);
    if (child is DepthAware) {
      _syncRelativeDepthVisuals();
    }
    // 새 컴포넌트가 추가될 때마다 현재 디버그 상태를 그대로 적용
    if (type == ChildrenChangeType.added) {
      _applyDebugToTree(child, debugMode);
    }
  }

  //toggle debug
  int _debugTapCount = 0;
  double _lastTapTime = 0;

  Vector2? _dragLastPos; // 마지막 드래그 좌표
  Vector2? _dragStartPos; // 드래그 시작 좌표
  int _dragStartTimeMs = 0;

  static const int _tapWindowMs = 180; // 이 시간 이하면 탭으로 간주
  static const double _tapMoveMax = 18.0; // 이 거리 이하면 탭으로 간주
  static const double _cornerRatio = 0.18; // 화면의 18% 정사각형 영역을 코너로 간주
  static const int _debugWindowMs = 1500; // 디버그 5연타 유효 시간
  static const int _debugNeedTaps = 5;

  StageResult? _pendingResult;
  bool _missionResolved = false;

  void _applyDebugToTree(Component root, bool value) {
    root.debugMode = value;
    for (final child in root.children) {
      _applyDebugToTree(child, value);
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
      priority: 0,
    );
    add(screenArea);

    final availWidth = size.x - (UIsidePadding * 2);
    final availHeight = size.y - (UItopPadding);

    double playWidth, playHeight;

    if (size.x > rangeX) {
      double actualRatio = availWidth / availHeight;
      print("actual ratio = $actualRatio, aspectRatio = $aspectRatio");
      if (availWidth / availHeight > aspectRatio) {
        playHeight = availHeight;
        playWidth = playHeight * aspectRatio;
      } else {
        playWidth = availWidth;
        playHeight = playWidth / aspectRatio;
      }
    } else {
      if (availWidth / availHeight > aspectRatio) {
        playHeight = availHeight;
        playWidth = playHeight * aspectRatio;
      } else {
        playWidth = availWidth;
        playHeight = playWidth / aspectRatio;
      }
    }

    playWidth = math.min(playWidth, targetPlayWidth);
    playHeight = math.min(playHeight, targetPlayHeight);

    double playCenterX = size.x / 2;
    double playCenterY = UItopPadding + (playHeight / 2);

    // print('play area = ($playWidth, $playHeight)');
    playArea = RectangleComponent(
      position: Vector2(playCenterX, playCenterY),
      size: Vector2(playWidth, playHeight),
      anchor: Anchor.center,
      paint: Paint()..color = Colors.transparent,
      priority: 0,
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
    )
      ..priority = 3000;
    add(refreshButton);

    pauseButton = PauseButton(
      position: Vector2(size.x * 0.11, 40),
      onPressed: pauseGame,
    )
      ..priority = 3000;
    add(pauseButton);

    timerBar = GameTimerComponent(
      totalTime: 60, // 기본값, 나중에 startMissionTimer에서 정확히 설정됨
      position: Vector2((size.x / 2) + 16, 80),
    )
      ..priority = 3000;
    add(timerBar);

    try {
      // _allStages = await sheetService.fetchData();
      _allStages = stages;

      maxStageIndex = _allStages.length;
      maxMissionIndex = _allStages[stageIndex].missions.length;

      _selectedStageIndex = stageIndex;
      _selectedMissionIndex = missionIndex + 1;

      if (_allStages.isNotEmpty) {
        print('Fetched stages: ${_allStages.toString()}');

        _runToken++;
        runStageWithAftermath(_selectedStageIndex, _selectedMissionIndex);
      }
    } catch (e) {
      print('Sheet fetch error: $e');
    }

    debugMode = false;

    Future.delayed(Duration.zero, () {
      debugMode = false;
      _applyDebugToTree(this, false);
    });
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
    // super.onTapDown(event);
    event.continuePropagation = true; // refresh 등 다른 컴포넌트 동작하기 위해 터치이벤트 전달

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

    // 사각형 슬라이스 시작 위치 추가
    // userPath.clear();
    // userPath.add(event.canvasPosition);
    // print("=== userPath start point added : ${userPath.first} ==========");
  }

  //시간 패널티
  void applyTimePenalty(double seconds) {
    if (_isTimeOver) return;
        
    // Sync both legacy and new timer variables
    currentMissionTime = math.max(0, currentMissionTime - seconds);
    remainingTime = currentMissionTime; 

    updateTimerUI();
    timerBar.flashPenalty();
    
    if (currentMissionTime <= 0 && !_timerEndedNotified) {
      _timerEndedNotified = true;
      // _isTimeOver = true;
      timerBar.updateTime(0);
      _onTimeOver();
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
    // if (_missionResolved) return;

    // if (_isPausedGlobally) return;
    if (_isTimeOver) return;
    // if (_timerPaused) return;
    // _missionResolved = true;
    _isTimeOver = true;
    _timerPaused = true; // 타이머 틱 중단
    
    _stopEnemyBehaviors(); // Blink 등 중단

    for (final b in blinkingMap.values) {
      b.isPaused = true;
    }

    if (_isPausedGlobally) {
      _pendingResult = StageResult.fail;
      return;
    }

    removeAll(children.whereType<AftermathScreen>().toList());

    Future.microtask(() async{
      // if (_isPausedGlobally){
      //   _pendingResult=StageResult.fail;
      //   return;
      // } 
      final starRating = _calculateStarRating(StageResult.fail);
      showAftermathScreen(
        StageResult.fail,
        starRating,
        _selectedStageIndex,
        _selectedMissionIndex,
      );
    });
  }

  Future<void> _runSequentialZMovement({
    required PositionComponent shape,
    required String movementRaw,
  }) async {
    // mount 보장
    while (!shape.isMounted) {
      await Future<void>.delayed(Duration.zero);
    }

    // 최초 스폰 위치 (Back 왕복/Repeat 시작점)
    final Vector2 spawnPosition = shape.position.clone();

    final lines = movementRaw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    bool isRepeatLine(String s) {
      final t = s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      return t == 'repeat';
    }

    bool isBackLine(String s) {
      final t = s.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      return t == 'back';
    }

    final bool hasRepeat = lines.any(isRepeatLine);
    final bool hasBack = lines.any(isBackLine);

    final zLines = lines.where((e) => e.startsWith('Z')).toList();
    if (zLines.isEmpty) return;

    final zReg = RegExp(
      r'^Z\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(\d+(?:\.\d+)?)\s*\)$',
    );

    Future<void> moveLinear(Vector2 target, double speed) async {
      if (!shape.isMounted) return;

      // 기존 이펙트 제거
      for (final e in List.of(shape.children.whereType<Effect>())) {
        e.removeFromParent();
      }

      final fromV = worldToVirtualPlay(shape.position);
      final toV = worldToVirtualPlay(target);
      final distV = fromV.distanceTo(toV);

      if (speed <= 0 || distV <= 0) {
        shape.position = target;
        return;
      }

      final duration = distV / speed;
      final completer = Completer<void>();

      shape.add(
        MoveEffect.to(
          target,
          EffectController(duration: duration, curve: Curves.linear),
          onComplete: () {
            if (!completer.isCompleted) completer.complete();
          },
        ),
      );

      await completer.future;
    }

    Future<void> runOnce() async {
      final List<Vector2> visited = [];
      final List<double> speeds = [];

      // 1) Z 순차 이동 (Forward)
      for (final z in zLines) {
        if (!shape.isMounted) return;

        final m = zReg.firstMatch(z);
        if (m == null) continue;

        final zx = double.parse(m.group(1)!);
        final zy = double.parse(m.group(2)!);
        final speed = double.parse(m.group(3)!);

        final target = toPlayArea(
          flipY(Vector2(zx, zy)),
          shape.size.x / 2,
          clampInside: true,
        );

        visited.add(target.clone());
        speeds.add(speed);

        await moveLinear(target, speed);
      }

      if (!shape.isMounted) return;

      // 2) Back이 있으면: 역순으로 스폰까지 복귀 (그리고 여기서 끝)
      //    (Back만 있어도 반복되어야 하므로, 반복 여부는 바깥 while에서 결정)
      if (hasBack && visited.isNotEmpty) {
        for (int i = visited.length - 1; i >= 0; i--) {
          if (!shape.isMounted) return;

          final Vector2 backTarget = (i == 0) ? spawnPosition : visited[i - 1];
          final double backSpeed = speeds[i] > 0 ? speeds[i] : 1.0;

          await moveLinear(backTarget, backSpeed);
        }
        return;
      }

      // 3) Back도 Repeat도 없으면: 마지막 Z 위치에서 멈춤 (스폰 복귀 금지)
      if (!hasRepeat) {
        return;
      }

      // 4) Repeat만 있으면: 다음 루프를 위해 스폰으로 복귀 후 반복
      final double lastSpeed =
          speeds.isNotEmpty && speeds.last > 0 ? speeds.last : 1.0;

      await moveLinear(spawnPosition, lastSpeed);
    }

    // "Back이 있으면 Repeat가 없어도 왕복 반복"이 되어야 함
    final bool loopForever = hasRepeat || hasBack;

    if (loopForever) {
      while (shape.isMounted) {
        await runOnce();
      }
    } else {
      await runOnce();
    }
  }

  void _hardResetMissionState() {
    _missionResolved = false;
    _timerPaused = false;
    _isTimeOver = false;
    _timerEndedNotified = false;
    _globalSpawnCounter = 100;

    for (final b in blinkingMap.values) {
      b.removeFromParent();
    }
    blinkingMap.clear();

    for (final c in children.toList()) {
      if (c is CircleShape ||
          c is RectangleShape ||
          c is PentagonShape ||
          c is TriangleShape ||
          c is HexagonShape ||
          c is Effect) {
        c.removeFromParent();
      }
    }
  }

  // ==== running missions ======================================================================================

  // runStageWithAftermath -> runSingleMissions
  // 게임 구조 : stage 안에 자잘한 mission 들 존재, stage 끝나기 전 보스 존재
  Future<void> runStageWithAftermath(int stageIndex, int missionIndex) async {
    if (_refreshCompleter != null) {
      await _refreshCompleter!.future;
    }

    print("stage index = $stageIndex, mission index = $missionIndex");
    // if (_isPausedGlobally) return;
    if (_isMissionRunning) {
      print('[BLOCK] runStageWithAftermath ignored: mission already running');
      return;
    }
    _isMissionRunning = true;
    _runToken++;
    final localToken = _runToken;

    try {
      if (stageIndex >= _allStages.length) return;

      _selectedStageIndex = stageIndex;
      _selectedMissionIndex = missionIndex;

      _isContinuing = false; // Fresh start

      final stage = _allStages[stageIndex];
      final result = await runSingleMissions(stage, missionIndex);

      // 다른 실행이 시작됐으면 결과 무시
      if (localToken != _runToken) return;
      if (_isPausedGlobally) {
        _pendingResult = result;
        return;
      }

      if (result != StageResult.cancelled) {
        
        final starRating = _calculateStarRating(result);
        showAftermathScreen(
          result,
          starRating,
          stageIndex,
          missionIndex,
        );
      }
    } finally {
      if (localToken == _runToken) {
        _isMissionRunning = false;
      }
    }
  }

  Future<StageResult> runSingleMissions(
    StageData stage,
    int missionIndex,{
    int startIndex = 0,
  }) async {
    if (_refreshCompleter != null) {
      await _refreshCompleter!.future;
    }


    // 게임 시작전 토큰확인
    int runId = _runToken;

    // 이전 스테이지 혹은 새로고침 전 남은 데이터가 없는지 확인 및 이전 데이터 제거
    _hardResetMissionState();

    _stopEnemyBehaviors();
    _clearAllShapes();

    // 시간 데이터 분석
    double? missionSeconds = stage.missionTimeLimits[missionIndex];

    String tl = stage.timeLimit;
    double? stageSeconds;
    if (missionSeconds == null) {
      stageSeconds = _parseTimeLimitToSeconds(stage.timeLimit);
    }
    final chosen = missionSeconds ?? stageSeconds;
    
    if (!_isContinuing) {
      initialMaxTime = chosen ?? 0.0;
      _lastRoundStartTime = initialMaxTime;
      currentMissionTime = initialMaxTime;
      _lastRoundStartIndex = 0;
    } else {
      // Use the previous starting time to halve, not the current 0 seconds
      _lastRoundStartTime = math.max(minTimeLimit, _lastRoundStartTime / 2.0);
      currentMissionTime = _lastRoundStartTime;
    }

    final timeToStart = currentMissionTime;

    // UI Gauge basis: Fix totalTime to the initial mission time
    timerBar.totalTime = initialMaxTime;

    if (timeToStart > 0) {
      startMissionTimer(timeToStart);
    } else {
      print(
        '[WARNING] Invalid or empty timeLimit: "${stage.timeLimit}" (timer not started)',
      );
    }

    // 게임데이터 분석 시작
    print('current stage index = $runId');
    int stgLength = _allStages.length;
    print('mission length = ${stage.missions.length}');

    final enemies = stage.missions[missionIndex]!;
    print("enemy data = $enemies");

    final spawnedThisMission = <Component>{};
    final currentWave = <Component>{};
    // final preparedEnemies = <PreparedEnemy>[];

    print("[BEFORE LOOP] enemy processing start : ${enemies.length}");
    // 에너미 데이터
    // startIndex 를 굳이 파라미터에서 initialize 한 이유가 있나?
    for (int i = startIndex; i < enemies.length; i++) {
      final enemy = enemies[i];

      // run token 불일치시 취소
      print("[TOKEN CHECK] runId = $runId, run token = $_runToken, logic survive y/n = ${runId == _runToken}");

      if(runId != _runToken) {
        print("[TOKEN CHECK] run token not matching, stage cancelled");
        return StageResult.cancelled;
      }

      // 게임 시간 체크
      // 시간 오버시 실패 및 게임 일시정지 정리
      if (_isTimeOver) return StageResult.fail;
      if (_isPausedGlobally) {
        // 게임이 resume될 때까지 기다림
        while (_isPausedGlobally) {
          if (_isTimeOver) return StageResult.fail;
          await Future.delayed(Duration(milliseconds: 100));
        }
      }

      // wait 명령어 체크
      if (enemy.command == 'wait') {
        print("[WAIT] processing wait command");
        final durationMatch = RegExp(r'(\d+\.?\d*)').firstMatch(enemy.shape);

        final duration = durationMatch != null
            ? double.tryParse(durationMatch.group(1)!) ?? 0.0
            : 0.0;

        if (duration == 0) {
          // wait 0: 지금까지 나온 도형들이 전부 없어질 때까지 대기
          await Future<void>.delayed(Duration.zero);

          if (currentWave.isNotEmpty) {
            _initOrder();
            await waitUntilMissionCleared(Set<Component>.from(currentWave));
            print("current wave size : ${currentWave.length}");
          }

          // 다크도형까지 제거위함
          for (final comp in List<Component>.from(spawnedThisMission)) {
            comp.removeFromParent();
          }

          currentWave.clear();
          spawnedThisMission.clear();
          print("[WAIT] processing over");
        } else {
          // wait N: N초 지연만, 도형들은 계속 살아있음(동시 진행)
          await Future.delayed(
            Duration(milliseconds: (duration * 1000).toInt()),
          );
        }
        
        // Check if failed during wait/clear
        if (_isTimeOver) return StageResult.fail;

        // Update round start for continue feature
        _lastRoundStartIndex = i + 1;
        print('[CONTINUE] Checkpoint updated to index $_lastRoundStartIndex');
        continue;
      }

      final spawnStart = DateTime.now();
      print('[SPAWN START] index=$i time=${spawnStart.millisecondsSinceEpoch}');

      final prepared = buildPreparedEnemy(
        enemy: enemy,
        flipY: flipY,
        toPlayArea: toPlayArea,
        checkBehavior: checkBehavior,
      );

      if (prepared == null) continue;

      print("[PREPARED CHECK END] prepared size : (${prepared.customSize.x}, ${prepared.customSize.y})");

      await spawnPreparedEnemy(
        prepared,
        spawnedThisMission,
        currentWave,
      );

      await Future.delayed(Duration(milliseconds: 100));

      final loopEnd = DateTime.now();
      print('[LOOP END] index=$i total=${loopEnd.difference(spawnStart).inMilliseconds}ms');
    }

    print("[AFTER LOOP] enemy processing over");
    StageResult ret = await waitUntilMissionCleared(currentWave);
    return ret;
  }

  PreparedEnemy? buildPreparedEnemy({
    required EnemyData enemy,
    required Vector2 Function(Vector2) flipY,
    required Vector2 Function(Vector2, double, {bool clampInside}) toPlayArea,
    required ShapeBehavior? Function(String movement, Vector2 actPosition) checkBehavior,
  }) {
    // 1. 도형 & 사이즈 파싱
    String shapeType = "";
    Vector2 size = Vector2.zero();
    print("[PreparedEnemy] enemy name : ${enemy.shape}");
    if (enemy.shape.startsWith('Circle')) {
      final scale = _parseScale(enemy.shape);
      size = Vector2.all(80 * scale);

      print("[PreparedEnemy] size = (${size.x}, ${size.y})");

      shapeType = "Circle";

    } else if (enemy.shape.startsWith('Rectangle')) {
      // Rectangle은 직접 크기 지정이 있거나, 없으면 스케일 적용
      size = _parseRectSize(enemy.shape) ?? Vector2(40, 80);

      // 만약 Rectangle2 처럼 스케일만 적혀있다면 기본(40,80)에 스케일 적용
      if (_parseRectSize(enemy.shape) == null) {
        final scale = _parseScale(enemy.shape);
        // 기본값이 Rectangle4라고 가정하면 scale 1.0 -> 40,80
        // Rectangle2 -> scale 0.5 -> 20,40
        size = Vector2(40 * scale, 80 * scale);
      }

      shapeType = "Rectangle";

    } else if (enemy.shape.startsWith('Pentagon')) {
      final scale = _parseScale(enemy.shape);
      size = Vector2.all(100 * scale);

      shapeType = "Pentagon";

    } else if (enemy.shape.startsWith('Triangle')) {
      final scale = _parseScale(enemy.shape);
      size = Vector2.all(70 * scale);

      shapeType = "Triangle";

    } else if (enemy.shape.startsWith('Hexagon')) {
      final scale = _parseScale(enemy.shape);
      size = Vector2.all(100 * scale);

      shapeType = "Hexagon";

    }

    // 2. 에너지 및 금지도형 파싱
    final energy = enemy.energy;

    bool isDark = false;
    if(enemy.energy == -1) {
      isDark = true;
    }

    // 4. order
    final int? order = enemy.order;

    // 5. 좌표 변환
    final posMatch = RegExp(
      r'\((-?\d+),\s*(-?\d+)\)',
    ).firstMatch(enemy.position);
    if (posMatch == null) {
      throw FormatException('Invalid position: ${enemy.position}');
    }
    final x = double.parse(posMatch.group(1)!);
    final y = double.parse(posMatch.group(2)!);

    final halfSizeX = size.x / 2;
    final halfSizeY = size.y / 2;

    Vector2 actPosition = toPlayArea(
      flipY(Vector2(x, y)),
      halfSizeX,
      clampInside: true,
    );

    final localPos = worldToVirtualPlay(actPosition);
    print('playLocal = (${localPos.x}, ${localPos.y})');

    // 6. behavior 파싱 (이미 만든 구조 활용)
    final behavior = checkBehavior(
      enemy.movement,
      actPosition,
    );

    // 7. PreparedEnemy 생성
    return PreparedEnemy(
      shapeType: shapeType,
      customSize: size,
      energy: energy,
      isDark: isDark,
      actPosition: actPosition,
      order: order,
      behavior: behavior,
      attackTime: enemy.attackSeconds,
      attackDamage: enemy.attackDamage,
    );
  }

  Future<void> spawnPreparedEnemy(
      PreparedEnemy enemy,
      Set<Component> spawnedThisMission,
      Set<Component> currentWave,
      ) async {
    final shape = _createShapeFromPrepared(enemy);

    shape.position = enemy.actPosition;

    await add(shape);
    await shape.loaded;

    // behavior attach
    if (enemy.behavior != null) {
      ShapeBehavior behavior = enemy.behavior!;
      await behavior.apply(shape);
    }

    spawnedThisMission.add(shape);

    if (!enemy.isDark) {
      currentWave.add(shape);
    }

    _updateShapeVisualsByPriority(shape as PositionComponent);
  }

  void _updateShapeVisualsByPriority(PositionComponent shape) {
    if (shape is DepthAware) {
      (shape as DepthAware).updateVisualsByPriority();
    }
  }

  void _applyBlendModeToShape(PositionComponent shape, BlendMode mode) {
    // Deprecated: handled by DepthAware
  }

  PositionComponent _createShapeFromPrepared(PreparedEnemy enemy) {
    PositionComponent? shape;

    double tp = enemy.attackDamage ?? 5;
    penalty() => applyTimePenalty(tp.abs());

    bool isAttackable = false;
    if (enemy.attackTime != null) isAttackable = true;


    switch (enemy.shapeType) {
      case "Circle":
        shape = CircleShape(
          enemy.actPosition,
          enemy.energy,
          isDark: enemy.isDark,
          isAttackable: isAttackable,
          onForbiddenTouch: penalty,
          attackTime: enemy.attackTime,
          onExplode: penalty,
          customSize: enemy.customSize,
          order: enemy.order,
          onInteracted: _onOrderInteracted,
          onRemoved: _onOrderedShapeRemoved,
        );
      case "Rectangle":
        shape = RectangleShape(
          enemy.actPosition,
          enemy.energy,
          isDark: enemy.isDark,
          onForbiddenTouch: penalty,
          isAttackable: isAttackable,
          attackTime: enemy.attackTime,
          onExplode: penalty,
          customSize: enemy.customSize,
          order: enemy.order,
          onInteracted: _onOrderInteracted,
        );

      case "Triangle":
        shape = TriangleShape(
          enemy.actPosition,
          enemy.energy,
          isDark: enemy.isDark,
          onForbiddenTouch: penalty,
          attackTime: enemy.attackTime,
          onExplode: penalty,
          customSize: enemy.customSize,
        );

      case "Pentagon":
        shape = PentagonShape(
          enemy.actPosition,
          enemy.energy,
          isDark: enemy.isDark,
          onForbiddenTouch: penalty,
          attackTime: enemy.attackTime,
          onExplode: penalty,
          customSize: enemy.customSize,
        );

      case "Hexagon":
        shape = HexagonShape(
          enemy.actPosition,
          enemy.energy,
          isDark: enemy.isDark,
          onForbiddenTouch: penalty,
          attackTime: enemy.attackTime,
          onExplode: penalty,
          customSize: enemy.customSize,
        );

      default:
        throw Exception("Unknown shapeType");
    }

    if (shape is DepthAware) {
        shape.priority = _globalSpawnCounter++;
    }
    _syncRelativeDepthVisuals();
    return shape;
  }

  // 1) 스케일 파싱 (Circle2 -> 2 -> 0.5배, Default=4 -> 1.0배)
  //    1~8: 0.25배씩 증가 (1=0.25, 4=1.0, 8=2.0)
  //    9~ : 0.5배씩 증가 (9=2.5, 10=3.0 ...)
  double _parseScale(String s) {
    // "Circle2", "Circle4_02", "Pentagon12" 등에서 숫자 추출
    // 도형 이름(알파벳) 뒤에 오는 숫자
    final m = RegExp(r'[a-zA-Z]+(\d+)').firstMatch(s);
    if (m != null) {
      print ("[Scale parse] m not null : $m ");
      final val = int.parse(m.group(1)!);
      if (val <= 8) {
        return val * 0.25;
      } else {
        // 8번이 2.0이므로, 거기서부터 0.5씩 증가
        return 2.0 + (val - 8) * 0.5;
      }
    }
    print ("[Scale parse] m null : 1.0 ");
    return 1.0; // 기본값 (Circle == Circle4)
  }

  // 2) Rectangle 직접 크기 파싱 (Rectangle40:200)
  Vector2? _parseRectSize(String s) {
    final m = RegExp(r'Rectangle(\d+):(\d+)').firstMatch(s);
    if (m != null) {
      print ("[Scale parse] m : $m ");
      final w = double.parse(m.group(1)!);
      final h = double.parse(m.group(2)!);
      return Vector2(w, h);
    }
    return null;
  }

  ShapeBehavior? checkBehavior(
      String raw,
      Vector2 actPosition
      ) {

    print("[Behavior check] parsing command into behavior");
    final lMatch = RegExp(
      r'^(?:L)?\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(\d+(?:\.\d+)?)\s*\)$'
    ).firstMatch(raw.trim());

    if (lMatch != null) {
      print("[Behavior check] returning L command");

      return LCommand(
        movementRaw: raw,
        flipY: flipY,
        toPlayArea: toPlayArea,
      );
    }

    final cMatch = RegExp(
      r'C\((-?\d+),\s*(-?\d+)\)',
    ).firstMatch(raw);

    if (cMatch != null) {
      print("[Behavior check] returning c command");
      final r = double.parse(cMatch.group(1)!);
      final s = double.parse(cMatch.group(2)!);

      return CCommand(
        radius: r,
        degreePerSec: s,
        actPosition: actPosition,
        flipY: flipY,
        toPlayArea: toPlayArea,
      );
    }

    Rect timerRectWorld() => timerBar.toRect();

    final drMatch = RegExp(
      r'DR\(\s*(\d+(?:\.\d+)?)\s*,\s*(\d+(?:\.\d+)?)\s*\)',
    ).firstMatch(raw);

    if (drMatch != null) {
      print("[Behavior check] returning dr command");
      final a = double.parse(drMatch.group(1)!);
      final b = double.parse(drMatch.group(2)!);

      return DDrCommand(
        visibleDuration: a,
        invisibleDuration: b,
        isRandomRespawn: true,
        timerRectWorld: timerRectWorld,
        gameSize: size,
        blinkingMap: blinkingMap,
      );
    }

    final dMatch = RegExp(
      r'D\(\s*(\d+(?:\.\d+)?)\s*,\s*(\d+(?:\.\d+)?)\s*\)',
    ).firstMatch(raw);

    if (dMatch != null) {
      print("[Behavior check] returning d command");

      final a = double.parse(dMatch.group(1)!);
      final b = double.parse(dMatch.group(2)!);

      return DDrCommand(
        visibleDuration: a,
        invisibleDuration: b,
        isRandomRespawn: false,
        timerRectWorld: timerRectWorld,
        gameSize: size,
        blinkingMap: blinkingMap,
      );
    }

    final mMatch = RegExp(
      r'M\((-?\d+)\s*,\s*(\d+)\s*,\s*([A-Za-z0-9\-.]+)\)',
    ).firstMatch(raw);

    if (mMatch != null) {
      print("[Behavior check] returning m command");

      final angle = double.parse(mMatch.group(1)!);
      final speed = double.parse(mMatch.group(2)!);
      final stopY = mMatch.group(3)!;

      return MCommand(
        angleDeg: angle,
        speed: speed,
        stopY: stopY,
        position: actPosition,
        size: size,
        flipY: flipY,
        toPlayArea: toPlayArea,
      );
    }

    if (raw.contains('Z(')) {
      print("[Behavior check] returning z command");

      return ZCommand(
        movementRaw: raw,
        flipY: flipY,
        toPlayArea: toPlayArea,
        worldToVirtualPlay: worldToVirtualPlay,
      );
    }

    final bMatch = RegExp(
      r'B\(\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(\d+(?:\.\d+)?)\s*\)',
    ).firstMatch(raw);

    if (bMatch != null) {
      final x0 = double.parse(bMatch.group(1)!);
      final y0 = double.parse(bMatch.group(2)!);
      final speed = double.parse(bMatch.group(3)!);

      return BCommand(
        startEditor: Vector2(x0, y0),
        directionWorld: actPosition, // 이미 toPlayArea 끝난 월드 좌표
        speed: speed,
        flipY: flipY,
        toPlayArea: toPlayArea,
        playAreaRect: () => playArea.toRect(),
      );
    }

    return null;
  }

  bool _isVisualEffectComponent(Component c) {
    // Flame Effect는 물론이고, 너가 만든 "xxxDisappearEffect" 같은 것도 잡기
    if (c is Effect) return true;

    final name = c.runtimeType.toString();
    if (name.contains('DisappearEffect')) return true;
    if (name.contains('ExplosionEffect')) return true;
    if (name.contains('SliceEffect')) return true;

    return false;
  }

  Future<void> _markMissionCleared(int stageIndex, int missionNo) async {
    final prefs = await SharedPreferences.getInstance();

    final key = 'stage_${stageIndex}_mission_${missionNo}_cleared';
    
    print("SAVE KEY: $key");
    
    await prefs.setBool(
      'stage_${stageIndex}_mission_${missionNo}_cleared',
      true,
    );
  }

  Future<void> _saveMissionProgressIfNeeded(StageResult result) async {
    if (result != StageResult.success) return;

    await _markMissionCleared(
      _selectedStageIndex,
      _selectedMissionIndex,
    );
  }

  bool _hasAnyActiveVisualEffectsInTree() {
    bool found = false;

    bool isAttachedToDarkShape(Component node) {
      Component? current = node;

      while (current != null) {
        if (_isDarkShape(current)) return true;
        current = current.parent;
      }

      return false;
    }

    void walk(Component node) {
      if (found) return;

      if (_isVisualEffectComponent(node)) {
        // 🔥 금지도형에 붙은 effect면 무시
        if (!isAttachedToDarkShape(node)) {
          found = true;
          return;
        }
      }

      for (final child in node.children) {
        walk(child);
        if (found) return;
      }
    }

    for (final c in children) {
      walk(c);
      if (found) break;
    }

    return found;
  }

  // 그냥 도형 다 죽였는지 여부
    Future<StageResult> waitUntilMissionCleared(Set<Component> targets) async {
      // add 직후 같은 프레임 race 방지
      await Future<void>.delayed(Duration.zero);

      print('[CLEAR CHECK] start wave size=${targets.length}');

      // to get log
      // 순서도형이 마지막에 오는 경우 아래 로그 찍으면 에러남
      // print("[CLEAR CHECK] mounted = ${targets.first.isMounted}");
      // print("[CLEAR CHECK] parent = ${targets.first.parent}");
      // print("[CLEAR CHECK] dark shape? ${_isDarkShape(targets.first)}");

      while (true) {
      // 1) 화면에 남아있는 모든 비주얼 이펙트(Effect + custom effect component) 끝날 때까지 대기
        if (_hasAnyActiveVisualEffectsInTree()) {
          await Future.delayed(const Duration(milliseconds: 60));
          continue;
        }

        if (_isTimeOver) return StageResult.fail;

        final remaining = targets.where((c) {
          // 1) 다크 도형 제외
          if (_isDarkShape(c)) return false;

          // 2) 아직 트리에 붙어 있으면(=애니메이션 중 포함) 무조건 남아있는 것으로 간주
          if (c.isMounted) return true;

          // 3) mount 해제면 기본 cleared
          //    단, blinking(D/DR)은 "다시 돌아올 예정"이면 남아있음 처리
          if (c is PositionComponent) {
            final blinking = blinkingMap[c];
            if (blinking != null) {
              if (!blinking.isRemoving && blinking.willReappear) return true;
            }
          }

          return false;
        }).toList();

        if (remaining.isEmpty) {
          print('Mission cleared');
          break;
        }
        // else {
        //   print('Still left : ${remaining.length}');
        // }

        await Future.delayed(const Duration(milliseconds: 120));
      }

      return StageResult.success;
    }


  bool _isDarkShape(Component c) {
    if (c is CircleShape) return c.isDark;
    if (c is RectangleShape) return c.isDark;
    if (c is PentagonShape) return c.isDark;
    if (c is TriangleShape) return c.isDark;
    if (c is HexagonShape) return c.isDark;
    return false;
  }

  bool _onOrderInteracted(OrderableShape c) {
    // order 없는 도형은 항상 패스

    print('[GAME] shape order YN(c.order == null) check = ${c.order == null}');
    if (c.order == null) return true;

    // 1) order 퍼즐인지 아닌지 판단
    print('[GAME] order shape YN(_hasOrder) = $_hasOrder');

    // 만약 모든 순서 도형을 제거한 상태라면 남은 도형 자유 터치 가능
    if (_currentOrderIndex >= _orderedShapes.length) {
      return true;
    }

    print('[GAME] order shape YN (order from shape)= ${c.order == null}');

    // 순서 도형이 남아있는데, 순서 없는 다른 도형을 눌렀다면 터치 금지 (패널티 처리 유도)
    if (c.order == null) return false;

    // 2) order 퍼즐이고 순서가 맞는지 판단
    final expected = _orderedShapes[_currentOrderIndex];

    print('[GAME] shape input checking for validity. validity = ${identical(c, expected)}');
    return identical(c.order, expected.order);
  }

  void _onOrderedShapeRemoved() {
    _currentOrderIndex++;
    print('[ORDER] next index = $_currentOrderIndex');
  }


  void _initOrder() {
    print("[ORDER] order reset");
    _orderedShapes = children
        .whereType<OrderableShape>()
        // RectangleShape는 슬라이스 전용 순서(_orderedRects)로 관리, 여기설 제외
        .where((c) => c.order != null && c is! RectangleShape)
        .toList()
      ..sort((a, b) => a.order!.compareTo(b.order!));

    _currentOrderIndex = 0;
    _hasOrder = _orderedShapes.isNotEmpty;
  }

  // 화면에 살아있는 사각형 중 가장 낮은 order 반환
  RectangleShape? _getExpectedRect() {
    RectangleShape? expected;
    for (final rect in children.whereType<RectangleShape>()) {
      if (rect.order != null && rect.count > 0 && rect.parent != null) {
        if (expected == null || rect.order! < expected.order!) {
          expected = rect;
        }
      }
    }
    return expected;
  }

  // 슬라이스 경로에 닿는 사각형들이 순서 규칙을 만족하는지 검증
  // 순서 있는 사각형이 경로에 포함될 경우, 가장 낮은 order가 현재 기대 순서와 같아야 함
  // 경로가 사각형에 처음 닿는 path index를 반환
  int _firstContactIndex(RectangleShape rect, List<Vector2> path) {
    final bounds = rect.toRect();
    for (int i = 0; i < path.length - 1; i++) {
      final p1 = path[i];
      final p2 = path[i + 1];
      if (bounds.contains(Offset(p1.x, p1.y)) ||
          bounds.contains(Offset(p2.x, p2.y))) {
        return i;
      }
      // 선분-사각형 교차 확인
      final intersections = rect.getLineRectangleIntersections(p1, p2, bounds);
      if (intersections.isNotEmpty) return i;
    }
    return path.length; // 미취시 가장 뒤로
  }


  // Convert from your coordinate system to play area coordinates
  Vector2 toPlayArea(
    Vector2 yourCoordinates,
    double actShapePadding, {
    bool clampInside = true,
  }) {
    if (rangeX > 0 && rangeY > 0) {
      _lastValidRangeX = rangeX;
      _lastValidRangeY = rangeY;
    }

    final safeRangeX = _lastValidRangeX;
    final safeRangeY = _lastValidRangeY;

    // 1) playArea 전역 영역 계산
    final double playMinX = playArea.position.x - playArea.size.x / 2;
    final double playMinY = playArea.position.y - playArea.size.y / 2;
    final double playMaxX = playArea.position.x + playArea.size.x / 2;
    final double playMaxY = playArea.position.y + playArea.size.y / 2;

    // 2) 도형 중심의 이동 가능한 최소/최대 (반지름/반폭 보정)
    final double minCenterX = playMinX + actShapePadding;
    final double maxCenterX = playMaxX - actShapePadding;
    final double minCenterY = playMinY + actShapePadding;
    final double maxCenterY = playMaxY - actShapePadding;

    print(
      "[COORDINATE] my coordinate = (${yourCoordinates.x}, ${yourCoordinates.y}), shape size = $actShapePadding",
    );

    // 3) 에디터 좌표 정상화
    final double normalizedX =
    ((yourCoordinates.x - minX) / safeRangeX).clamp(0.0, 1.0);

    final double normalizedY =
        ((yourCoordinates.y - minY) / safeRangeY).clamp(0.0, 1.0);

    // 4) playArea 내부 상대 좌표 → 절대 좌표 변환
    double playX = minCenterX + (normalizedX * (maxCenterX - minCenterX));
    double playY = minCenterY + (normalizedY * (maxCenterY - minCenterY));

    // 5) 도형이 playArea 밖으로 나가지 않게 중심 위치 clamp
    if (clampInside) {
      if (minCenterX > maxCenterX) {
        // 도형이 화면보다 가로로 더 큰 경우: 화면 중앙 X
        playX = playArea.position.x;
      } else {
        playX = playX.clamp(minCenterX, maxCenterX);
      }

      if (minCenterY > maxCenterY) {
        // 도형이 화면보다 세로로 더 큰 경우: 화면 중앙 Y
        playY = playArea.position.y;
      } else {
        playY = playY.clamp(minCenterY, maxCenterY);
      }
    }

    final virtual = worldToVirtualPlay(Vector2(playX, playY));
    print(
      "Max (x,y) = (${virtual.x.toStringAsFixed(1)}, ${virtual.y.toStringAsFixed(1)})",
    );

    return Vector2(playX, playY);
  }

  Vector2 worldToPlayLocal(Vector2 worldPos) {
    final double playMinX = playArea.position.x - playArea.size.x / 2;
    final double playMinY = playArea.position.y - playArea.size.y / 2;

    // playArea 왼쪽 위를 (0,0)으로 보는 로컬 좌표
    return Vector2(worldPos.x - playMinX, worldPos.y - playMinY);
  }

  Vector2 worldToVirtualPlay(Vector2 worldPos) {
    final local = worldToPlayLocal(worldPos); // 0 ~ playArea.size
    final vx = local.x / playArea.size.x * targetPlayWidth;
    final vy = local.y / playArea.size.y * targetPlayHeight;
    return Vector2(vx, vy);
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

  Future<void> onRefresh() async {
    if (_refreshCompleter != null) {
      await _refreshCompleter!.future;
      return;
    }

    _refreshCompleter = Completer<void>();
    try {
      _isContinuing = false;
      _lastRoundStartIndex = 0;

      if (_isPausedGlobally) return;

      print("Refreshing Game...");

      // refresh 이후 기존에 돌고있던 runSingleMission 취소 위함
      _isMissionRunning = false; // 이전 미션 강제 종료 허용
      _runToken++;

      userPath.clear();
      currentCircleCenter = null;
      currentCircleRadius = null;
      blinkingMap.clear();

      // 결과 화면도 제거
      removeAll(children.whereType<AftermathScreen>().toList());

      children.whereType<BlinkingBehaviorComponent>()
          .forEach((b) => b.removeFromParent());

      children.whereType<CircleShape>().forEach((s) => s.removeFromParent());
      children.whereType<RectangleShape>().forEach((s) => s.removeFromParent());
      children.whereType<PentagonShape>().forEach((s) => s.removeFromParent());
      children.whereType<TriangleShape>().forEach((s) => s.removeFromParent());
      children.whereType<HexagonShape>().forEach((s) => s.removeFromParent());

      // 화면에 남은 도형이 완전히 제거될 때까지 대기 (최대 1.5초 안전망)
      final deadline = DateTime.now().add(const Duration(milliseconds: 1500));
      bool hasShapes() => children.any((c) =>
          c is CircleShape ||
          c is RectangleShape ||
          c is PentagonShape ||
          c is TriangleShape ||
          c is HexagonShape ||
          c is AftermathScreen);

      while (hasShapes() && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      print('[REFRESH] All shapes cleared. Proceeding with fetch.');

      final newStages = await sheetService.fetchData();
      if (newStages.isEmpty) {
        print("새로 불러온 데이터가 비어있음");
        return;
      }

      _allStages = newStages;

      // 기존 오브젝트, 타이머, 이펙트 다 정리
      _stopEnemyBehaviors();
      _clearAllShapes();
      
      print("stage hash: ${_allStages[_selectedStageIndex].hashCode}");

      _refreshCompleter?.complete();
      _refreshCompleter = null;

      // 동일 스테이지 / 미션으로 재시작
      runStageWithAftermath(_selectedStageIndex, _selectedMissionIndex);
    } catch (e, st) {
      _refreshCompleter?.completeError(e, st);
      _refreshCompleter = null;
      rethrow;
    }
  }

  void startMissionTimer(double seconds) {
    currentMissionTime = seconds;
    isTimeCritical = false;

    _timerPaused = false;
    _timerEndedNotified = false;
    _accumulator = 0;
    _lastShownTime = -1;
    _isTimeOver = false;

    // NOTE: timerBar.totalTime is already set in runSingleMissions
    updateTimerUI();
    print('[TIMER] startMissionTimer -> $seconds sec (Basis: ${timerBar.totalTime})');
  }

  void updateTimerUI() {
    timerBar.updateTime(currentMissionTime);
    remainingTime = currentMissionTime; // Sync with legacy if needed
  }

  // timer update
  @override
  void update(double dt) {
    super.update(dt);

    if (_isPausedGlobally) {
      return;
    }

    if (_timerPaused && !_isTimeOver) {
      return;
    }

    if (currentMissionTime > 0) {
      _accumulator += dt;
      if (_accumulator >= 1.0) {
        _accumulator -= 1.0;
        currentMissionTime -= 1;

        if (currentMissionTime != _lastShownTime) {
          _lastShownTime = currentMissionTime;
          // 필요할 때만 로그
          print('currentMissionTime: $currentMissionTime');
          updateTimerUI();
        }

        if (currentMissionTime <= 10) isTimeCritical = true;

        if (currentMissionTime <= 0 && !_timerPaused) {
          _timerEndedNotified = true;
          // 마지막으로 0초 반영 후 더 이상 건드리지 않음
          currentMissionTime = 0;
          updateTimerUI();
          // TODO: 타임오버 처리(스테이지 실패 등) 넣을 곳
          // print("Time's up!");
          if (!_isTimeOver) {
            print('[UPDATE] Time is up → triggering _onTimeOver()');
            _onTimeOver();
          }
        }
      }
    }
  }

  Future<void> showAftermathScreen(
    StageResult result,
    int starCount,
    int stgIndex,
    int msnIndex,
  ) async {
    print("RESULT = $result");

    for (final shape in children.whereType<PositionComponent>()) {
      for (final b in shape.children.whereType<BounceMoveComponent>()) {
        b.removeFromParent();
      }
    }
    if (_isPausedGlobally){
      _pendingResult=result;
      return;
    }
    if (_missionResolved) return;
    _missionResolved = true;
    _timerPaused = true;

    if (result == StageResult.success) {
      _stopEnemyBehaviors();
      _clearAllShapes();
      await _markMissionCleared(
        _selectedStageIndex,
        _selectedMissionIndex,
      );

      await Future.delayed(const Duration(milliseconds: 100));
    }

    final stage = _allStages[_selectedStageIndex];
    final int missionNo = _selectedMissionIndex; // 이미 1-based
    final String msnTitle = stage.missionTitle[missionNo] ?? '';

    print("stage result is = $result");
    final aftermath = AftermathScreen(
      result: result,
      starCount: starCount,
      msnIndex: msnIndex,
      stgIndex: stgIndex,
      msnTitle: msnTitle,
      screenSize: size,
      onContinue: () {
        print('[AFTERMATH] Continue pressed.');
        removeAll(children.whereType<AftermathScreen>().toList());
        _resumeFromFailure();
      },
      onRetry: onRefresh,
      //     () {
      //   removeAll(children.whereType<AftermathScreen>().toList());
      //
      //   _isContinuing = false;
      //   _lastRoundStartIndex = 0;
      //
      //   _isMissionRunning = false;
      //   _runToken++;
      //
      //   runStageWithAftermath(_selectedStageIndex, _selectedMissionIndex);
      // },
      onPlay: () {
        // play next stage
        removeAll(children.whereType<AftermathScreen>().toList());

        final isLastStage = _selectedStageIndex >= maxStageIndex - 1;
        final isLastMission = _selectedMissionIndex >= maxMissionIndex;

        if (isLastStage && isLastMission) {
          print("All stages cleared → go to menu");

          rootNavigatorKey.currentContext!.go(
            '/stages',
            extra: stages,
          );

          return;
        }

        // Could start from stage 0 or a chosen stage
        // move to next stage
        if (_selectedStageIndex < maxStageIndex) {
          if (_selectedMissionIndex < maxMissionIndex) {
            _selectedMissionIndex = _selectedMissionIndex + 1;
          } else {
            print("last mission - move to next stage");
            _selectedStageIndex = 0;
            _selectedMissionIndex = 0;


          }

          print(
            "stage index = $_selectedStageIndex, mission index = $_selectedMissionIndex",
          );
          print("playing next stage/mission");
          removeAll(children.whereType<AftermathScreen>().toList());
          runStageWithAftermath(_selectedStageIndex, _selectedMissionIndex);
        } else {
          print("No more stages left!");
        }
      },
      onMenu: () {
        print("Go to menu screen");
        removeAll(children.whereType<AftermathScreen>().toList());

        rootNavigatorKey.currentContext!.push(
          '/missions',
          extra: {"stages": stages, "index": _selectedStageIndex},
        );
      },
    );
    print("aftermath Screen defined");
    add(aftermath);
  }

  void _resumeFromFailure() {
    print('[RESUME] Resuming failed mission from last round...');

    // Remove aftermath screen
    removeAll(children.whereType<AftermathScreen>().toList());

    _isTimeOver = false;
    _timerPaused = false;
    _timerEndedNotified = false;
    isTimeCritical = false;

    // 남은 시간 리셋 (예: 타임오버된 경우 10초 부여)
    // Set continuing flag
    _isContinuing = true;

    final int localToken = ++_runToken;

    // Reset run token to stop previous mission loop if it's still running
    // _isMissionRunning = false;
    // _runToken++;

    // Restart mission from the last saved round index
    final stage = _allStages[_selectedStageIndex];
    print('[RESUME] Restarting Stage $_selectedStageIndex, Mission $_selectedMissionIndex from index $_lastRoundStartIndex');
    
    runSingleMissions(
      stage,
      _selectedMissionIndex,
      startIndex: _lastRoundStartIndex,
    ).then((result) {
      if (localToken != _runToken) {
        print('[RESUME] outdated mission ignored');
        return;
      }

      final starRating = _calculateStarRating(result);

      if (result != StageResult.cancelled) {
        showAftermathScreen(
          result,
          starRating,
          _selectedStageIndex,
          _selectedMissionIndex,
        );
      }
    });
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

  int _orientation(Vector2 a, Vector2 b, Vector2 c) {
    final v = (b.y - a.y) * (c.x - b.x) - (b.x - a.x) * (c.y - b.y);
    const eps = 1e-9;
    if (v.abs() < eps) return 0;     // collinear
    return (v > 0) ? 1 : 2;          // 1: clockwise, 2: counterclockwise
  }

  bool _onSegment(Vector2 a, Vector2 b, Vector2 c) {
    // b is on segment ac (collinear assumed)
    return b.x >= math.min(a.x, c.x) - 1e-9 &&
        b.x <= math.max(a.x, c.x) + 1e-9 &&
        b.y >= math.min(a.y, c.y) - 1e-9 &&
        b.y <= math.max(a.y, c.y) + 1e-9;
  }

  bool _doLinesIntersect(Vector2 p1, Vector2 p2, Vector2 q1, Vector2 q2) {
    final o1 = _orientation(p1, p2, q1);
    final o2 = _orientation(p1, p2, q2);
    final o3 = _orientation(q1, q2, p1);
    final o4 = _orientation(q1, q2, p2);

    // general case
    if (o1 != o2 && o3 != o4) return true;

    // special collinear cases
    if (o1 == 0 && _onSegment(p1, q1, p2)) return true;
    if (o2 == 0 && _onSegment(p1, q2, p2)) return true;
    if (o3 == 0 && _onSegment(q1, p1, q2)) return true;
    if (o4 == 0 && _onSegment(q1, p2, q2)) return true;

    return false;
  }

  bool _isPathClosed(List<Vector2> path) {
  if (path.length < 5) return false;

  const double minLength = 80;
  const double minArea = 8000;   // 이 값 조절 가능

  // 전체 길이
  double length = 0;
  for (int i = 0; i < path.length - 1; i++) {
    length += path[i].distanceTo(path[i + 1]);
  }

  if (length < minLength) return false;

  final area = _calculatePolygonArea(path);

  if (area < minArea) {
    print("Path area too small: $area");
    return false;
  }

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
  
  bool _isPointInPolygon(Vector2 p, List<Vector2> poly) {
    int count = 0;
    for (int i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      if (((a.y > p.y) != (b.y > p.y)) &&
          (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y + 0.0001) + a.x)) {
        count++;
      }
    }
    return count.isOdd;
  }

  bool _isComponentEnclosed(PositionComponent comp, List<Vector2> path) {
    // Check key points of the component. For simplicity, we check center and 4 corners.
    final center = comp.absoluteCenter;
    final hw = comp.size.x / 2 * comp.scale.x;
    final hh = comp.size.y / 2 * comp.scale.y;

    final points = [
      center,
      center + Vector2(-hw, -hh),
      center + Vector2(hw, -hh),
      center + Vector2(-hw, hh),
      center + Vector2(hw, hh),
    ];

    for (final p in points) {
      if (!_isPointInPolygon(p, path)) return false;
    }
    return true;
  }

  double _calculatePathLength(List<Vector2> path) {
    double len = 0;
    for (int i = 0; i < path.length - 1; i++) {
      len += path[i].distanceTo(path[i + 1]);
    }
    return len;
  }

  void _resetPathState() {
    userPath.clear();
    currentCircleCenter = null;
    currentCircleRadius = null;
  }

  void _applyTouchPenalty(List<PositionComponent> comps) {
    if (comps.isEmpty) return;

    double totalPenalty = 0;

    for (final comp in comps) {

      if (_isDarkShape(comp)) {
        applyTimePenalty(5);
        continue;
      }

      int energy = 0;

      if (comp is CircleShape) energy = comp.count;
      if (comp is RectangleShape) energy = comp.count;
      if (comp is PentagonShape) energy = comp.energy;
      if (comp is HexagonShape) energy = comp.energy;

      totalPenalty += energy.abs();
    }

    if (totalPenalty > 0) {
      applyTimePenalty(totalPenalty);
    }
  }

bool _isStraightLine(List<Vector2> path) {
  if (path.length < 2) return false;

  final start = path.first;
  final end = path.last;

  final lineDir = (end - start);
  final len = lineDir.length;
  if (len == 0) return false;

  final norm = lineDir / len;

  double maxDeviation = 0;

  for (final p in path) {
    final v = p - start;
    final projLength = v.dot(norm).clamp(0, len).toDouble();
    final projPoint = start + norm * projLength;
    final deviation = p.distanceTo(projPoint);
    maxDeviation = math.max(maxDeviation, deviation);
  }

  return maxDeviation < 20;  // 허용 오차 (원래 10에서 20으로 늘려 관대하게)
}


  @override
  void onDragStart(DragStartEvent event) {
    dragStart = event.canvasPosition;
    // userPath.clear();
    userPath.add(event.canvasPosition);
    print("=== userPath added : ${userPath.last} =============");

    _dragStartPos = event.canvasPosition;
    _dragLastPos = event.canvasPosition;
    _dragStartTimeMs = DateTime.now().millisecondsSinceEpoch;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    final endPos = _dragLastPos ?? _dragStartPos ?? Vector2.zero();
    final nowMs = DateTime.now().millisecondsSinceEpoch.toDouble();
    final durMs = nowMs - _dragStartTimeMs;
    final startPos = _dragStartPos ?? endPos;
    final moved = startPos.distanceTo(endPos);

    // ─────────────────────────────
    // 탭 처리
    // ─────────────────────────────
    if (durMs <= _tapWindowMs && moved <= _tapMoveMax) {
      final corner = size.x * _cornerRatio;

      if (endPos.x <= corner && endPos.y <= corner) {
        pauseGame();
        _resetPathState();
        return;
      }

      if (endPos.x >= size.x - corner && endPos.y <= corner) {
        if (_lastTapTime == 0 || (nowMs - _lastTapTime) <= _debugWindowMs) {
          _debugTapCount += 1;
        } else {
          _debugTapCount = 1;
        }
        _lastTapTime = nowMs;

        if (_debugTapCount >= _debugNeedTaps) {
          toggleDebug();
          _debugTapCount = 0;
        }

        _resetPathState();
        return;
      }
    }

    if (userPath.length < 3) {
      _resetPathState();
      return;
    }
    // 드래그 포인트 최적화 파라미터 튜닝
    // minDistance: 포인트 간 최소 간격. (기존 6 -> 3: 촘촘하게 수집하여 원 닫힘 인식 개선)
    final filtered = _filterDensePoints(userPath, minDistance: 3);
    
    // window: 스무딩 강도. (기존 2 -> 4: 손떨림 지글거림을 확실히 눌러줌)
    final smoothed = _smoothPoints(filtered, window: 4);
    final judgePath = smoothed;

    // final isClosed = _isPathClosed(userPath);
    final pathLength = _calculatePathLength(judgePath);
    final straightDist =
        judgePath.first.distanceTo(judgePath.last);
    final ratio = (pathLength <= 0) ? 0.0 : (straightDist / pathLength);


    // ─────────────────────────────
    // 슬라이스 제스처 판정
    // ─────────────────────────────
    final bool isStraightEnough =
    pathLength > 0 &&
    (straightDist / pathLength) > 0.35;  // 0.55 → 0.4 완화

    // final bool isLongEnough = _isLongEnoughForAnyRect(straightDist);

    final isSliceGesture = straightDist > 30 && // 너무 짧은 터치를 슬라이스로 오인 방지 (20->30)
    _isStraightLine(judgePath);

    print("straightDist: $straightDist");
    print("pathLength: $pathLength");
    print("ratio: ${straightDist / pathLength}");


    if (isSliceGesture) {
      // 경로에 닿는 사각형 목록을 먼저 수집 (blocker 면제 판단에도 사용)
      final slicedRects = children
          .whereType<RectangleShape>()
          .where((r) => _isRealSlice(r, judgePath))
          .toList();

      // 다른 주요 게임 도형들이 슬라이스 경로에 있는지 확인
      final overlappingShapes = <PositionComponent>[];
      for (final comp in children.whereType<PositionComponent>()) {
        bool isDarkRect = comp is RectangleShape && comp.isDark;

        if (comp is CircleShape ||
            comp is TriangleShape ||
            comp is PentagonShape ||
            comp is HexagonShape ||
            isDarkRect) {
          if (_doesPathTouchComponent(comp, judgePath)) {
            overlappingShapes.add(comp);
          }
        }
      }

      if (overlappingShapes.isNotEmpty) {
        // 슬라이스 대상 사각형 Rect 집합
        final slicedRectBounds = slicedRects.map((r) => r.toRect()).toList();

        // blocker(삼각형 등) 면제 판단:
        // 경로가 blocker bounding box 안으로 들어오는 포인트가 없으면 → 면제 (노출된 rect만 통과)
        // 포인트가 하나라도 있으면 → 삼각형 영역을 지나간 것 → 차단
        final realBlockers = overlappingShapes.where((blocker) {
          final blockerRect = blocker.toRect();

          // blocker가 슬라이스 대상 사각형과 아예 안 겹치면 → 항상 차단 (무관한 도형)
          final overlapsAnyRect = slicedRectBounds.any((r) => r.overlaps(blockerRect));
          if (!overlapsAnyRect) return true;

          // 경로 포인트가 blocker bounding box 안에 들어오는지 확인
          final pathEntersBlocker = judgePath.any(
            (p) => blockerRect.contains(Offset(p.x, p.y)),
          );

          // 선분 교차도 확인 (포인트는 밖에 있어도 선분이 bbox를 통과하는 경우)
          final lineEntersBlocker = !pathEntersBlocker && (() {
            for (int i = 0; i < judgePath.length - 1; i++) {
              if (_lineIntersectsRect(judgePath[i], judgePath[i + 1], blockerRect)) {
                return true;
              }
            }
            return false;
          })();

          final touchesBbox = pathEntersBlocker || lineEntersBlocker;

          // bounding box에 닿았으면 → 삼각형 영역 통과로 간주 → 차단
          // 닿지 않았으면 → 노출된 rect만 통과 → 면제
          return touchesBbox;
        }).toList();

        if (realBlockers.isNotEmpty) {
          print('[SLICE BLOCKED] Path enters blocker bbox: ${realBlockers.map((c) => c.runtimeType)}');
          _applyTouchPenalty(realBlockers);
          _resetPathState();
          return;
        }

        // 모든 blocker bounding box를 회피 → 슬라이스 허용
        print('[SLICE ALLOWED] Path avoids all blocker bboxes: ${overlappingShapes.map((c) => c.runtimeType)}');
      }

      if (slicedRects.isNotEmpty) {
        // 경로가 닿은 순서(traversal order)대로 정렬
        slicedRects.sort((a, b) {
          return _firstContactIndex(a, judgePath)
              .compareTo(_firstContactIndex(b, judgePath));
        });

        bool isIllegalSlice = false;
        bool stopSlicing = false;
        bool hitAnyExpected = false;

        for (final rect in slicedRects) {
          if (stopSlicing) break;

          if (rect.order == null) {
            rect.touchAtPoint(userPath);
            continue;
          }

          final expected = _getExpectedRect();

          if (expected == null || rect.order == expected.order) {
            // 올바른 순서의 사각형을 타격함
            rect.touchAtPoint(userPath);
            hitAnyExpected = true;
          } else {
            // 기대하지 않은 순서의 사각형을 타격함
            if (hitAnyExpected) {
              // 한 제스처 내에서 올바른 앞 번호 사각형을 쳤지만, 완전히 제거(카운트=0)되지 않아서
              // 뒤에 있는 번호로 차례가 넘어가지 않은 경우입니다.
              // 이 경우 뒤에 닿은 다른 번호의 사각형들은 슬라이스를 무시합니다. (페널티 없음)
              print('[RECT ORDER] Ignored correctly-sequenced rect because expected rect is not yet destroyed. rect=${rect.order}, expected=${expected.order}');
              stopSlicing = true;
            } else {
              // 처음부터 틀린 사각형을 타격 (예: 역방향) → 전체 차단 및 페널티 부여
              isIllegalSlice = true;
              break;
            }
          }
        }

        if (isIllegalSlice) {
          print('[RECT ORDER BLOCKED] Wrong order slice attempted');
          _applyTouchPenalty(slicedRects.cast<PositionComponent>());
        }
      }

      _resetPathState();
      return;
    }

    // ─────────────────────────────
    // 원 판정 시작
    // ─────────────────────────────
    final isClosed = _isPathClosed(judgePath);
    if (!isClosed && !isSliceGesture) {
      print("triangle not enclosed");

      final touchedOtherShapes = <PositionComponent>[];

      for (final comp in children.whereType<PositionComponent>()) {

        // 삼각형은 여기서 제외 (감싸기 전용)
        if (comp is TriangleShape) continue;

        if (_doesPathTouchComponent(comp, judgePath)) {
          touchedOtherShapes.add(comp);
        }
      }

      if (touchedOtherShapes.isNotEmpty) {
        _applyTouchPenalty(touchedOtherShapes);
      }

      _resetPathState();
      return;
    }


    final enclosedTriangles = <TriangleShape>[];
    final touchedOtherShapes = <PositionComponent>[];

    for (final comp in children.whereType<PositionComponent>()) {
      bool isDarkTriangle = comp is TriangleShape && comp.isDark;

      if (comp is TriangleShape && !isDarkTriangle) {
        if (comp.isFullyEnclosedByUserPath(judgePath)) {
          enclosedTriangles.add(comp);
        }
      } else if (comp is CircleShape ||
          comp is RectangleShape ||
          comp is PentagonShape ||
          comp is HexagonShape ||
          isDarkTriangle) {

        final enclosed = _isComponentEnclosed(comp, judgePath);
        final touched = _doesPathTouchComponent(comp, judgePath);

        if (enclosed || touched) {
          touchedOtherShapes.add(comp);
        }
      }
    }

    // ─────────────────────────────
    // 패널티 처리
    // ─────────────────────────────
    if (touchedOtherShapes.isNotEmpty) {
      _applyTouchPenalty(touchedOtherShapes);
      _resetPathState();
      return;
    }

    // ─────────────────────────────
    // 삼각형 제거
    // ─────────────────────────────
    if (enclosedTriangles.isNotEmpty) {
      for (final comp in enclosedTriangles) {
        if (comp.isDark) {
          applyTimePenalty(5);
        } else {
          comp.triggerDisappear();
        }
      }
    }

    _resetPathState();
  }


  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);

    final p = event.canvasEndPosition;
    _dragLastPos = p;
    userPath.add(p);

    // userPath.add(event.canvasEndPosition);

    if (dragStart != null) {
      // final end = event.canvasEndPosition;
      // final radius = dragStart!.distanceTo(end);
      final radius = dragStart!.distanceTo(p);
      currentCircleCenter = dragStart!;
      currentCircleRadius = radius;
    }
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

  // [CHANGED] 도형별 정밀 히트판정으로 교체 (bounding box → 실제 형태)
  bool _doesPathTouchComponent(
    PositionComponent comp,
    List<Vector2> path,
  ) {
    if (comp is TriangleShape) {
      // 삼각형: 기존 getTriangleVertices() 재사용 (월드 좌표)
      return _doesPathTouchPolygon(comp.getTriangleVertices(), path);
    }
    if (comp is CircleShape) {
      // 원: 중심 + 반지름으로 원 판정
      return _doesPathTouchCircle(comp.absoluteCenter, comp.size.x * 0.48, path);
    }
    if (comp is PentagonShape) {
      // 오각형: 월드 좌표 꼭짓점 5개 계산 후 폴리곤 판정
      return _doesPathTouchPolygon(_getPentagonVertices(comp), path);
    }
    if (comp is HexagonShape) {
      // 육각형: 월드 좌표 꼭짓점 6개 계산 후 폴리곤 판정
      return _doesPathTouchPolygon(_getHexagonVertices(comp), path);
    }
    // 기타 도형(RectangleShape 등)은 기존 bbox 판정 유지
    return _doesPathTouchRect(comp.toRect(), path);
  }

  // [NEW] 기존 bbox 판정 분리
  bool _doesPathTouchRect(Rect rect, List<Vector2> path) {
    for (int i = 0; i < path.length - 1; i++) {
      final p1 = path[i];
      final p2 = path[i + 1];
      if (rect.contains(Offset(p1.x, p1.y)) || rect.contains(Offset(p2.x, p2.y))) {
        return true;
      }
      if (_lineIntersectsRect(p1, p2, rect)) return true;
    }
    return false;
  }

  // [NEW] 경로-폴리곤 충돌 판정 (ray-casting + 선분 교차)
  bool _doesPathTouchPolygon(List<Vector2> vertices, List<Vector2> path) {
    if (vertices.length < 3) return false;
    for (int i = 0; i < path.length - 1; i++) {
      final p1 = path[i];
      final p2 = path[i + 1];
      // 점이 폴리곤 내부에 있는지
      if (_isPointInPolygon(p1, vertices) || _isPointInPolygon(p2, vertices)) {
        return true;
      }
      // 선분이 폴리곤 변과 교차하는지
      for (int j = 0; j < vertices.length; j++) {
        final va = vertices[j];
        final vb = vertices[(j + 1) % vertices.length];
        if (_doLinesIntersect(p1, p2, va, vb)) return true;
      }
    }
    return false;
  }



  // [NEW] 경로-원 충돌 판정
  bool _doesPathTouchCircle(Vector2 center, double radius, List<Vector2> path) {
    for (int i = 0; i < path.length - 1; i++) {
      final p1 = path[i];
      final p2 = path[i + 1];
      if ((p1 - center).length <= radius || (p2 - center).length <= radius) {
        return true;
      }
      if (_lineIntersectsCircle(p1, p2, center, radius)) return true;
    }
    return false;
  }

  // [NEW] 선분-원 교차 판정
  bool _lineIntersectsCircle(Vector2 p1, Vector2 p2, Vector2 center, double radius) {
    final d = p2 - p1;
    final f = p1 - center;
    final a = d.dot(d);
    if (a < 0.00001) return false;
    final b = 2 * f.dot(d);
    final c = f.dot(f) - radius * radius;
    double discriminant = b * b - 4 * a * c;
    if (discriminant < 0) return false;
    discriminant = math.sqrt(discriminant);
    final t1 = (-b - discriminant) / (2 * a);
    final t2 = (-b + discriminant) / (2 * a);
    return (t1 >= 0 && t1 <= 1) || (t2 >= 0 && t2 <= 1);
  }

  // [NEW] 오각형 월드 꼭짓점 반환 (PentagonShape.dart의 _buildPentagonPath와 동일한 공식)
  List<Vector2> _getPentagonVertices(PentagonShape comp) {
    // _visualPentagonCenter 오프셋 반영
    final localCenter = Vector2(
      comp.size.x / 2 - comp.size.x * 0.04,
      comp.size.y / 2 + comp.size.y * 0.04,
    );
    // 월드 좌표로 변환 (anchor = center이므로 position이 도형 중심)
    final topLeft = comp.position - comp.size / 2;
    final worldCenter = topLeft + localCenter;
    final radius = comp.size.x * 0.392;

    return List.generate(5, (i) {
      final a = (-90 + i * 72) * math.pi / 180;
      return worldCenter + Vector2(math.cos(a) * radius, math.sin(a) * radius);
    });
  }

  // [NEW] 육각형 월드 꼭짓점 반환 (HexagonShape.dart의 _buildHexagonPath와 동일한 공식)
  List<Vector2> _getHexagonVertices(HexagonShape comp) {
    final worldCenter = comp.absoluteCenter;
    // inset = strokeWidth/2 + 10 = 3 + 10 = 13, radius = size.x/2 - 13
    final radius = comp.size.x / 2 - 13.0;
    const angleOffset = -math.pi / 30;

    return List.generate(6, (i) {
      final a = (math.pi / 3) * i + angleOffset;
      return worldCenter + Vector2(math.cos(a) * radius, math.sin(a) * radius);
    });
  }

  bool _isRealSlice(RectangleShape rect, List<Vector2> path) {
    final box = rect.toRect();
    int hits = 0;

    for (int i = 0; i < path.length - 1; i++) {
      final p1 = path[i];
      final p2 = path[i + 1];

      final p1Inside = box.contains(Offset(p1.x, p1.y));
      final p2Inside = box.contains(Offset(p2.x, p2.y));

      // 안/밖이 다르면 경계 통과 → hit
      if (p1Inside != p2Inside) {
        hits++;
        continue;
      }

      // 둘 다 밖인데 실제 교차하면 hit
      if (!p1Inside && !p2Inside && _lineIntersectsRect(p1, p2, box)) {
        hits++;
      }
    }

    // 밖→안→밖이면 hits >= 2, 또는 안에서 시작해 밖으로 나가도 hits >= 1
    return hits >= 2 || (hits >= 1 && box.contains(Offset(path.first.x, path.first.y)));
  }


  bool _lineIntersectsRect(Vector2 p1, Vector2 p2, Rect rect) {
    final edges = [
      [rect.topLeft, rect.topRight],
      [rect.topRight, rect.bottomRight],
      [rect.bottomRight, rect.bottomLeft],
      [rect.bottomLeft, rect.topLeft],
    ];

    for (final edge in edges) {
      if (_doLinesIntersect(
        p1,
        p2,
        Vector2(edge[0].dx, edge[0].dy),
        Vector2(edge[1].dx, edge[1].dy),
      )) {
        return true;
      }
    }
    return false;
  }


  void pauseGame() {
    print("blinkingMap:${blinkingMap.values}");
    if (pausedScreen != null && pausedScreen!.isMounted) return;

    if (!_missionResolved && remainingTime <= 0) {
      _timerEndedNotified = true;
      _isTimeOver = true;                 // "이미 끝난 상태"로 마킹
      _pendingResult = StageResult.fail;  // resume 시 결과창 띄우기용
      _timerPaused = true;
    }

    // if (_missionResolved) {
    //   _timerEndedNotified = true;
    // }
    _isPausedGlobally = true;
    _timerPaused = true;
    // _timerEndedNotified = true;

    for (final c in children.whereType<CircleShape>()) {
      c.isPaused = true;
    }

    for (final b in blinkingMap.values) {
      print('Pausing ${b.shape}');
      b.isPaused = true;
    }

    for (final c in children.whereType<PositionComponent>()) {
      for (final e in c.children.whereType<Effect>()) {
        e.pause();
      }
    }

    for (final c in children.whereType<PositionComponent>()) {
      for (final o in c.children.whereType<OrbitingComponent>()) {
        o.pause();
      }
    }

    for (final c in children.whereType<PositionComponent>()) {
      for (final b in c.children.whereType<BounceMoveComponent>()) {
        b.isPaused = true;
      }
    }

    pausedScreen = PausedScreen(
      screenSize: size,
      onResume: () {
        resumeGame();
      },
      onRetry: () {
        resumeGame();
        onRefresh();
      },
      onMenu: () {
        removeAll(children.whereType<AftermathScreen>().toList());
        //TODO : 다른 화면들처럼 go_router 사용할수는 없나?
        rootNavigatorKey.currentContext!.push(
          '/missions',
          extra: {"stages": stages, "index": _selectedStageIndex},
        );
      },
    );

    add(pausedScreen!);
  }

  void resumeGame() {
  print("resumed");

  // pause 상태 먼저 해제
  _isPausedGlobally = false;
  _timerPaused = true; // 결과창 뜰 동안 타이머는 멈춤 유지

  // pause UI 제거
  if (pausedScreen != null) {
    pausedScreen!.removeFromParent();
    pausedScreen = null;
  }

  if (_pendingResult == null && !_missionResolved && remainingTime <= 0) {
    _pendingResult = StageResult.fail;
  }

  for (final c in children.whereType<PositionComponent>()) {
    for (final e in c.children.whereType<Effect>()) {
      e.resume();
    }
  }

  for (final c in children.whereType<PositionComponent>()) {
    for (final o in c.children.whereType<OrbitingComponent>()) {
      o.resume();
    }
  }

  for (final c in children.whereType<PositionComponent>()) {
      for (final b in c.children.whereType<BounceMoveComponent>()) {
        b.isPaused = false;
      }
    }

  // 3️⃣ pending 결과 있으면 → 결과창 띄우고 return
  if (_pendingResult != null) {
    final result = _pendingResult!;
    _pendingResult = null;

    _missionResolved = false;

    final starRating = _calculateStarRating(result);
    Future.microtask(() {
    showAftermathScreen(
      result,
      starRating,
      _selectedStageIndex,
      _selectedMissionIndex,
    );
    });
    return;
  }

  // 4️⃣ 진짜 resume인 경우만 타이머/도형 재개
  _timerPaused = false;

  for (final c in children.whereType<CircleShape>()) {
    c.isPaused = false;
  }
  for (final b in blinkingMap.values) {
    b.isPaused = false;
  }
}
  
  void _drawDashedPath(
    Canvas canvas,
    Path source, {
    required Paint paint,
    double dashLength = 10,
    double gapLength = 6,
  }) {
    for (final metric in source.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final len = math.min(dashLength, metric.length - distance);
        final segment = metric.extractPath(distance, distance + len);
        canvas.drawPath(segment, paint);
        distance += dashLength + gapLength;
      }
    }
  }
  
  // ===== path smoothing helper =====
  Path _buildSmoothedPath(List<Vector2> points) {
    if (points.length < 3) {
      final p = Path();
      if (points.isNotEmpty) {
        p.moveTo(points.first.x, points.first.y);
        for (final pt in points.skip(1)) {
          p.lineTo(pt.x, pt.y);
        }
      }
      return p;
    }

    final path = Path();
    path.moveTo(points.first.x, points.first.y);

    for (int i = 1; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];

      final mid = Offset(
        (p0.x + p1.x) / 2,
        (p0.y + p1.y) / 2,
      );

      path.quadraticBezierTo(
        p0.x,
        p0.y,
        mid.dx,
        mid.dy,
      );
    }

    path.lineTo(points.last.x, points.last.y);
    return path;
  }

  List<Vector2> _filterDensePoints(
    List<Vector2> points, {
    double minDistance = 6,
  }) {
    if (points.isEmpty) return [];

    final result = <Vector2>[points.first];
    for (final p in points.skip(1)) {
      if (p.distanceTo(result.last) >= minDistance) {
        result.add(p);
      }
    }
    return result;
  }

  List<Vector2> _smoothPoints(
    List<Vector2> pts, {
    int window = 3,
  }) {
    final smoothed = <Vector2>[];

    for (int i = 0; i < pts.length; i++) {
      Vector2 sum = Vector2.zero();
      int count = 0;

      for (int j = i - window; j <= i + window; j++) {
        if (j >= 0 && j < pts.length) {
          sum += pts[j];
          count++;
        }
      }
      smoothed.add(sum / count.toDouble());
    }
    return smoothed;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 디버그용 원 보기
    if (userPath.length > 1) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF9E9E9E).withOpacity(0.75);

      // 1) 손떨림 제거용 1차 필터 (너무 촘촘한 포인트 제거)
      final filteredPoints = _filterDensePoints(
        userPath,
        minDistance: 6,
      );

      // 2) 저주파 스무딩 (낙서 느낌 유지)
      final smoothedPoints = _smoothPoints(
        filteredPoints,
        window: 2,
      );

      // 3) 시각용 Path 생성 (판정에는 userPath 그대로 사용)
      final renderPath = _buildSmoothedPath(smoothedPoints);

      // 4) 점선 렌더
      _drawDashedPath(
        canvas,
        renderPath,
        paint: paint,
        dashLength: 14,
        gapLength: 10,
      );
    }
  }

  void _applyBlinkAlpha(PositionComponent shape, double alpha) {
    final target = shape as dynamic;

    try {
      target.setBlinkAlpha(alpha);
    } catch (e) {
      print('[BLINK ALPHA] setBlinkAlpha not found on ${shape.runtimeType}: $e');
    }
  }
}