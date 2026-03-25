import 'dart:ui';

import 'package:figureout/src/behaviors/shapeBehavior.dart';
import 'package:flame/components.dart';

import '../functions/BlinkingBehavior.dart';

class DDrCommand implements ShapeBehavior {
  late final double visibleDuration;
  late final double invisibleDuration;
  final bool isRandomRespawn;

  late final Rect Function() timerRectWorld;
  late final Vector2 gameSize;

  late final Map<PositionComponent, dynamic> blinkingMap;

  DDrCommand({
    required this.visibleDuration,
    required this.invisibleDuration,
    required this.timerRectWorld,
    required this.gameSize,
    required this.blinkingMap,
    this.isRandomRespawn = false,
  });

  @override
  Future<void> apply(PositionComponent shape) async {
    await shape.loaded;

    final r = timerRectWorld();

    const pad = 8.0;
    const margin = 50.0;

    final halfW = shape.size.x / 2;
    final halfH = shape.size.y / 2;

    // 타이머바 "아래" 영역 (Y는 아래로 증가)
    final minYCenter = r.bottom + pad + halfH;
    final maxYCenter = gameSize.y - margin - halfH;

    // 화면 좌우 여백 고려
    final minXCenter = margin + halfW;
    final maxXCenter = gameSize.x - margin - halfW;

    // 시작 위치도 즉시 범위 안으로
    shape.position = Vector2(
      shape.position.x.clamp(minXCenter, maxXCenter),
      shape.position.y.clamp(minYCenter, maxYCenter),
    );

    final blinking = BlinkingBehaviorComponent(
      shape: shape,
      visibleDuration: visibleDuration,
      invisibleDuration: invisibleDuration,
      isRandomRespawn: isRandomRespawn,
      xMin: minXCenter,
      xMax: maxXCenter,
      yMin: minYCenter,
      yMax: maxYCenter,
      onFadeAlphaChanged: onFadeAlphaChanged,
    );

    blinkingMap[shape] = blinking;

    shape.parent?.add(blinking);
  }

  void onFadeAlphaChanged(PositionComponent shape, double alpha) {
    final target = shape as dynamic;

    try {
      target.setBlinkAlpha(alpha);
    } catch (e) {
      print('[BLINK ALPHA] setBlinkAlpha not found on ${shape.runtimeType}: $e');
    }
  }

  @override
  // TODO: implement command
  String get command => throw UnimplementedError();
}