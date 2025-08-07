import 'dart:math';

import 'package:figureout/src/components/PentagonShape.dart';
import 'package:figureout/src/components/UserRemovable.dart';
import 'package:flame/components.dart';

class BlinkingBehaviorComponent extends Component with HasGameReference {
  final PositionComponent shape;
  final double visibleDuration;
  final double invisibleDuration;
  final bool isRandomRespawn;
  final Vector2? bounds;

  double _timer = 0;
  bool _visible = true;
  final _rng = Random();

  bool get isBlinkingInvisible => !_visible;
  bool get willReappear => !_visible && !isRemoving && !shape.isRemoving;
  bool isPaused = false;

  BlinkingBehaviorComponent({
    required this.shape,
    required this.visibleDuration,
    required this.invisibleDuration,
    this.isRandomRespawn = false,
    this.bounds,
  });

  @override
  void update(double dt) {
    super.update(dt);

    if (isPaused) return;

    if (shape is UserRemovable && (shape as UserRemovable).wasRemovedByUser) {
      // 사용자가 삼각형을 제거한 경우 깜빡임 종료
      removeFromParent(); // 깜빡임 종료
      return;
    }
    _timer += dt;

    if (_visible && _timer >= visibleDuration) {
      _timer = 0;
      _visible = false;
      shape.removeFromParent();
    } else if (!_visible && _timer >= invisibleDuration) {
      _timer = 0;
      _visible = true;
      // parent?.add(shape);
      if (!shape.isMounted) {
        if (isRandomRespawn && bounds != null) {
          final margin = 50.0;
          final x = margin + _rng.nextDouble() * (bounds!.x - 2 * margin);
          final y = margin + _rng.nextDouble() * (bounds!.y - 2 * margin);
          shape.position = Vector2(x, y);
        }

        game.add(shape);
      }
    }
  }
}
