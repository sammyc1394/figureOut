import 'dart:async';

import 'package:flame/components.dart';

abstract class ShapeBehavior {
  Future<void> apply(PositionComponent shape);

  String get command; // ex : C, D, DR,...
}

// Every shape class (Circle/Triangle/Rectangle/Pentagon/Hexagon) exposes its
// own `bool isPaused` field, but they don't share a common interface for it.
// Movement commands (Z/M/L) create fresh Effects mid-route (e.g. each leg of
// a repeating/back-and-forth path), and a one-time pause sweep elsewhere in
// the game only pauses whatever Effect happens to exist at that moment — a
// brand-new Effect created right after would run un-paused. This lets a
// freshly-created Effect check the shape's current pause state itself before
// starting, so it doesn't "escape" the game's pause/aftermath overlay.
bool isShapePaused(PositionComponent shape) {
  try {
    return (shape as dynamic).isPaused == true;
  } catch (_) {
    return false;
  }
}

// Timing lines that can appear alongside movement commands in a movement cell:
//   Wait 2          → wait 2 seconds ("Wait(2)" also allowed)
//   Disappear(3)    → remove the shape after 3 seconds ("Disappear 3" also allowed)
// One command per line; trimmed; case-insensitive.
final RegExp _waitLineRegex = RegExp(
  r'^wait\s*\(?\s*(\d+(?:\.\d+)?)\s*\)?$',
  caseSensitive: false,
);
final RegExp _disappearLineRegex = RegExp(
  r'^disappear\s*\(?\s*(\d+(?:\.\d+)?)\s*\)?$',
  caseSensitive: false,
);

/// Seconds from a `Wait n` line, or null if not a wait line.
double? parseWaitLine(String line) {
  final match = _waitLineRegex.firstMatch(line.trim());
  return match == null ? null : double.tryParse(match.group(1)!);
}

/// Seconds from a `Disappear(n)` line, or null if not a disappear line.
double? parseDisappearLine(String line) {
  final match = _disappearLineRegex.firstMatch(line.trim());
  return match == null ? null : double.tryParse(match.group(1)!);
}

/// Counts [duration] seconds in the parent shape's game time. Time does not
/// advance while the shape is paused (pause/aftermath overlay, [isShapePaused])
/// or detached for D/DR blinking — unlike wall-clock `Future.delayed`. Calls
/// [onTick] each frame with progress (0.0–1.0), then [onComplete] once and
/// removes itself.
class ShapeTimerComponent extends Component {
  ShapeTimerComponent({
    required this.duration,
    this.onTick,
    this.onComplete,
  });

  final double duration;
  final void Function(double progress)? onTick;
  final void Function()? onComplete;

  double _elapsed = 0.0;
  bool _done = false;

  @override
  void update(double dt) {
    super.update(dt);
    if (_done) return;

    final shape = parent;
    if (shape is PositionComponent && isShapePaused(shape)) return;

    _elapsed += dt;
    final progress =
        duration <= 0 ? 1.0 : (_elapsed / duration).clamp(0.0, 1.0);
    onTick?.call(progress);

    if (progress >= 1.0) {
      _done = true;
      removeFromParent();
      onComplete?.call();
    }
  }
}

/// Waits [seconds] in [shape]'s game time (see [ShapeTimerComponent]).
/// If the shape is removed first, this future never completes; callers can
/// ignore that because a gone shape does not need further movement.
Future<void> waitShapeSeconds(
  PositionComponent shape,
  double seconds, {
  void Function(double progress)? onTick,
}) {
  final completer = Completer<void>();
  shape.add(
    ShapeTimerComponent(
      duration: seconds,
      onTick: onTick,
      onComplete: () {
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );
  return completer.future;
}
