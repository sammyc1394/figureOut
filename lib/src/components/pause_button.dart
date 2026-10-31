import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_svg/svg.dart';
import 'package:flame_svg/svg_component.dart';
import 'package:flutter/material.dart';

class PauseButton extends PositionComponent with TapCallbacks {
  final VoidCallback onPressed;

  PauseButton({
    required Vector2 position,
    required this.onPressed,
  }) : super(
          position: position,
          size: Vector2(28.3, 35.0),
          anchor: Anchor.topRight,
        );

  @override
  Future<void> onLoad() async {
    final svg = await Svg.load('menu/common/Pause_button_blue.svg');
    add(SvgComponent(
      svg: svg,
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    ));
  }

  @override
  void onTapDown(TapDownEvent event) {
    onPressed();
  }
}
