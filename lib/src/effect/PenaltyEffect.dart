import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

class ForbiddenShapeEffect extends RectangleComponent {
  ForbiddenShapeEffect()
      : super(
    paint: Paint()..color = Colors.red,
    priority: 999999,
  ) {
    opacity = 0;
  }

  void flash() {
    removeAll(children);
    opacity = 0;

    add(
      SequenceEffect([
        OpacityEffect.to(
          0.18,
          EffectController(duration: 0.08),
        ),
        OpacityEffect.to(
          0,
          EffectController(duration: 0.7),
        ),
      ]),
    );
  }
}