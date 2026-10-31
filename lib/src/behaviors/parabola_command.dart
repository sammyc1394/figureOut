import 'package:figureout/src/behaviors/shape_behavior.dart';
import 'package:figureout/src/components/user_removable.dart';
import 'package:flame/components.dart';

/// P(vx, vy, gravity): editor units/second; positive vy launches upwards.
class ParabolaCommand implements ShapeBehavior {
  ParabolaCommand({
    required this.velocityX,
    required this.velocityY,
    required this.gravity,
    required this.flipY,
    required this.toPlayArea,
    required this.onMiss,
  });

  final double velocityX;
  final double velocityY;
  final double gravity;
  final Vector2 Function(Vector2) flipY;
  final Vector2 Function(Vector2, double, {bool clampInside}) toPlayArea;
  final void Function(PositionComponent shape) onMiss;

  @override
  Future<void> apply(PositionComponent shape) async {
    if (gravity <= 0 || velocityY <= 0) {
      throw FormatException('P requires positive launch speed and gravity');
    }
    final padding = shape.size.x / 2;
    Vector2 convert(Vector2 point) =>
        toPlayArea(flipY(point), padding, clampInside: false);
    final zero = convert(Vector2.zero());
    await shape.add(_ParabolaMotion(
      shape: shape,
      velocity: convert(Vector2(velocityX, velocityY)) - zero,
      acceleration: convert(Vector2(0, -gravity)) - zero,
      onMiss: onMiss,
    ));
  }

  @override
  String get command => 'P';
}

class _ParabolaMotion extends Component with HasGameReference {
  _ParabolaMotion({
    required this.shape,
    required this.velocity,
    required this.acceleration,
    required this.onMiss,
  });

  final PositionComponent shape;
  final Vector2 velocity;
  final Vector2 acceleration;
  final void Function(PositionComponent shape) onMiss;
  late final Vector2 _origin = shape.position.clone();
  double _elapsed = 0;
  bool _finished = false;

  @override
  void update(double dt) {
    super.update(dt);
    if (_finished || isShapePaused(shape)) return;
    if (shape.isRemoving ||
        (shape is UserRemovable && (shape as UserRemovable).wasRemovedByUser)) {
      _finished = true;
      return;
    }
    _elapsed += dt;
    shape.position = _origin + velocity * _elapsed +
        acceleration * (0.5 * _elapsed * _elapsed);

    // Do not remove a launch that starts below the screen while still rising.
    final descending = velocity.y + acceleration.y * _elapsed > 0;
    final radius = shape.size.length / 2;
    if (descending && shape.position.y - radius > game.size.y) {
      _finished = true;
      onMiss(shape);
      shape.removeFromParent();
    }
  }
}
