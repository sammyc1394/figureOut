import 'dart:math';

import 'package:figureout/src/functions/UserRemovable.dart';
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

  final void Function(PositionComponent shape, double alpha)? onFadeAlphaChanged;

  double _timer = 0;
  bool _visible = true;
  final _rng = Random();

  bool get isBlinkingInvisible => !_visible;
  bool get willReappear => !_visible && !isRemoving && !shape.isRemoving;
  bool isPaused = false;
  double? _pausedTimer;

  //Fade effect variables
  final List<double> _fadeSteps = [1.0, 0.75, 0.5, 0.25, 0.0];
  int _fadeIndex = 0;
  double _fadeTimer = 0;
  bool _fadeStarted = false;
  late double _fadeStepDuration;
  late double _fadeStartTime;

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
    this.onFadeAlphaChanged,
  }){
    _fadeStartTime = visibleDuration * 0.6;

    final fadeTotal = visibleDuration * 0.4;
    _fadeStepDuration = fadeTotal / (_fadeSteps.length - 1);
  }

  @override
  void update(double dt) {

    if (isPaused) return;

    if (_pausedTimer != null) {
      _timer = _pausedTimer!;
      _pausedTimer = null;
    }

    super.update(dt);

    if (shape is UserRemovable && (shape as UserRemovable).wasRemovedByUser) {

      // 애니메이션 끝난 뒤에만 정리
      if (shape.isMounted) {
        return;
      }

      removeFromParent();
      return;
    }
    _timer += dt;

    if (_visible && !_fadeStarted && _timer >= _fadeStartTime) {
      _fadeStarted = true;
      _fadeIndex = 0;
      _fadeTimer = 0;

      onFadeAlphaChanged?.call(shape, _fadeSteps[0]);
    }

    if (_visible && _fadeStarted) {

      _fadeTimer += dt;

      if (_fadeTimer >= _fadeStepDuration) {
        _fadeTimer = 0;

        if (_fadeIndex < _fadeSteps.length-1) {
          _fadeIndex++;
          onFadeAlphaChanged?.call(shape, _fadeSteps[_fadeIndex]);
        }
      }
    }

    if (_visible && _timer >= visibleDuration) {
      _timer = 0;
      _visible = false;
      _fadeStarted = false;
      _fadeIndex = 0;
      _fadeTimer = 0;

      onFadeAlphaChanged?.call(shape, 0.0);

      shape.removeFromParent();
    } else if (!_visible && _timer >= invisibleDuration) {
      _timer = 0;
      _visible = true;

      _fadeStarted = false;
      _fadeIndex = 0;
      _fadeTimer = 0;

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

        // game.add(shape);
        parent?.add(shape);
      }

      onFadeAlphaChanged?.call(shape, 1.0);
    }
  }
}
