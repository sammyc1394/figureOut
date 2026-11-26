import 'dart:math' as math;

import 'package:figureout/src/components/circle_shape.dart';
import 'package:figureout/src/components/pentagon_shape.dart';
import 'package:figureout/src/components/prepared_enemy.dart';
import 'package:figureout/src/components/rectangle_shape.dart';
import 'package:figureout/src/components/triangle_shape.dart';
import 'package:figureout/src/config/config.dart';
import 'package:figureout/src/game_modes/one_second_game.dart';
import 'package:figureout/src/services/random_context.dart';
import 'package:figureout/src/services/sheet_service.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _HoldTestGame extends OneSecondGame {
  _HoldTestGame(BuildContext context)
    : super(
        navigatorContext: context,
        stages: [
          StageData(
            name: 'Pentagon hold',
            reward: '',
            timeLimit: '60',
            missions: const {1: []},
            missionTimeLimits: const {1: 60},
            missionTitle: const {},
            missionIsBoss: const {},
          ),
        ],
        stageIndex: 0,
        missionIndex: 0,
      );

  final penalties = <double>[];

  @override
  Future<void> runStageWithAftermath(int stageIndex, int missionIndex) async {}

  @override
  void applyTimePenalty(double seconds) {
    penalties.add(seconds);
    super.applyTimePenalty(seconds);
  }
}

Future<_HoldTestGame> _startGame(WidgetTester tester) async {
  dotenv.testLoad();
  SharedPreferences.setMockInitialValues({});
  late _HoldTestGame game;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          game = _HoldTestGame(context);
          return GameWidget(game: game);
        },
      ),
    ),
  );
  await tester.runAsync(() => game.loaded);
  await tester.pump(const Duration(milliseconds: 1));
  game.startMissionTimer(60);
  return game;
}

Future<void> _spawn(
  WidgetTester tester,
  _HoldTestGame game,
  String type,
  Vector2 point,
  int energy, {
  String movement = '',
  Vector2? size,
  bool sheetPosition = false,
}) async {
  final prepared = sheetPosition
      ? game.buildPreparedEnemy(
          enemy: EnemyData(
            command: '',
            shape: type,
            movement: movement,
            position: '(${point.x.toInt()}, ${point.y.toInt()})',
            mission: 1,
            energy: energy,
            darkYN: energy < 0,
          ),
          flipY: game.flipY,
          toPlayArea: game.toPlayArea,
          checkBehavior: game.checkBehavior,
        )!
      : PreparedEnemy(
          shapeType: type,
          energy: energy,
          isDark: energy < 0,
          actPosition: point,
          attackDamage: 7,
          order: null,
          behavior: game.checkBehavior(movement, point),
          customSize: size ?? Vector2.all(80),
        );
  await tester.runAsync(
    () => game.spawnPreparedEnemy(
      prepared,
      <Component>{},
      <Component>{},
      runId: 1,
    ),
  );
  await tester.pump();
}

Future<void> _advance(WidgetTester tester, int milliseconds) async {
  for (var i = 0; i < milliseconds; i += 10) {
    await tester.pump(const Duration(milliseconds: 10));
    // Spawned behaviors resume their awaits in the real async zone used
    // to load sprites. Let those continuations run between game frames.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }
}

Future<void> _drag(WidgetTester tester, List<Offset> path) async {
  final finger = await tester.startGesture(path.first);
  for (final point in path.skip(1)) {
    await finger.moveTo(point);
    await tester.pump(const Duration(milliseconds: 10));
  }
  await finger.up();
  await tester.pump();
}

void main() {
  test('rectangle angle parsing resolves RD and RND and keeps health', () {
    dotenv.testLoad();
    final service = SheetService();
    final context = RandomContext();

    expect(
      service.resolveShape('Rectangle 35:200/RD(-45, -45) (-1)', context),
      'Rectangle35:200/-45(-1)',
    );
    expect(
      service.resolveShape('Rectangle 35:200/RND(45, 45)_2 (3)', context),
      'Rectangle35:200/45_2(3)',
    );
    expect(
      service.resolveShape('Rectangle 35:200/45 (-1)', context),
      'Rectangle35:200/45(-1)',
    );
  });

  testWidgets('a forbidden shape intercepts only the finger it crosses once', (
    tester,
  ) async {
    final game = await _startGame(tester);
    final left = Vector2(150, 280);
    final right = Vector2(350, 280);
    await _spawn(tester, game, 'Pentagon', left, 5);
    await _spawn(tester, game, 'Pentagon', right, 5);
    await _spawn(tester, game, 'Circle', Vector2(50, 280), -1);
    final pentagons = game.children.whereType<PentagonShape>().toList();
    final forbidden = game.children.whereType<CircleShape>().single;

    final leftFinger = await tester.startGesture(left.toOffset(), pointer: 1);
    final rightFinger = await tester.startGesture(right.toOffset(), pointer: 2);
    await tester.pump(const Duration(milliseconds: 350));
    expect(pentagons.map((shape) => shape.energy), [4, 4]);
    expect(game.penalties, isEmpty);
    final beforeContact = game.currentMissionTime;

    await forbidden.add(
      MoveEffect.to(left.clone(), EffectController(duration: 0.25)),
    );
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.penalties, [7.0]);
    expect(game.currentMissionTime, beforeContact - 7);

    // Both physical pointers stay down while the forbidden shape covers left.
    for (var frame = 0; frame < 70; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.penalties, [7.0]);
    expect(pentagons.map((shape) => shape.energy), [4, 3]);

    await leftFinger.up();
    await rightFinger.up();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sheet Y aligns different shapes and sizes at spawn', (
    tester,
  ) async {
    final game = await _startGame(tester);
    await _spawn(
      tester,
      game,
      'Triangle5',
      Vector2(-120, 150),
      -1,
      sheetPosition: true,
    );
    await _spawn(
      tester,
      game,
      'Pentagon',
      Vector2(0, 150),
      2,
      sheetPosition: true,
    );
    final triangle = game.children.whereType<TriangleShape>().single;
    final pentagon = game.children.whereType<PentagonShape>().single;
    expect(triangle.size.y, isNot(pentagon.size.y));
    expect(
      triangle.toRect().center.dy,
      closeTo(pentagon.toRect().center.dy, 1e-6),
    );
    expect(triangle.toRect().center.dy, lessThan(game.playArea.position.y));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a slash crosses the exposed rectangle beside a forbidden one', (
    tester,
  ) async {
    final game = await _startGame(tester);
    await _spawn(
      tester,
      game,
      'Rectangle',
      Vector2(400, 280),
      1,
      size: Vector2(160, 24),
    );
    await _spawn(
      tester,
      game,
      'Rectangle',
      Vector2(400, 252),
      -1,
      size: Vector2(160, 24),
    );
    final target = game.children.whereType<RectangleShape>().first;
    await _drag(tester, [
      for (var x = 290.0; x <= 510; x += 20) Offset(x, 280),
    ]);
    expect(target.wasRemovedByUser, isTrue);
    expect(game.penalties, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a closed drag encloses and removes the normal triangle', (
    tester,
  ) async {
    final game = await _startGame(tester);
    await _spawn(tester, game, 'Triangle', Vector2(400, 300), 1);
    final triangle = game.children.whereType<TriangleShape>().single;
    await _drag(tester, [
      for (var i = 0; i <= 32; i++)
        Offset(
          400 + 80 * math.cos(i * math.pi / 16),
          300 + 80 * math.sin(i * math.pi / 16),
        ),
    ]);
    expect(triangle.wasRemovedByUser, isTrue);
    expect(game.penalties, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final keepUnrelatedEffect in [false, true]) {
    testWidgets(
      'Stage 4 M3 advances through Wait 0'
      '${keepUnrelatedEffect ? ' with an unrelated effect running' : ''}',
      (tester) async {
        final messenger = tester.binding.defaultBinaryMessenger;
        const audio = 'xyz.luan/audioplayers';
        for (final name in ['$audio.global', '$audio.global/events']) {
          messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
        }
        messenger.setMockMethodCallHandler(const MethodChannel(audio), (call) async {
          if (call.method == 'create') {
            final id = (call.arguments as Map)['playerId'];
            messenger.setMockMethodCallHandler(
              MethodChannel('$audio/events/$id'),
              (_) async => null,
            );
          }
          return null;
        });
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(393, 852);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final game = await _startGame(tester);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'figureout.audio-preferences.v1',
          '{"all":false,"effects":false,"bgm":false}',
        );
        // Warm the sprite cache outside fake time, as the real mission loads
        // assets asynchronously. The mission removes the warm-up triangle.
        await _spawn(tester, game, 'Triangle', Vector2(400, 300), 1);

        EnemyData wait(String command) => EnemyData(
          command: 'wait',
          shape: command,
          movement: '',
          position: '',
          mission: 3,
          energy: 1,
          darkYN: false,
        );
        EnemyData triangle(String movement, {bool dark = false}) => EnemyData(
          command: 'e',
          shape: dark ? 'Triangle4 (-1)' : 'Triangle4 (1)',
          movement: movement,
          position: '(0, 0)',
          mission: 3,
          energy: dark ? -1 : 1,
          darkYN: dark,
          zOrder: dark ? ShapeZOrder.top : ShapeZOrder.normal,
          attackSeconds: dark ? null : 3,
          attackDamage: dark ? null : -10,
        );
        final mission = StageData(
          name: 'Stage 4',
          reward: '',
          timeLimit: '40',
          missions: {
            3: [
              triangle('', dark: true),
              wait('Wait 2'),
              triangle('Z(-125, 0, 1000)'),
              triangle('Z(125, 0, 1000)'),
              wait('Wait 0'),
              triangle('', dark: true),
              wait('Wait 2'),
              triangle('Z(0, 125, 1000)'),
              triangle('Z(0, -125, 1000)'),
              wait('Wait 0'),
              triangle('', dark: true),
              wait('Wait 2'),
              for (final x in [-125, 125])
                for (final y in [-125, 125]) triangle('Z($x, $y, 1000)'),
            ],
          },
          missionTimeLimits: const {3: 40},
          missionTitle: const {3: 'Dakota'},
          missionIsBoss: const {},
        );
        Iterable<TriangleShape> targets() =>
            game.children.whereType<TriangleShape>().where((s) => !s.isDark);
        TriangleShape obstacle() =>
            game.children.whereType<TriangleShape>().singleWhere((s) => s.isDark);
        Future<void> enclose(TriangleShape shape) async {
          final center = shape.absoluteCenter;
          final radius = shape.getTriangleVertices()
              .map((corner) => corner.distanceTo(center))
              .reduce(math.max) + 14;
          await _drag(tester, [
            for (var i = 0; i <= 32; i++)
              Offset(
                center.x + radius * math.cos(i * math.pi / 16),
                center.y + radius * math.sin(i * math.pi / 16),
              ),
          ]);
          expect(shape.wasRemovedByUser, isTrue);
        }

        // Mission delays use wall time and Z waits for a Flame mount. Pump
        // frames alongside the real async mission so both can advance.
        Future<void> advanceMission(int milliseconds) async {
          final elapsed = Stopwatch()..start();
          var previous = Duration.zero;
          while (elapsed.elapsedMilliseconds < milliseconds) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 16)),
            );
            final now = elapsed.elapsed;
            await tester.pump(now - previous);
            previous = now;
          }
        }

        late Future<StageResult> result;
        await tester.runAsync(() async {
          result = game.runSingleMissions(mission, 3);
        });
        await advanceMission(2450);
        final first = targets().toList();
        expect(first, hasLength(2));
        final firstObstacle = obstacle();
        final unrelated = MoveEffect.to(
          Vector2(-100, 0),
          EffectController(duration: 15),
        );
        if (keepUnrelatedEffect) {
          await game.add(PositionComponent(children: [unrelated]));
          await tester.pump();
        }

        for (final shape in first) {
          await enclose(shape);
        }
        await advanceMission(1250);
        expect(targets(), isEmpty);
        expect(obstacle(), isNot(same(firstObstacle)));
        await advanceMission(1900);
        final second = targets().toList();
        expect(second, hasLength(2));
        expect(second.every((shape) => (shape.x - obstacle().x).abs() < 1), isTrue);

        final secondObstacle = obstacle();
        for (final shape in second) {
          await enclose(shape);
        }
        await advanceMission(3300);
        final third = targets().toList();
        expect(third, hasLength(4));
        expect(obstacle(), isNot(same(secondObstacle)));
        if (keepUnrelatedEffect) expect(unrelated.isMounted, isTrue);
        for (final shape in third) {
          await enclose(shape);
        }
        await advanceMission(1300);
        expect(
          await tester.runAsync(() => result.timeout(const Duration(seconds: 2))),
          StageResult.success,
        );
        expect(game.penalties, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('Wait, Z, Back returns to spawn and waits before repeating', (
    tester,
  ) async {
    final game = await _startGame(tester);
    await _spawn(
      tester,
      game,
      'Circle4',
      Vector2(-100, 0),
      3,
      sheetPosition: true,
      movement: 'Wait 1\nZ(100, 0, 200)\nBack',
    );
    final circle = game.children.whereType<CircleShape>().single;
    final start = circle.position.x;
    final end = game.toPlayArea(Vector2(100, 0), circle.size.x / 2).x;
    await _advance(tester, 800);
    expect(circle.position.x, closeTo(start, 1e-6));
    await _advance(tester, 700);
    expect(circle.position.x, inExclusiveRange(start, end));
    await _advance(tester, 400);
    expect(circle.position.x, closeTo(end, 3));
    await _advance(tester, 1100);
    expect(circle.position.x, closeTo(start, 0.01));
    await _advance(tester, 550);
    expect(circle.position.x, closeTo(start, 0.01));
    await _advance(tester, 350);
    expect(circle.position.x, inExclusiveRange(start + 5, end));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('C and CC orbit in opposite directions', (tester) async {
    final game = await _startGame(tester);
    await _spawn(
      tester,
      game,
      'Circle',
      Vector2(330, 280),
      3,
      movement: 'C(40, 90)',
    );
    await _spawn(
      tester,
      game,
      'Circle',
      Vector2(470, 280),
      3,
      movement: 'CC(40, 90)',
    );
    await _advance(tester, 300);
    final circles = game.children.whereType<CircleShape>().toList();
    expect(circles.first.position.y, greaterThan(280));
    expect(circles.last.position.y, lessThan(280));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('D fades in place while DR fades and respawns elsewhere', (
    tester,
  ) async {
    final game = await _startGame(tester);
    final fixed = Vector2(330, 280);
    final random = Vector2(470, 280);
    await _spawn(
      tester,
      game,
      'Circle',
      fixed.clone(),
      3,
      movement: 'D(0.5, 0.5)',
    );
    await _spawn(
      tester,
      game,
      'Circle',
      random.clone(),
      3,
      movement: 'DR(0.5, 0.5)',
    );
    final circles = game.children.whereType<CircleShape>().toList();
    await _advance(tester, 200);
    expect(circles.map((c) => c.blinkAlpha), everyElement(greaterThan(0)));
    await _advance(tester, 470);
    expect(circles.map((c) => c.blinkAlpha), everyElement(0));
    await _advance(tester, 550);
    expect(circles.map((c) => c.blinkAlpha), everyElement(greaterThan(0)));
    expect(circles.first.position.distanceTo(fixed), closeTo(0, 1e-6));
    expect(circles.last.position.distanceTo(random), greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
