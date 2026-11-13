import 'dart:ui' show Rect;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';

import 'b_command.dart';
import 'blinking_behavior.dart';
import 'c_command.dart';
import 'composite_behavior.dart';
import 'd_dr_command.dart';
import 'l_command.dart';
import 'm_command.dart';
import 'parabola_command.dart';
import 'shape_behavior.dart';
import 'timing_command.dart';
import 'z_command.dart';

/// Converts a movement cell into the behaviors applied by the game.
class MovementCommandParser {
  MovementCommandParser({
    required this.flipY,
    required this.toPlayArea,
    required this.worldToVirtualPlay,
    required this.gameSize,
    required this.playAreaRect,
    required this.timerRectWorld,
    required this.blinkingMap,
    required this.onDisappear,
    required this.onParabolaMiss,
  });

  final Vector2 Function(Vector2) flipY;
  final Vector2 Function(Vector2, double, {bool clampInside}) toPlayArea;
  final Vector2 Function(Vector2) worldToVirtualPlay;
  final Vector2 Function() gameSize;
  final Rect Function() playAreaRect;
  final Rect Function() timerRectWorld;
  final Map<PositionComponent, BlinkingBehaviorComponent> blinkingMap;
  final void Function(PositionComponent) onDisappear;
  final void Function(PositionComponent) onParabolaMiss;

  ShapeBehavior? parse(String raw, Vector2 actPosition) {
    // Strip leading timing lines ("Wait n", "Disappear(n)") from the movement
    // cell, parse the remaining movement as usual, then wrap with TimingCommand
    // when timing is present.
    final timing = TimingCommand.parse(raw);
    final behavior = _checkMovementBehavior(
      timing.movement,
      actPosition,
      repeatDelaySeconds: timing.waitSeconds,
    );
    if (!timing.hasTiming) return behavior;

    debugPrint(
      "[Behavior check] timing: wait=${timing.waitSeconds}s, disappear=${timing.disappearSeconds}s",
    );
    return TimingCommand(
      waitSeconds: timing.waitSeconds,
      disappearSeconds: timing.disappearSeconds,
      inner: behavior,
      onDisappear: onDisappear,
    );
  }

  ShapeBehavior? _checkMovementBehavior(
    String raw,
    Vector2 actPosition, {
    double repeatDelaySeconds = 0,
  }) {
    debugPrint("[Behavior check] parsing command into behavior");

    final behaviors = <ShapeBehavior>[];

    final parabolaMatch = RegExp(
      r'^\s*P\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(\d+(?:\.\d+)?)\s*,\s*(\d+(?:\.\d+)?)\s*\)\s*$',
      multiLine: true,
    ).firstMatch(raw);
    if (parabolaMatch != null) {
      behaviors.add(
        ParabolaCommand(
          velocityX: double.parse(parabolaMatch.group(1)!),
          velocityY: double.parse(parabolaMatch.group(2)!),
          gravity: double.parse(parabolaMatch.group(3)!),
          flipY: flipY,
          toPlayArea: toPlayArea,
          onMiss: onParabolaMiss,
        ),
      );
    }

    final lMatch = RegExp(
      r'^(?:L)?\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(\d+(?:\.\d+)?)\s*\)$',
      multiLine: true,
    ).firstMatch(raw.trim());

    if (lMatch != null) {
      debugPrint("[Behavior check] returning L command");

      behaviors.add(
        LCommand(movementRaw: raw, flipY: flipY, toPlayArea: toPlayArea),
      );
    }

    final cMatch = RegExp(
      r'\b(CC|C)\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)',
    ).firstMatch(raw);

    if (cMatch != null) {
      debugPrint("[Behavior check] returning c command");
      final clockwise = cMatch.group(1) == 'C';
      final r = double.parse(cMatch.group(2)!);
      final s = double.parse(cMatch.group(3)!);

      behaviors.add(
        CCommand(
          clockwise: clockwise,
          radius: r,
          degreePerSec: s,
          actPosition: actPosition,
          flipY: flipY,
          toPlayArea: toPlayArea,
        ),
      );
    }

    final drMatch = RegExp(
      r'^\s*DR\(\s*(\d+(?:\.\d+)?)\s*,\s*(\d+(?:\.\d+)?)\s*\)\s*$',
      multiLine: true,
    ).firstMatch(raw);

    if (drMatch != null) {
      debugPrint("[Behavior check] returning dr command");
      final a = double.parse(drMatch.group(1)!);
      final b = double.parse(drMatch.group(2)!);

      behaviors.add(
        DDrCommand(
          visibleDuration: a,
          invisibleDuration: b,
          isRandomRespawn: true,
          timerRectWorld: timerRectWorld,
          gameSize: gameSize(),
          blinkingMap: blinkingMap,
        ),
      );
    }

    final dMatch = RegExp(
      r'^\s*D\(\s*(\d+(?:\.\d+)?)\s*,\s*(\d+(?:\.\d+)?)\s*\)\s*$',
      multiLine: true,
    ).firstMatch(raw);

    if (dMatch != null) {
      debugPrint("[Behavior check] returning d command");

      final a = double.parse(dMatch.group(1)!);
      final b = double.parse(dMatch.group(2)!);

      behaviors.add(
        DDrCommand(
          visibleDuration: a,
          invisibleDuration: b,
          isRandomRespawn: false,
          timerRectWorld: timerRectWorld,
          gameSize: gameSize(),
          blinkingMap: blinkingMap,
        ),
      );
    }

    final mMatch = RegExp(
      r'M\((-?\d+)\s*,\s*(\d+)\s*,\s*([A-Za-z0-9\-.]+)\)',
    ).firstMatch(raw);

    if (mMatch != null) {
      debugPrint("[Behavior check] returning m command");

      final angle = double.parse(mMatch.group(1)!);
      final speed = double.parse(mMatch.group(2)!);
      final stopY = mMatch.group(3)!;

      behaviors.add(
        MCommand(
          angleDeg: angle,
          speed: speed,
          stopY: stopY,
          position: actPosition,
          size: gameSize(),
          flipY: flipY,
          toPlayArea: toPlayArea,
        ),
      );
    }

    if (raw.contains('Z(')) {
      debugPrint("[Behavior check] returning z command");

      behaviors.add(
        ZCommand(
          movementRaw: raw,
          flipY: flipY,
          toPlayArea: toPlayArea,
          worldToVirtualPlay: worldToVirtualPlay,
          repeatDelaySeconds: repeatDelaySeconds,
        ),
      );
    }

    final bMatch = RegExp(
      r'B\(\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(\d+(?:\.\d+)?)\s*\)',
    ).firstMatch(raw);

    if (bMatch != null) {
      final x0 = double.parse(bMatch.group(1)!);
      final y0 = double.parse(bMatch.group(2)!);
      final speed = double.parse(bMatch.group(3)!);

      behaviors.add(
        BCommand(
          startEditor: Vector2(x0, y0),
          directionWorld: actPosition, // 이미 toPlayArea 끝난 월드 좌표
          speed: speed,
          flipY: flipY,
          toPlayArea: toPlayArea,
          playAreaRect: playAreaRect,
        ),
      );
    }

    if (behaviors.isEmpty) return null;

    if (behaviors.length == 1) {
      return behaviors.first;
    }

    debugPrint(
      '[Behavior check] Composite: '
      '${behaviors.map((b) => b.runtimeType).join(', ')}',
    );

    return CompositeBehavior(behaviors);
  }
}
