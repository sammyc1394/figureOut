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