import 'dart:math';

import 'package:figureout/src/components/UserRemovable.dart';
import 'package:flame/components.dart';

class BlinkingBehaviorComponent extends Component with HasGameReference {
  final PositionComponent shape;
  final double visibleDuration;
  final double invisibleDuration;
  final bool isRandomRespawn;
  final Vector2? bounds;

  final double? xMin;
  final double? xMax;
  final double? yMin;
  final double? yMax;

  final double margin;

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
    this.xMin,
    this.xMax,
    this.yMin,
    this.yMax,
    this.margin = 50.0,
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
        if (isRandomRespawn) {
          final margin = 50.0;
          final screenW = game.size.x;
          final screenH = game.size.y;

          final xmin = (xMin ?? margin).clamp(0.0, screenW);
          final xmax = (xMax ?? (screenW - margin)).clamp(xmin, screenW);

          final ymin = (yMin ?? margin).clamp(0.0, screenH);
          final ymax = (yMax ?? (screenH - margin)).clamp(ymin, screenH);

          final x = xmin + _rng.nextDouble() * (xmax - xmin);
          final y = ymin + _rng.nextDouble() * (ymax - ymin);

          shape.position = Vector2(x, y);
        }

        game.add(shape);
      }
    }
  }
}
