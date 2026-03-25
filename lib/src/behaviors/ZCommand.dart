import 'dart:async';

import 'package:figureout/src/behaviors/shapeBehavior.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

class ZCommand implements ShapeBehavior {
  late final String movementRaw;

  late final Vector2 Function(Vector2) flipY;
  late final Vector2 Function(Vector2, double, {bool clampInside}) toPlayArea;
  late final Vector2 Function(Vector2) worldToVirtualPlay;

  ZCommand({
    required this.movementRaw,
    required this.flipY,
    required this.toPlayArea,
    required this.worldToVirtualPlay,
  });

  @override
  Future<void> apply(PositionComponent shape) async {
    // 🔥 기존과 동일하게 "비동기 실행만 시작"
    unawaited(_run(shape));
  }

  Future<void> _run(PositionComponent shape) async {
    while (!shape.isMounted) {
      await Future<void>.delayed(Duration.zero);
    }

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

      if (hasBack && visited.isNotEmpty) {
        for (int i = visited.length - 1; i >= 0; i--) {
          if (!shape.isMounted) return;

          final backTarget = (i == 0) ? spawnPosition : visited[i - 1];
          final backSpeed = speeds[i] > 0 ? speeds[i] : 1.0;

          await moveLinear(backTarget, backSpeed);
        }
        return;
      }

      if (!hasRepeat) return;

      final lastSpeed =
      speeds.isNotEmpty && speeds.last > 0 ? speeds.last : 1.0;

      await moveLinear(spawnPosition, lastSpeed);
    }

    final bool loopForever = hasRepeat || hasBack;

    if (loopForever) {
      while (shape.isMounted) {
        await runOnce();
      }
    } else {
      await runOnce();
    }
  }

  @override
  // TODO: implement command
  String get command => throw UnimplementedError();
}