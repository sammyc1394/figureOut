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
  bool isPaused = false;

  static const double _minScale = 1.0;
  final double _maxScale;
  final double _ringSpacing;
  final int _maxRings;
  final double _strokeMaxWidth;

  AttackExplosionEffect({
    required this.basePath,
    required this.color,
    required Vector2 position,
    required Vector2 size,
    this.duration = 0.9,
    // Local-space point to use as the scale pivot.
    // Defaults to the path's bounding-box centre.
    Offset? pivot,
    double maxScale = 3.0,
    double ringSpacing = 0.30,
    int maxRings = 9,
    double strokeMaxWidth = 2.0,
  })  : _maxScale = maxScale,
        _ringSpacing = ringSpacing,
        _maxRings = maxRings,
        _strokeMaxWidth = strokeMaxWidth,
        super(size: size) {
    if (pivot != null) {
      _cx = pivot.dx;
      _cy = pivot.dy;
    } else {
      final bounds = basePath.getBounds();
      _cx = (bounds.left + bounds.right) / 2;
      _cy = (bounds.top + bounds.bottom) / 2;
    }
    this.position = Vector2(position.x - _cx, position.y - _cy);
  }

  @override
  void update(double dt) {
    if (isPaused) return;
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
      final stroke =
          (_strokeMaxWidth * (1.0 - progress * 0.4)).clamp(0.4, _strokeMaxWidth).toDouble();

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

    // Solid fill fades linearly over the first 40%, overlapping with rings.
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
