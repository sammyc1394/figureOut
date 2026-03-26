import 'dart:async';

import 'package:figureout/src/behaviors/shapeBehavior.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';

class LCommand implements ShapeBehavior {
  final String movementRaw;
  final Vector2 Function(Vector2) flipY;
  final Vector2 Function(Vector2, double, {bool clampInside}) toPlayArea;

  LCommand({
    required this.movementRaw,
    required this.flipY,
    required this.toPlayArea,
  });

  @override
  Future<void> apply(PositionComponent shape) async {
    unawaited(_run(shape));
  }

  Future<void> _run(PositionComponent shape) async {
    while (!shape.isMounted) {
      await Future<void>.delayed(Duration.zero);
    }

    final raw = movementRaw.trim();

    final match = RegExp(
      r'^(?:L)?\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*,\s*(\d+(?:\.\d+)?)\s*\)$',
    ).firstMatch(raw);

    if (match == null) {
      print('[LCommand] parse failed: $raw');
      return;
    }

    final dx1 = double.parse(match.group(1)!);
    final dy1 = double.parse(match.group(2)!);
    final dx2 = double.parse(match.group(3)!);
    final dy2 = double.parse(match.group(4)!);
    final speed = double.parse(match.group(5)!);

    final halfSize = shape.size.x / 2;

    final p1 = toPlayArea(
      flipY(Vector2(dx1, dy1)),
      halfSize,
      clampInside: true,
    );

    final p2 = toPlayArea(
      flipY(Vector2(dx2, dy2)),
      halfSize,
      clampInside: true,
    );

    for (final e in List.of(shape.children.whereType<Effect>())) {
      e.removeFromParent();
    }

    final originalScale = shape.scale.clone();

    shape.add(
      ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: 0.10, startDelay: 0.25),
        onComplete: () {
          if (!shape.isMounted) return;

          shape.position = p1;

          shape.add(
            ScaleEffect.to(
              originalScale,
              EffectController(duration: 0.50),
              onComplete: () {
                if (!shape.isMounted) return;

                final distance = p1.distanceTo(p2);
                final duration = speed <= 0 ? 0.0 : distance / speed;

                if (duration <= 0) {
                  shape.position = p2;
                  return;
                }

                shape.add(
                  MoveEffect.to(
                    p2,
                    EffectController(
                      duration: duration,
                      alternate: true,
                      infinite: true,
                      curve: Curves.linear,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  String get command => 'L';
}