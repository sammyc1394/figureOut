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
}
