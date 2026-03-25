import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class AttackExplosionEffect extends PositionComponent {
  final Path basePath;
  final Color color;               // required
  final double duration;
  final double maxScale;
  final double scaleSpacing;
  final double timeSpacing;
  final double startScale;

  double _elapsed = 0;

  AttackExplosionEffect({
    required this.basePath,
    required this.color,            // 여기 required
    required Vector2 position,
    required Vector2 size,
    this.duration = 0.8,
    this.maxScale = 2.5,
    this.scaleSpacing = 0.25,
    this.timeSpacing = 0.12,
    this.startScale = 0.25,
  }) : super(
    position: position,
    size: size,
    anchor: Anchor.center,
  );

  @override
  void update(double dt) {
    _elapsed += dt;
    if (_elapsed >= duration + timeSpacing) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final globalT = (_elapsed / duration).clamp(0.0, 1.0);

    final outerScale =
        startScale + (maxScale - startScale) * globalT;

    final maxRingCount =
    ((outerScale - startScale) / scaleSpacing).ceil();

    const double startStroke = 3.0;
    const double minStroke = 0.2;

    for (int i = 0; i <= maxRingCount; i++) {
      final scale = startScale + i * scaleSpacing;

      final appearTime = i * timeSpacing;
      final localT =
      ((_elapsed - appearTime) / duration).clamp(0.0, 1.0);

      if (localT <= 0 || localT >= 1) continue;

      final scaleRatio =
          (scale - startScale) / (maxScale - startScale);

      final thicknessCurve =
      pow(1 - scaleRatio, 1.6);

      final strokeWidth =
      (startStroke * thicknessCurve)
          .clamp(minStroke, startStroke)
          .toDouble();

      final opacity =
      pow(1 - localT, 1.2).clamp(0.0, 1.0);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = color.withOpacity(0.8)
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;

      canvas.save();

      canvas.translate(size.x / 2, size.y / 2);
      canvas.scale(scale, scale);
      canvas.translate(-size.x / 2, -size.y / 2);

      canvas.drawPath(basePath, paint);

      canvas.restore();
    }
  }
}
