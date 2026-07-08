import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Curves;

class HexagonBurstEffect extends PositionComponent {
  final double radius;
  final Color color;

  static const int _segmentCount = 6;
  // Aligns each fragment with a hexagon vertex direction (matches
  // HexagonShape._buildHexagonPath's i * 60 degree layout, no offset).
  static const double _angleOffset = 0.0;

  static const double _totalDuration = 0.35;
  static const double _growEnd = 0.55; // peak dash length reached here, then shrink

  // How far the dash's slight hand-drawn bend swings off the straight axis,
  // as a fraction of the dash's own half-length — small on purpose, this is
  // a subtle wiggle, not the pronounced S-bend that read as a "wave".
  static const double _curveAmpRatio = 0.15;

  double _elapsed = 0.0;
  bool isPaused = false;

  HexagonBurstEffect({
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

    final pillHalfH = radius * 0.035;
    final pillHalfLMax = radius * 0.24;

    // Short, near-round "bean" at spawn and right before the pop — note the
    // round stroke caps already add pillHalfH of visible length past each
    // path endpoint, so this only needs to be a small fraction of pillHalfH
    // to read as short (reference: short frame vs. the elongated max frame).
    final startHalfLen = pillHalfH * 0.3;

    // Shared growth curve: spread and length both start growing at t=0 and
    // both reach their peak at the exact same moment (_growEnd), since they
    // use this same clamped progress value — no independent timing for
    // either one. Linear on purpose: an eased (easeOut) curve front-loads
    // most of the growth into the first frame or two, which read as the
    // fragments already being long/spread out right from the start.
    final growP = (t / _growEnd).clamp(0.0, 1.0);

    // Half-length: startHalfLen → pillHalfLMax (0~growEnd, via growP), then
    // pillHalfLMax → startHalfLen (growEnd~100%, ease-in) — grows to a peak,
    // then shrinks back down to a short blob before popping away.
    final double pillHalfL;
    if (t <= _growEnd) {
      pillHalfL = lerpDouble(startHalfLen, pillHalfLMax, growP)!;
    } else {
      final p = Curves.easeIn.transform(
        ((t - _growEnd) / (1.0 - _growEnd)).clamp(0.0, 1.0),
      );
      pillHalfL = lerpDouble(pillHalfLMax, startHalfLen, p)!;
    }

    // Spread (distance from center): grows in lockstep with the length
    // (same growP curve, so it starts and peaks at the same moments), then
    // holds at its max — growP naturally stays at 1.0 past _growEnd — while
    // only the length shrinks back down and opacity fades.
    final spread = radius * lerpDouble(0.44, 1.07, growP)!;

    // Opacity holds full almost the whole time, then fades hard right at
    // the very end so the dashes visibly pop away (reference frame 8→9).
    final double opacity;
    if (t <= 0.8) {
      opacity = 1.0;
    } else {
      final fadeT = ((t - 0.8) / 0.2).clamp(0.0, 1.0);
      opacity = 1.0 - Curves.easeIn.transform(fadeT);
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
      final angle = _angleOffset + (i / _segmentCount) * pi * 2;
      canvas.save();
      canvas.translate(cos(angle) * spread, sin(angle) * spread);
      canvas.rotate(angle);
      canvas.drawPath(dashPath, paint);
      canvas.restore();
    }
  }

  // A gently bent segment along the local X axis (the dash's long axis)
  // from -halfLen to +halfLen — just a slight hand-drawn wiggle, not a
  // pronounced S-curve — with strokeCap.round giving blunt (never pointy)
  // ends regardless of length.
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
