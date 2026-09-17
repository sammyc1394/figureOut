import 'dart:async';

import 'package:figureout/src/behaviors/ZCommand.dart';
import 'package:figureout/src/behaviors/shapeBehavior.dart';
import 'package:figureout/src/functions/blink_alpha_target.dart';
import 'package:flame/components.dart';

/// Timing data stripped from a movement cell by [TimingCommand.parse].
class MovementTiming {
  const MovementTiming({
    required this.waitSeconds,
    required this.disappearSeconds,
    required this.movement,
  });

  /// Sum of leading `Wait n` lines (0 = none).
  final double waitSeconds;

  /// Seconds from a `Disappear(n)` line (null = do not disappear).
  final double? disappearSeconds;

  /// Remaining lines — the actual movement commands.
  final String movement;

  bool get hasTiming => waitSeconds > 0 || disappearSeconds != null;
}

/// Wraps a movement command with timing lines from the same cell.
///
/// ```text
/// Wait 2            → stay at spawn for 2s, then start moving
/// Z(200, 0, 100)
///
/// Z(160, 0, 250)    → move to (160, 0), then 3s after the path ends
/// Disappear(3)        fade out and leave the wave (no penalty/reward)
/// ```
///
/// Delaying the Disappear countdown until "after movement finishes" only
/// applies to finite Z paths. Looping paths (Repeat/Back) and continuous
/// commands (B/C/D/DR/L/M) have no end, so the countdown starts when
/// movement starts. Both timers use the shape's game time, so they pause
/// during pause/aftermath overlays (see [ShapeTimerComponent]).
class TimingCommand implements ShapeBehavior {
  TimingCommand({
    required this.waitSeconds,
    required this.disappearSeconds,
    required this.inner,
    required this.onDisappear,
  });

  /// Fade-out duration before [onDisappear] removes the shape.
  static const double fadeOutSeconds = 0.3;

  final double waitSeconds;
  final double? disappearSeconds;

  /// Movement command for this cell (null if none).
  final ShapeBehavior? inner;

  /// Removes the shape from the game (also cleans up game-owned state such
  /// as D/DR blink components).
  final void Function(PositionComponent shape) onDisappear;

  /// Splits [raw] into timing lines and movement lines the existing parsers
  /// understand. Only `Wait n` lines *before* the first movement line count
  /// as a leading delay. Waits between Z legs stay in
  /// [MovementTiming.movement] for [ZCommand] to run mid-path.
  static MovementTiming parse(String raw) {
    final lines = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    double waitSeconds = 0.0;
    double? disappearSeconds;
    bool beforeMovement = true;
    final movementLines = <String>[];

    for (final line in lines) {
      final disappear = parseDisappearLine(line);
      if (disappear != null) {
        disappearSeconds ??= disappear;
        continue;
      }

      final wait = parseWaitLine(line);
      if (wait != null && beforeMovement) {
        waitSeconds += wait;
        continue;
      }

      beforeMovement = false;
      movementLines.add(line);
    }

    return MovementTiming(
      waitSeconds: waitSeconds,
      disappearSeconds: disappearSeconds,
      movement: movementLines.join('\n'),
    );
  }

  @override
  Future<void> apply(PositionComponent shape) async {
    // Same as ZCommand: start the timeline without blocking the spawn loop.
    unawaited(_run(shape));
  }

  Future<void> _run(PositionComponent shape) async {
    if (waitSeconds > 0) {
      await waitShapeSeconds(shape, waitSeconds);
    }

    final inner = this.inner;
    if (inner != null) {
      await inner.apply(shape);
      if (inner is ZCommand) {
        await inner.sequenceDone;
      }
    }

    final disappearSeconds = this.disappearSeconds;
    if (disappearSeconds == null) return;

    await waitShapeSeconds(shape, disappearSeconds);

    if (shape is BlinkAlphaTarget) {
      final BlinkAlphaTarget fading = shape;
      await waitShapeSeconds(
        shape,
        fadeOutSeconds,
        onTick: (progress) => fading.setBlinkAlpha(1.0 - progress),
      );
    }

    onDisappear(shape);
  }

  @override
  String get command => 'T';
}
