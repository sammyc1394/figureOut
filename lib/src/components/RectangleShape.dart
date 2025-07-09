import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class RectangleShape extends RectangleComponent {
  int energy = 0;
  bool isSliced = false;
  Vector2? sliceStart;
  Vector2? sliceEnd;

  RectangleShape(Vector2 position)
      : super(
    size: Vector2(30, 60),
    paint: Paint()..color = const Color(0xFF673AB7),
  ) {
    this.position = position;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw the slice line if it exists
    if (sliceStart != null && sliceEnd != null) {
      final slicePaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      // Convert absolute coordinates to local coordinates
      final localStart = sliceStart! - position;
      final localEnd = sliceEnd! - position;

      canvas.drawLine(
        Offset(localStart.x, localStart.y),
        Offset(localEnd.x, localEnd.y),
        slicePaint,
      );
    }
  }

  void touchAtPoint(List<Vector2> userPath) {
    if (userPath.length < 2 || isSliced) return;

    // Check if the user path slices through the rectangle
    final slicePoints = getSlicePoints(userPath);
    if (slicePoints != null) {
      print('[SLICE] Rectangle at $position');

      // Store the slice line points
      sliceStart = slicePoints.start;
      sliceEnd = slicePoints.end;
      isSliced = true;

      // Remove after showing the slice effect
      Future.delayed(Duration(milliseconds: 800), () {
        removeFromParent();
      });
    }
  }

  SlicePoints? getSlicePoints(List<Vector2> userPath) {
    final rectBounds = toRect();
    List<Vector2> intersectionPoints = [];

    // Check each segment of the user path
    for (int i = 0; i < userPath.length - 1; i++) {
      final start = userPath[i];
      final end = userPath[i + 1];

      // Find intersection points with rectangle edges
      final intersections = getLineRectangleIntersections(start, end, rectBounds);
      intersectionPoints.addAll(intersections);
    }

    // If we have at least 2 intersection points, we have a slice
    if (intersectionPoints.length >= 2) {
      // Use the first and last intersection points for the slice line
      return SlicePoints(
        start: intersectionPoints.first,
        end: intersectionPoints.last,
      );
    }

    return null;
  }

  List<Vector2> getLineRectangleIntersections(Vector2 start, Vector2 end, Rect rect) {
    List<Vector2> intersections = [];

    // Check intersection with top edge
    final topIntersection = getLineIntersection(
        start, end,
        Vector2(rect.left, rect.top), Vector2(rect.right, rect.top)
    );
    if (topIntersection != null) intersections.add(topIntersection);

    // Check intersection with bottom edge
    final bottomIntersection = getLineIntersection(
        start, end,
        Vector2(rect.left, rect.bottom), Vector2(rect.right, rect.bottom)
    );
    if (bottomIntersection != null) intersections.add(bottomIntersection);

    // Check intersection with left edge
    final leftIntersection = getLineIntersection(
        start, end,
        Vector2(rect.left, rect.top), Vector2(rect.left, rect.bottom)
    );
    if (leftIntersection != null) intersections.add(leftIntersection);

    // Check intersection with right edge
    final rightIntersection = getLineIntersection(
        start, end,
        Vector2(rect.right, rect.top), Vector2(rect.right, rect.bottom)
    );
    if (rightIntersection != null) intersections.add(rightIntersection);

    return intersections;
  }

  Vector2? getLineIntersection(Vector2 p1, Vector2 p2, Vector2 p3, Vector2 p4) {
    final denom = (p1.x - p2.x) * (p3.y - p4.y) - (p1.y - p2.y) * (p3.x - p4.x);
    if (denom == 0) return null; // Lines are parallel

    final t = ((p1.x - p3.x) * (p3.y - p4.y) - (p1.y - p3.y) * (p3.x - p4.x)) / denom;
    final u = -((p1.x - p2.x) * (p1.y - p3.y) - (p1.y - p2.y) * (p1.x - p3.x)) / denom;

    // Check if intersection is within both line segments
    if (t >= 0 && t <= 1 && u >= 0 && u <= 1) {
      return Vector2(
        p1.x + t * (p2.x - p1.x),
        p1.y + t * (p2.y - p1.y),
      );
    }

    return null;
  }
}

class SlicePoints {
  final Vector2 start;
  final Vector2 end;

  SlicePoints({required this.start, required this.end});
}