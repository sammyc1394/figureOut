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

// 이동 셀에서 이동 명령과 함께 쓸 수 있는 타이밍 줄:
//   Wait 2          → 2초 기다림 ("Wait(2)"도 허용)
//   Disappear(3)    → 3초 뒤 도형 제거 ("Disappear 3"도 허용)
// 한 줄씩, 앞뒤 공백을 제거한 뒤 대소문자 구분 없이 매칭한다.
final RegExp _waitLineRegex = RegExp(
  r'^wait\s*\(?\s*(\d+(?:\.\d+)?)\s*\)?$',
  caseSensitive: false,
);
final RegExp _disappearLineRegex = RegExp(
  r'^disappear\s*\(?\s*(\d+(?:\.\d+)?)\s*\)?$',
  caseSensitive: false,
);

/// `Wait n` 줄이면 n(초), 아니면 null.
double? parseWaitLine(String line) {
  final match = _waitLineRegex.firstMatch(line.trim());
  return match == null ? null : double.tryParse(match.group(1)!);
}

/// `Disappear(n)` 줄이면 n(초), 아니면 null.
double? parseDisappearLine(String line) {
  final match = _disappearLineRegex.firstMatch(line.trim());
  return match == null ? null : double.tryParse(match.group(1)!);
}

/// 부모 도형의 "게임 시간"으로 [duration]초를 센다. 도형이 일시정지되어 있거나
/// (pause/aftermath 오버레이, [isShapePaused]) D/DR 블링크로 트리에서 빠져 있는
/// 동안에는 시간이 흐르지 않는다 — 실제 시간으로 계속 흐르는 `Future.delayed`와
/// 다른 점. 매 프레임 [onTick]에 진행률(0.0~1.0)을 넘기고, 끝나면 [onComplete]를
/// 한 번 호출한 뒤 스스로 제거된다.
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

/// [shape]의 게임 시간으로 [seconds]초 기다린다 ([ShapeTimerComponent] 참고).
/// 도형이 그 전에 완전히 제거되면 영원히 완료되지 않는데, 호출자는 사라진 도형을
/// 더 움직일 일이 없으므로 그대로 두면 된다.
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
