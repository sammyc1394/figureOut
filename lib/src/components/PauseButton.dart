import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';

class PauseButton extends PositionComponent with TapCallbacks {
  final VoidCallback onPressed;

  PauseButton({
    required Vector2 position,
    required this.onPressed,
  }) : super(
          position: position,
          size: Vector2.all(25),
          anchor: Anchor.topRight,
        );

  @override
  Future<void> onLoad() async {
    final svg = await Svg.load('Pause_basic.svg'); // 준비해둔 Pause_basic.svg 경로
    final svgComponent = SvgComponent(
      svg: svg,
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
    add(svgComponent);
  }

  @override
  void onTapDown(TapDownEvent event) {
    onPressed();
  }
}
