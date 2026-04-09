import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'shapeBehavior.dart';

class BCommand implements ShapeBehavior {
  // B(x0, y0, speed) 의 x0, y0
  final Vector2 startEditor;

  // H열 위치에서 이미 계산된 월드 좌표
  final Vector2 directionWorld;

  final double speed;

  final Vector2 Function(Vector2) flipY;
  final Vector2 Function(Vector2, double, {bool clampInside}) toPlayArea;
  final Rect Function() playAreaRect;

  BCommand({
    required this.startEditor,
    required this.directionWorld,
    required this.speed,
    required this.flipY,
    required this.toPlayArea,
    required this.playAreaRect,
  });

  @override
  Future<void> apply(PositionComponent shape) async {
    final halfWidth = shape.size.x / 2;
    final halfHeight = shape.size.y / 2;
    final shapePadding = math.max(halfWidth, halfHeight);

    // 시작점만 에디터 좌표 -> 월드 좌표 변환
    final startWorld = toPlayArea(
      flipY(startEditor),
      shapePadding,
      clampInside: true,
    );

    // 방향점은 이미 월드 좌표
    final targetWorld = directionWorld.clone();

    shape.position = startWorld;

    Vector2 dir = targetWorld - startWorld;
    if (dir.length2 == 0) {
      dir = Vector2(1, 0);
    } else {
      dir.normalize();
    }

    shape.add(
      BounceMoveComponent(
        velocity: dir * speed,
        halfWidth: halfWidth,
        halfHeight: halfHeight,
        playAreaRect: playAreaRect,
      ),
    );
  }

  @override
  String get command => 'B';
}

class BounceMoveComponent extends Component {
  Vector2 velocity;
  final double halfWidth;
  final double halfHeight;
  final Rect Function() playAreaRect;

  bool isPaused = false;

  static const double _eps = 0.000001;

  BounceMoveComponent({
    required this.velocity,
    required this.halfWidth,
    required this.halfHeight,
    required this.playAreaRect,
  });

  @override
  void update(double dt) {
    if (isPaused) return;
    super.update(dt);

    final shape = parent as PositionComponent;
    final rect = playAreaRect();

    final left = rect.left + halfWidth;
    final right = rect.right - halfWidth;
    final top = rect.top + halfHeight;
    final bottom = rect.bottom - halfHeight;

    double remainingTime = dt;
    int guard = 0;

    while (remainingTime > _eps && guard < 8) {
      guard++;

      final pos = shape.position;

      double tx = double.infinity;
      double ty = double.infinity;

      if (velocity.x > _eps) {
        tx = (right - pos.x) / velocity.x;
      } else if (velocity.x < -_eps) {
        tx = (left - pos.x) / velocity.x;
      }

      if (velocity.y > _eps) {
        ty = (bottom - pos.y) / velocity.y;
      } else if (velocity.y < -_eps) {
        ty = (top - pos.y) / velocity.y;
      }

      final hitTimeX = tx >= 0 ? tx : double.infinity;
      final hitTimeY = ty >= 0 ? ty : double.infinity;
      final hitTime = math.min(hitTimeX, hitTimeY);

      if (hitTime == double.infinity || hitTime > remainingTime) {
        shape.position += velocity * remainingTime;
        break;
      }

      // 충돌 지점까지 이동
      shape.position += velocity * hitTime;

      final hitX = (hitTimeX - hitTime).abs() < _eps;
      final hitY = (hitTimeY - hitTime).abs() < _eps;

      if (hitX) {
        velocity.x = -velocity.x;
      }
      if (hitY) {
        velocity.y = -velocity.y;
      }

      shape.position.x = shape.position.x.clamp(left, right);
      shape.position.y = shape.position.y.clamp(top, bottom);

      remainingTime -= hitTime;
    }
  }
}