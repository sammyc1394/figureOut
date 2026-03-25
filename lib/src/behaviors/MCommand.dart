import 'package:figureout/src/behaviors/shapeBehavior.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

class MCommand implements ShapeBehavior {
  final double angleDeg;
  final double speed;
  final String stopY;

  final Vector2 position;
  final Vector2 size;

  final Vector2 Function(Vector2) flipY;
  final Vector2 Function(Vector2, double, {bool clampInside}) toPlayArea;

  MCommand({
    required this.angleDeg,
    required this.speed,
    required this.stopY,
    required this.position,
    required this.size,
    required this.flipY,
    required this.toPlayArea,
  });

  @override
  Future<void> apply(PositionComponent shape) async {
    final halfSizeX = shape.size.x / 2;

    double yCoord = position.y;

    if (stopY.contains("Y")) {
      yCoord = size.y;
    } else {
      yCoord = double.parse(stopY);
    }

    final target = toPlayArea(
      flipY(Vector2(position.x, yCoord)),
      halfSizeX,
      clampInside: false,
    );

    final comp = shape;

    // 기존 이펙트 제거
    for (final e in List.of(comp.children.whereType<Effect>())) {
      e.removeFromParent();
    }

    // 시작 위치
    comp.position = position;

    const showDelay = 0.25;
    final originalScale = comp.scale.clone();

    comp.add(
      ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: 0.10, startDelay: showDelay),
        onComplete: () {
          comp.position = position;

          comp.add(
            ScaleEffect.to(
              originalScale,
              EffectController(duration: 0.50),
              onComplete: () {
                final distance = comp.position.distanceTo(target);
                final duration = distance / speed;

                comp.add(
                  MoveEffect.to(
                    target,
                    EffectController(
                      duration: duration,
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
  String get command => throw UnimplementedError();
}