import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Curves;

class CircleDisappearEffect extends PositionComponent {
  final double radius;
  final Color color;

  static const int _segmentCount = 8;
  static const double _totalDuration = 0.35;
  static const double _growEnd = 0.5; // peak dash length reached here, then shrink

  // Spread reaches its final radius within this absolute time (independent
  // of _totalDuration), then holds there while length/opacity keep animating.
  static const double _spreadDuration = 0.075;

  // How far the S-bend's control points swing off the straight axis,
  // as a fraction of the dash's own half-length.
  static const double _curveAmpRatio = 0.42;

  double _elapsed = 0.0;
  bool isPaused = false;

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
    if (isPaused) return;
    _elapsed += dt;
    if (_elapsed >= _totalDuration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final t = (_elapsed / _totalDuration).clamp(0.0, 1.0);

    final pillHalfH = radius * 0.059;
    final pillHalfLMax = radius * 0.096;

    // Short, near-round "bean" at spawn and right before the pop — note the
    // round stroke caps already add pillHalfH of visible length past each
    // path endpoint, so this only needs to be a small fraction of pillHalfH
    // to read as short (reference: short frame vs. the elongated max frame).
    final startHalfLen = pillHalfH * 0.3;

    // Half-length: startHalfLen → pillHalfLMax (0~growEnd, ease-out), then
    // pillHalfLMax → startHalfLen (growEnd~100%, ease-in) — grows to a peak,
    // then shrinks back down to a short blob before popping away.
    final double pillHalfL;
    if (t <= _growEnd) {
      final p = Curves.easeOut.transform(t / _growEnd);
      pillHalfL = lerpDouble(startHalfLen, pillHalfLMax, p)!;
    } else {
      final p = Curves.easeIn.transform((t - _growEnd) / (1.0 - _growEnd));
      pillHalfL = lerpDouble(pillHalfLMax, startHalfLen, p)!;
    }

    // Spread (distance from center) snaps out fast — full radius reached
    // within _spreadDuration (linear, not eased, so it doesn't front-load
    // into the very first frame) — then holds there for the remainder of
    // the effect while only opacity/length keep animating.
    final spreadT = (_elapsed / _spreadDuration).clamp(0.0, 1.0);
    final spread = radius * lerpDouble(0.46, 0.95, spreadT)!;

    // Opacity holds full almost the whole time, then fades hard right at
    // the very end so the dashes visibly pop away (reference frame 4→5).
    final double opacity;
    if (t <= 0.82) {
      opacity = 1.0;
    } else {
      opacity = 1.0 - Curves.easeIn.transform((t - 0.82) / 0.18);
    }
    if (opacity <= 0.01) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = pillHalfH * 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: opacity);

    final dashPath = _buildDashPath(pillHalfL);

    for (int i = 0; i < _segmentCount; i++) {
      final angle = (i / _segmentCount) * pi * 2;
      canvas.save();
      canvas.translate(cos(angle) * spread, sin(angle) * spread);
      canvas.rotate(angle);
      canvas.drawPath(dashPath, paint);
      canvas.restore();
    }
  }

  // A single cubic-bezier S-bend along the local X axis (the dash's long
  // axis) from -halfLen to +halfLen, so the curve is visible across the
  // whole dash rather than only in one small kink, with strokeCap.round
  // giving blunt (never pointy) ends regardless of length.
  Path _buildDashPath(double halfLen) {
    final amp = halfLen * _curveAmpRatio;
    return Path()
      ..moveTo(-halfLen, 0)
      ..cubicTo(
        -halfLen * 0.33, amp,
        halfLen * 0.33, -amp,
        halfLen, 0,
      );
  }
}
