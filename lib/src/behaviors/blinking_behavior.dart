import 'dart:math';

import 'package:figureout/src/components/user_removable.dart';
import 'package:flame/components.dart';

class BlinkingBehaviorComponent extends Component with HasGameReference {
  final PositionComponent shape;
  final double visibleDuration;
  final double invisibleDuration;
  final bool isRandomRespawn;

  final double? xMin;
  final double? xMax;
  final double? yMin;
  final double? yMax;


  final void Function(PositionComponent shape, double alpha)? onFadeAlphaChanged;

  double _timer = 0;
  bool _visible = true;
  final _rng = Random();

  bool get isBlinkingInvisible => !_visible;
  bool get willReappear => !_visible && !isRemoving && !shape.isRemoving;
  bool isPaused = false;

  // 표시 시간의 앞/뒤 40%를 페이드에 사용하고, 가운데 20%는 완전히 표시한다.
  static const double _fadeFraction = 0.4;
  double? _lastAlpha;

  BlinkingBehaviorComponent({
    required this.shape,
    required this.visibleDuration,
    required this.invisibleDuration,
    this.isRandomRespawn = false,
    this.xMin,
    this.xMax,
    this.yMin,
    this.yMax,
    this.onFadeAlphaChanged,
  }) {
    // 첫 등장도 투명한 상태에서 시작해 한 프레임 번쩍이는 것을 막는다.
    _setAlpha(0);
  }

  void _setAlpha(double alpha) {
    if (_lastAlpha == alpha) return;
    _lastAlpha = alpha;
    onFadeAlphaChanged?.call(shape, alpha);
  }

  // 양 끝에서 변화 속도가 0이 되어 유지 구간 및 다음 주기와 부드럽게 연결된다.
  double _smoothAlpha(double progress) {
    final t = progress.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  @override
  void update(double dt) {

    if (isPaused) return;

    super.update(dt);

    if (shape is UserRemovable && (shape as UserRemovable).wasRemovedByUser) {

      // 애니메이션 끝난 뒤에만 정리
      if (shape.isMounted) {
        return;
      }

      removeFromParent();
      return;
    }

    // BBC가 visible이라고 판단 중인데 도형이 실제로 없으면
    // 공격 타이머 등 외부 원인으로 제거된 것이므로 BBC도 함께 제거
    if (_visible && !shape.isMounted) {
      removeFromParent();
      return;
    }

    if (visibleDuration <= 0) {
      _visible = false;
      _setAlpha(0);
      return;
    }

    final cycleDuration = visibleDuration + invisibleDuration;
    final elapsed = _timer + dt;
    final startsNewCycle = elapsed >= cycleDuration;
    // 경계를 넘은 프레임의 남은 시간도 반영해 주기가 조금씩 밀리지 않게 한다.
    _timer = elapsed % cycleDuration;
    _visible = _timer < visibleDuration;

    if (startsNewCycle && isRandomRespawn) {
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

    if (!_visible) {
      _setAlpha(0);
      return;
    }

    final fadeDuration = visibleDuration * _fadeFraction;
    if (_timer < fadeDuration) {
      _setAlpha(_smoothAlpha(_timer / fadeDuration));
    } else if (_timer > visibleDuration - fadeDuration) {
      _setAlpha(_smoothAlpha((visibleDuration - _timer) / fadeDuration));
    } else {
      _setAlpha(1);
    }
  }
}
