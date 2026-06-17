import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class AttackExplosionEffect extends PositionComponent {
  final Path basePath;
  final Color color;
  final double duration;

  late final double _cx;
  late final double _cy;
  double _elapsed = 0;

  static const double _minScale = 1.0;
  static const double _maxScale = 3.0;
  static const double _ringSpacing = 0.30;
  static const int _maxRings = 9;

  AttackExplosionEffect({
    required this.basePath,
    required this.color,
    required Vector2 position,
    required Vector2 size,
    this.duration = 0.9,
  }) : super(size: size) {
    final bounds = basePath.getBounds();
    _cx = (bounds.left + bounds.right) / 2;
    _cy = (bounds.top + bounds.bottom) / 2;
    // position the component so that path center = shape center
    this.position = Vector2(position.x - _cx, position.y - _cy);
  }

  @override
  void update(double dt) {
    _elapsed += dt;
    if (_elapsed >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / duration).clamp(0.0, 1.0);

    // Global fade-out in the last 45%
    final globalAlpha = t < 0.55 ? 1.0 : (1.0 - t) / 0.45;
    if (globalAlpha <= 0) return;

    final outerScale = _minScale + (_maxScale - _minScale) * t;

    // Collect ring scales from outer to inner (inner drawn last = on top)
    final List<double> ringScales = [];
    double s = outerScale;
    while (s >= _minScale && ringScales.length < _maxRings) {
      ringScales.add(s);
      s -= _ringSpacing;
    }

    for (final ringScale in ringScales) {
      final progress = (ringScale - _minScale) / (_maxScale - _minScale);

      final opacity =
          ((1.0 - progress * 0.55) * globalAlpha).clamp(0.0, 1.0).toDouble();
      final stroke = (2.0 - progress * 0.8).clamp(0.5, 2.0).toDouble();

      if (opacity < 0.01) continue;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: opacity);

      canvas.save();
      canvas.translate(_cx, _cy);
      canvas.scale(ringScale, ringScale);
      canvas.translate(-_cx, -_cy);
      canvas.drawPath(basePath, paint);
      canvas.restore();
    }

    // Solid fill fades linearly over the first 40% of the animation,
    // overlapping with the rings so the transition feels like a blend not a cut.
    if (t < 0.40) {
      final fillT = t / 0.40;
      final fillOpacity =
          ((1.0 - fillT) * globalAlpha).clamp(0.0, 1.0).toDouble();

      if (fillOpacity > 0.01) {
        final fillScale = 1.0 + fillT * 0.05;

        final fillPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: fillOpacity);

        canvas.save();
        canvas.translate(_cx, _cy);
        canvas.scale(fillScale, fillScale);
        canvas.translate(-_cx, -_cy);
        canvas.drawPath(basePath, fillPaint);
        canvas.restore();
      }
    }
  }
}
