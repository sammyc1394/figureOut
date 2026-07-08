import 'dart:math';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' show Curves;

class EncircleSliceEffect extends PositionComponent {
  final Path basePath;
  final Color color;

  static const double _totalDuration = 0.70; // ~1.5x longer so fragments linger
  static const double _t1 = 0.67; // Phase 1 ends at ~67% (~313ms)

  // Pill flight directions (180° flip from previous):
  //   -pi/2   → UP          (fragment 1, vertical pill)
  //    pi/6   → lower-right (fragment 3)
  //   5*pi/6  → lower-left  (fragment 2)
  static const List<double> _pillDirs = [-pi / 2, pi / 6, 5 * pi / 6];

  double _elapsed = 0.0;
  bool isPaused = false;
  final double _initialAngle;
  late final double _cx, _cy, _shapeR;

  EncircleSliceEffect({
    required this.basePath,
    required this.color,
    required Vector2 position,
    required Vector2 size,
    Offset? pivot,
    double initialAngle = 0.0,
  })  : _initialAngle = initialAngle,
        super(size: size) {
    if (pivot != null) {
      _cx = pivot.dx;
      _cy = pivot.dy;
    } else {
      final b = basePath.getBounds();
      _cx = (b.left + b.right) / 2;
      _cy = (b.top + b.bottom) / 2;
    }
    _shapeR = (size.x + size.y) / 4;
    this.position = Vector2(position.x - _cx, position.y - _cy);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isPaused) return;
    _elapsed += dt;
    if (_elapsed >= _totalDuration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final t = (_elapsed / _totalDuration).clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    if (t <= _t1) {
      // Phase 1: basePath rotates 90° (ease-out) + minimal scale reduction
      final localT = (t / _t1).clamp(0.0, 1.0);
      final progress = Curves.easeOut.transform(localT);
      final angle = _initialAngle + (pi / 2) * progress;
      final sc = lerpDouble(1.0, 0.85, progress)!;

      canvas.save();
      canvas.translate(_cx, _cy);
      canvas.rotate(angle);
      canvas.scale(sc, sc);
      canvas.translate(-_cx, -_cy);
      canvas.drawPath(basePath, paint);
      canvas.restore();
    } else {
      // Phase 2: 3 short dash fragments fly outward from a tight, clearly-
      // separated cluster (reference: Triangle 5→8). Start as short dots with
      // visible gaps between them; length AND spread grow together to a peak;
      // past the peak, only the length shrinks back to its starting size
      // (spread keeps drifting outward, never retreats) and only then fades.
      final localT = ((t - _t1) / (1.0 - _t1)).clamp(0.0, 1.0);

      const double growEnd = 0.55; // growth phase ends here, then shrink begins

      // Fixed thickness (short axis) — kept thin so the fragment always reads
      // as a dash, never a fat blob.
      final pillHalfH = _shapeR * 0.07;
      final pillHalfWMax = _shapeR * 0.45;

      // Start/end half-length is derived from pillHalfH (not a magic fraction
      // of pillHalfWMax) so the fragment always starts as a near-round blob:
      // width ≈ height * 1.0~1.2, regardless of how pillHalfWMax is tuned.
      const double startWidthToHeightRatio = 1.1;
      final double startLen = (pillHalfH * startWidthToHeightRatio) / pillHalfWMax;

      // Half-length factor: startLen → 1.0x (0~growEnd, ease-out),
      // 1.0x → startLen (growEnd~100%, ease-in: slow start, fast finish).
      // Baked directly into the RRect geometry (not a canvas transform) so the
      // corner radius shrinks along with it instead of flooring the min size.
      final double lengthFactor;
      if (localT <= growEnd) {
        final p = Curves.easeOut.transform((localT / growEnd).clamp(0.0, 1.0));
        lengthFactor = lerpDouble(startLen, 1.0, p)!;
      } else {
        final p = Curves.easeIn.transform(
          ((localT - growEnd) / (1.0 - growEnd)).clamp(0.0, 1.0),
        );
        lengthFactor = lerpDouble(1.0, startLen, p)!;
      }
      final pillHalfW = pillHalfWMax * lengthFactor;

      // Position: spread grows monotonically for the whole phase (never
      // retreats back toward center, even while the length shrinks again).
      // Min spread is well beyond the fragment's own size so the 3 fragments
      // start clearly separated instead of overlapping at the center.
      final spreadP = Curves.easeOut.transform(localT);
      final spread = _shapeR * lerpDouble(0.44, 1.07, spreadP)!;

      // Opacity: holds full while growing/shrinking, only fades right at the
      // very end once the length is back down near its starting size.
      final double opacity;
      if (localT <= 0.8) {
        opacity = 1.0;
      } else {
        final fadeT = ((localT - 0.8) / 0.2).clamp(0.0, 1.0);
        opacity = 1.0 - Curves.easeIn.transform(fadeT);
      }

      // ignore: deprecated_member_use
      paint.color = color.withOpacity(opacity);

      final pillRRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: pillHalfW * 2, height: pillHalfH * 2),
        Radius.circular(min(pillHalfH, pillHalfW)),
      );

      for (final dir in _pillDirs) {
        canvas.save();
        canvas.translate(_cx + cos(dir) * spread, _cy + sin(dir) * spread);
        canvas.rotate(dir);
        canvas.drawRRect(pillRRect, paint);
        canvas.restore();
      }
    }
  }
}
