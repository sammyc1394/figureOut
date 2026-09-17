import 'dart:async';

import 'package:figureout/src/behaviors/shapeBehavior.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

// One step on a Z path: a Z(...) move leg, or a mid-path "Wait n" hold.
class _ZStep {
  _ZStep.move(this.zLine) : waitSeconds = null;

  _ZStep.wait(this.waitSeconds) : zLine = null;

  final String? zLine;
  final double? waitSeconds;
}

class ZCommand implements ShapeBehavior {
  late final String movementRaw;

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
  });

  Future<void> get sequenceDone => _sequenceCompleter.future;

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
      r'^Z\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(?:(-?\d+(?:\.\d+)?)\s*,\s*)?(\d+(?:\.\d+)?)\s*\)$',
    );

    // Path in sheet order: Z(...) legs plus mid-path "Wait n" holds.
    // (Leading waits are stripped by TimingCommand first; any Wait seen here
    // holds the shape in place between two legs.)
    final steps = <_ZStep>[];
    for (final line in lines) {
      if (zReg.hasMatch(line)) {
        steps.add(_ZStep.move(line));
        continue;
      }
      final waitSeconds = parseWaitLine(line);
      if (waitSeconds != null) {
        steps.add(_ZStep.wait(waitSeconds));
      }
    }
    if (!steps.any((step) => step.zLine != null)) return;

    Future<void> moveLinear(Vector2 target, double speed, {double? priorityValue}) async {
      if (!shape.isMounted) return;

      if (priorityValue != null) {
        shape.priority = priorityValue.toInt();
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

      final duration = distV / speed;
      final completer = Completer<void>();

      final effect = MoveEffect.to(
        target,
        EffectController(duration: duration, curve: Curves.linear),
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
      final List<double?> priorities = [];

      for (final step in steps) {
        if (!shape.isMounted) return;

        final waitSeconds = step.waitSeconds;
        if (waitSeconds != null) {
          await waitShapeSeconds(shape, waitSeconds);
          continue;
        }

        final m = zReg.firstMatch(step.zLine!);
        if (m == null) continue;

        final zx = double.parse(m.group(1)!);
        final zy = double.parse(m.group(2)!);
        double? zz;
        double speed;

        if (m.group(3) != null) {
          zz = double.parse(m.group(3)!);
          speed = double.parse(m.group(4)!);
        } else {
          speed = double.parse(m.group(4)!);
        }

        final target = toPlayArea(
          flipY(Vector2(zx, zy)),
          shape.size.x / 2,
          clampInside: true,
        );

        visited.add(target.clone());
        speeds.add(speed);
        priorities.add(zz);

        await moveLinear(target, speed, priorityValue: zz);
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
      _markSequenceDone();
      while (shape.isMounted) {
        await runOnce();
      }
    } else {
      await runOnce();
    }
  }

  @override
  String get command => throw UnimplementedError();
}
