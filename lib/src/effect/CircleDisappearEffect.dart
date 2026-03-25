import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class CircleDisappearEffect extends PositionComponent {
  final double radius;
  final Color color;

  static const int segmentCount = 8;
  static const double lifeTime = 0.8;

  // burst 비율 (영상 느낌 핵심)
  static const double burstRatio = 0.15;

  double _elapsed = 0.0;

  CircleDisappearEffect({
    required Vector2 position,
    required this.radius,
    required this.color,
  }) : super(
          position: position,
          anchor: Anchor.center,
        );

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    if (_elapsed >= lifeTime) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final t = (_elapsed / lifeTime).clamp(0.0, 1.0);
    final center = Offset.zero;

    // -------------------------------
    // 1️⃣ BURST PHASE
    // -------------------------------
    if (t < burstRatio) {
      final k = Curves.easeOut.transform(t / burstRatio);

      final paint = Paint()
        ..color = color.withOpacity(k)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;

      final burstLength = radius * lerpDouble(0.2, 1.0, k)!;

      for (int i = 0; i < segmentCount; i++) {
        final angle = (i / segmentCount) * pi * 2;
        final dir = Offset(cos(angle), sin(angle));

        final start = center + dir * (burstLength * 0.35);
        final end = center + dir * burstLength;

        canvas.drawLine(start, end, paint);
      }
      return;
    }

    // -------------------------------
    // 2️⃣ SHRINK PHASE
    // -------------------------------
    final shrinkT = (t - burstRatio) / (1.0 - burstRatio);
    final progress = Curves.easeIn.transform(shrinkT);

    final paint = Paint()
      ..color = color.withOpacity(1.0)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    // 안쪽 투명 원이 커지면서 사라짐
    final innerRadius = lerpDouble(
      radius * 0.70,
      radius,
      progress,
    )!;

    for (int i = 0; i < segmentCount; i++) {
      final angle = (i / segmentCount) * pi * 2;
      final dir = Offset(cos(angle), sin(angle));

      final start = center + dir * innerRadius;
      final end = center + dir * radius;

      canvas.drawLine(start, end, paint);
    }
  }
}
