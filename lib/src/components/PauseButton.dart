import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

class PauseButton extends PositionComponent with TapCallbacks {
  static final _images = Images(prefix: 'assets/');
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
    final sprite = await Sprite.load('Pause_button_blue.png', images: _images);
    add(SpriteComponent(
      sprite: sprite,
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
