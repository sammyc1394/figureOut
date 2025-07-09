import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';

import '../config.dart';

class PlayArea extends RectangleComponent {
  PlayArea()
    : super(
        paint: Paint()..color = const Color(0xFFECEFF1),
        anchor: Anchor.center,
      );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    size = Vector2(gameWidth, gameHeight);
  }
}
