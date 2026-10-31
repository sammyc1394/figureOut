import 'dart:async';
import 'dart:math';

import 'package:figureout/src/behaviors/shape_behavior.dart';
import 'package:figureout/src/components/attack_timer_gate.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

// One step on a Z path: a Z(...) move leg, or a fixed/random wait.
class _ZStep {
  _ZStep.move(this.zLine) : waitSeconds = null, waitMaxSeconds = null;

  _ZStep.wait(this.waitSeconds, [this.waitMaxSeconds]) : zLine = null;

  final String? zLine;
  final double? waitSeconds;
  final double? waitMaxSeconds;
}

class ZCommand implements ShapeBehavior, InitialWaitBehavior {
  late final String movementRaw;

  // TimingCommand handles the first leading wait; repeat it after each return.
  final double repeatDelaySeconds;

  late final Vector2 Function(Vector2) flipY;
  late final Vector2 Function(Vector2, double, {bool clampInside}) toPlayArea;
  late final Vector2 Function(Vector2) worldToVirtualPlay;

  // Completes when the path finishes. Infinite Repeat/Back paths complete as
  // soon as the loop starts. TimingCommand awaits this before starting an
  // "after movement" Disappear(n) countdown.
  final Completer<void> _sequenceCompleter = Completer<void>();

  ZCommand({
    required this.movementRaw,
    required this.flipY,
    required this.toPlayArea,
    required this.worldToVirtualPlay,
    this.repeatDelaySeconds = 0,
  });

  Future<void> get sequenceDone => _sequenceCompleter.future;

  @override
  bool get hasInitialWait {
    final firstLine = movementRaw.split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
    return parseWaitLine(firstLine) != null ||
        _randomWaitReg.hasMatch(firstLine);
  }

  static final _randomWaitReg = RegExp(
    r'^wait\s+rnd\(\s*(\d+(?:\.\d+)?)\s*,\s*(\d+(?:\.\d+)?)\s*\)$',
    caseSensitive: false,
  );

  void _markSequenceDone() {
    if (!_sequenceCompleter.isCompleted) _sequenceCompleter.complete();
  }

  @override
  Future<void> apply(PositionComponent shape) async {
    // Same as before: start async execution without awaiting here.
    unawaited(_run(shape));
  }

  Future<void> _run(PositionComponent shape) async {
    try {
      await _runPath(shape);
    } finally {
      _markSequenceDone();
    }
  }

  Future<void> _runPath(PositionComponent shape) async {
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

    final zReg = RegExp(
      r'^Z\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(\d+(?:\.\d+)?)(?:\s*,\s*(\d+(?:\.\d+)?))?\s*\)$',
    );

    // Keep waits in sheet order, including the initial wait on every repeat.
    final steps = <_ZStep>[];
    final random = Random();
    for (final line in lines) {
      if (zReg.hasMatch(line)) {
        steps.add(_ZStep.move(line));
        continue;
      }
      final waitSeconds = parseWaitLine(line);
      if (waitSeconds != null) {
        steps.add(_ZStep.wait(waitSeconds));
        continue;
      }
      final randomWait = _randomWaitReg.firstMatch(line);
      if (randomWait != null) {
        final minimum = double.parse(randomWait.group(1)!);
        final maximum = double.parse(randomWait.group(2)!);
        if (maximum < minimum) {
          throw FormatException('Wait RND maximum is below minimum', line);
        }
        steps.add(_ZStep.wait(minimum, maximum));
      }
    }
    if (!steps.any((step) => step.zLine != null)) return;

    Future<void> moveLinear(Vector2 target, double speed, {double accelerationSeconds = 0}) async {
      if (!shape.isMounted) return;

      if (shape is AttackTimerGate) {
        shape.waitingForInitialMovement = false;
      }

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

      double duration = distV / speed;
      Curve curve = Curves.linear;
      if (accelerationSeconds > 0) {
        final accelerationDistance = speed * accelerationSeconds / 2;
        // 가까운 목적지는 최고 속도에 도달하기 전에 멈춘다.
        duration = distV <= accelerationDistance
            ? sqrt(2 * distV * accelerationSeconds / speed)
            : distV / speed + accelerationSeconds / 2;
        curve = _ZAccelerationCurve(
          speed: speed,
          accelerationSeconds: accelerationSeconds,
          distance: distV,
          duration: duration,
        );
      }
      final completer = Completer<void>();

      final effect = MoveEffect.to(
        target,
        EffectController(duration: duration, curve: curve),
        onComplete: () {
          if (!completer.isCompleted) completer.complete();
        },
      );
      shape.add(effect);
      // A freshly-created effect always starts un-paused — if the shape was
      // already paused (e.g. aftermath overlay showing) the moment this leg
      // began, freeze it immediately instead of letting it run one leg
      // un-paused before the next pause sweep catches it.
      if (isShapePaused(shape)) effect.pause();

      await completer.future;
    }

    Future<void> runOnce() async {
      final List<Vector2> visited = [];
      final List<double> speeds = [];
      final List<double> accelerationTimes = [];

      for (final step in steps) {
        if (!shape.isMounted) return;

        final waitSeconds = step.waitSeconds;
        if (waitSeconds != null) {
          final maximum = step.waitMaxSeconds ?? waitSeconds;
          final duration = waitSeconds +
              random.nextDouble() * (maximum - waitSeconds);
          await waitShapeSeconds(shape, duration);
          continue;
        }

        final m = zReg.firstMatch(step.zLine!);
        if (m == null) continue;

        final zx = double.parse(m.group(1)!);
        final zy = double.parse(m.group(2)!);
        final speed = double.parse(m.group(3)!);
        final accelerationSeconds =
            m.group(4) == null ? 0.0 : double.parse(m.group(4)!);

        final target = toPlayArea(
          flipY(Vector2(zx, zy)),
          shape.size.x / 2,
          clampInside: false,
        );

        visited.add(target.clone());
        speeds.add(speed);
        accelerationTimes.add(accelerationSeconds);

        await moveLinear(target, speed, accelerationSeconds: accelerationSeconds);
      }

      if (!shape.isMounted) return;

      if (hasBack && visited.isNotEmpty) {
        for (int i = visited.length - 1; i >= 0; i--) {
          if (!shape.isMounted) return;

          final backTarget = (i == 0) ? spawnPosition : visited[i - 1];
          final backSpeed = speeds[i] > 0 ? speeds[i] : 1.0;

          await moveLinear(backTarget, backSpeed,
              accelerationSeconds: accelerationTimes[i]);
        }
        return;
      }

      if (!hasRepeat) return;

      final lastSpeed =
      speeds.isNotEmpty && speeds.last > 0 ? speeds.last : 1.0;

      await moveLinear(spawnPosition, lastSpeed,
          accelerationSeconds: accelerationTimes.last);
    }

    final bool loopForever = hasRepeat || hasBack;

    if (loopForever) {
      _markSequenceDone();
      while (shape.isMounted) {
        await runOnce();
        if (shape.isMounted && repeatDelaySeconds > 0) {
          await waitShapeSeconds(shape, repeatDelaySeconds);
        }
      }
    } else {
      await runOnce();
    }
  }

  @override
  String get command => throw UnimplementedError();
}

// 선형으로 증가하는 속도를 적분해 MoveEffect의 이동 거리 진행률로 변환한다.
class _ZAccelerationCurve extends Curve {
  const _ZAccelerationCurve({
    required this.speed,
    required this.accelerationSeconds,
    required this.distance,
    required this.duration,
  });

  final double speed;
  final double accelerationSeconds;
  final double distance;
  final double duration;

  @override
  double transformInternal(double t) {
    final elapsed = t * duration;
    final acceleratingTime = min(elapsed, accelerationSeconds);
    final traveled = speed * acceleratingTime * acceleratingTime /
            (2 * accelerationSeconds) +
        speed * max(0.0, elapsed - accelerationSeconds);
    return (traveled / distance).clamp(0.0, 1.0);
  }
}
