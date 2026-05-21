import 'dart:math';
import 'dart:ui';

class ShapePathUtils {
  const ShapePathUtils._();

  static Path extractPartial(Path path, double length) {
    final result = Path();
    double remaining = length;

    for (final metric in path.computeMetrics()) {
      if (remaining <= 0) break;
      final segmentLength = remaining.clamp(0.0, metric.length);
      result.addPath(metric.extractPath(0, segmentLength), Offset.zero);
      remaining -= segmentLength;
    }

    return result;
  }

  // Figma Dynamic stroke: Frequency 136%, Wiggle 25%, Smoothen 83%
  // Multi-harmonic approach: low + mid + high frequency waves combined
  // for organic, irregular hand-drawn feel.
  static Path wobble(
    Path source, {
    double amplitude = 4,
  }) {
    final pts = <Offset>[];

    for (final metric in source.computeMetrics()) {
      final len = metric.length;
      // Steps must be ≥ 2× highest frequency to represent waves (Nyquist)
      final steps = max(80, (len / 3.5).round());
      for (var i = 0; i < steps; i++) {
        final progress = i / steps;
        final t = progress * len;
        final tan = metric.getTangentForOffset(t);
        if (tan == null) continue;
        final nx = -tan.vector.dy;
        final ny = tan.vector.dx;
        // Coprime frequencies → irregular, non-repeating pattern
        final wave = amplitude * (
          0.50 * sin(progress * 2 * pi * 11) +
          0.32 * sin(progress * 2 * pi * 19 + 1.1) +
          0.18 * sin(progress * 2 * pi * 29 + 2.6)
        );
        pts.add(Offset(
          tan.position.dx + nx * wave,
          tan.position.dy + ny * wave,
        ));
      }
    }

    if (pts.isEmpty) return source;

    // Catmull-Rom spline: smooth curves through all wobble points
    final n = pts.length;
    final result = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 0; i < n; i++) {
      final p0 = pts[(i - 1 + n) % n];
      final p1 = pts[i];
      final p2 = pts[(i + 1) % n];
      final p3 = pts[(i + 2) % n];
      final cp1 = Offset(p1.dx + (p2.dx - p0.dx) / 5, p1.dy + (p2.dy - p0.dy) / 5);
      final cp2 = Offset(p2.dx - (p3.dx - p1.dx) / 5, p2.dy - (p3.dy - p1.dy) / 5);
      result.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }
    return result..close();
  }
}
