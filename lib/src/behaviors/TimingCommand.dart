import 'dart:async';

import 'package:figureout/src/behaviors/ZCommand.dart';
import 'package:figureout/src/behaviors/shapeBehavior.dart';
import 'package:figureout/src/functions/blink_alpha_target.dart';
import 'package:flame/components.dart';

/// [TimingCommand.parse]가 이동 셀에서 떼어낸 타이밍 정보.
class MovementTiming {
  const MovementTiming({
    required this.waitSeconds,
    required this.disappearSeconds,
    required this.movement,
  });

  /// 맨 앞의 `Wait n` 줄들의 합 (0 = 없음).
  final double waitSeconds;

  /// `Disappear(n)` 줄의 n (null = 사라지지 않음).
  final double? disappearSeconds;

  /// 남은 줄들 — 실제 이동 명령.
  final String movement;

  bool get hasTiming => waitSeconds > 0 || disappearSeconds != null;
}

/// 이동 명령을 같은 셀의 타이밍 줄로 감싼다.
///
/// ```text
/// Wait 2            → 도형이 생성 위치에 2초 머문 뒤 이동을 시작한다
/// Z(200, 0, 100)
///
/// Z(160, 0, 250)    → (160, 0)으로 이동한 뒤, 경로가 끝나고 3초 뒤에
/// Disappear(3)        페이드아웃되며 웨이브에서 빠진다 (패널티/보상 없음)
/// ```
///
/// Disappear 카운트다운을 "이동이 끝난 뒤"로 미루는 것은 단순 Z 경로뿐이다.
/// 반복 경로(Repeat/Back)와 계속 움직이는 명령(B/C/D/DR/L/M)은 끝이 없으므로
/// 이동이 시작될 때 함께 카운트다운을 시작한다. 두 타이머 모두 도형의 게임
/// 시간으로 흐르므로 pause/aftermath 오버레이 동안 멈춘다
/// ([ShapeTimerComponent] 참고).
class TimingCommand implements ShapeBehavior {
  TimingCommand({
    required this.waitSeconds,
    required this.disappearSeconds,
    required this.inner,
    required this.onDisappear,
  });

  /// [onDisappear]로 제거되기 전 페이드아웃에 걸리는 시간.
  static const double fadeOutSeconds = 0.3;

  final double waitSeconds;
  final double? disappearSeconds;

  /// 셀이 가리키는 이동 명령 (없으면 null).
  final ShapeBehavior? inner;

  /// 도형을 게임에서 제거한다 (게임이 그 도형에 대해 들고 있는 것들 —
  /// 예: D/DR 블링크 컴포넌트 — 도 함께 정리).
  final void Function(PositionComponent shape) onDisappear;

  /// [raw]를 타이밍 줄과, 기존 명령 해석기가 이해하는 이동 줄로 나눈다.
  /// 첫 이동 줄 *앞*의 `Wait n`만 선행 대기로 친다. 두 Z 구간 사이의 Wait는
  /// ZCommand가 구간 사이에서 실행하도록 [MovementTiming.movement]에 남긴다.
  static MovementTiming parse(String raw) {
    final lines = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    double waitSeconds = 0.0;
    double? disappearSeconds;
    bool beforeMovement = true;
    final movementLines = <String>[];

    for (final line in lines) {
      final disappear = parseDisappearLine(line);
      if (disappear != null) {
        disappearSeconds ??= disappear;
        continue;
      }

      final wait = parseWaitLine(line);
      if (wait != null && beforeMovement) {
        waitSeconds += wait;
        continue;
      }

      beforeMovement = false;
      movementLines.add(line);
    }

    return MovementTiming(
      waitSeconds: waitSeconds,
      disappearSeconds: disappearSeconds,
      movement: movementLines.join('\n'),
    );
  }

  @override
  Future<void> apply(PositionComponent shape) async {
    // ZCommand와 같은 방식: 타임라인만 시작하고 스폰 루프는 막지 않는다.
    unawaited(_run(shape));
  }

  Future<void> _run(PositionComponent shape) async {
    if (waitSeconds > 0) {
      await waitShapeSeconds(shape, waitSeconds);
    }

    final inner = this.inner;
    if (inner != null) {
      await inner.apply(shape);
      if (inner is ZCommand) {
        await inner.sequenceDone;
      }
    }

    final disappearSeconds = this.disappearSeconds;
    if (disappearSeconds == null) return;

    await waitShapeSeconds(shape, disappearSeconds);

    if (shape is BlinkAlphaTarget) {
      final BlinkAlphaTarget fading = shape;
      await waitShapeSeconds(
        shape,
        fadeOutSeconds,
        onTick: (progress) => fading.setBlinkAlpha(1.0 - progress),
      );
    }

    onDisappear(shape);
  }

  @override
  String get command => 'T';
}
