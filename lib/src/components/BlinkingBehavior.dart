import 'UserRemovable.dart';
import 'package:flame/components.dart';

class BlinkingBehaviorComponent extends Component {
  final Component shape;
  final double visibleDuration;
  final double invisibleDuration;

  double _timer = 0;
  bool _visible = true;

  BlinkingBehaviorComponent({
    required this.shape,
    required this.visibleDuration,
    required this.invisibleDuration,
  });

  @override
  void update(double dt) {
    super.update(dt);

    if (shape is UserRemovable && (shape as UserRemovable).wasRemovedByUser) {
      // 사용자가 삼각형을 제거한 경우 깜빡임 종료
      removeFromParent(); // 깜빡임 종료
      return;
    }
    _timer += dt;

    if (_visible && _timer >= visibleDuration) {
      _timer = 0;
      _visible = false;
      shape.removeFromParent(); // 🔴 숨김
    } else if (!_visible && _timer >= invisibleDuration) {
      _timer = 0;
      _visible = true;
      parent?.add(shape); // 🟢 다시 추가
    }
  }
}
