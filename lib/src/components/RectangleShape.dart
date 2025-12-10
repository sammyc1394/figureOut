import 'package:figureout/src/functions/UserRemovable.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_svg/svg.dart';
import 'package:flame_svg/svg_component.dart';
import 'package:flutter/material.dart';

class RectangleShape extends PositionComponent with TapCallbacks,UserRemovable {
  int energy = 0;
  late final SvgComponent svg;

  bool isSliced = false;
  Vector2? sliceStart;
  Vector2? sliceEnd;

  final bool isDark;
  final VoidCallback? onForbiddenTouch;
  bool _penaltyFired = false;

  RectangleShape(Vector2 position, this.energy, {
    this.isDark = false,
    this.onForbiddenTouch,
  })
  // RectangleShape(Vector2 position)
    : super(position: position, size: Vector2(40, 80),anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final String asset = isDark ? 'DarkRectangle.svg' : 'Rectangle 3.svg';
    final svgData = await Svg.load(asset);
    svg = SvgComponent(
      svg: svgData,
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );

    add(svg);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    _renderRectangleShape(canvas);

    _renderSliceLine(canvas);
  }

  void _renderRectangleShape(Canvas canvas) {
    svg.render(canvas);

    if (!isDark && energy > 1) {
      _drawText(canvas, energy.toString());
    }
  }

  void _drawText(Canvas canvas, String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Color(0xFF4680FF), fontSize: 20),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final offset = Offset(
      (size.x - textPainter.width) / 2,
      (size.y - textPainter.height) / 2,
    );

    canvas.save();

    textPainter.paint(canvas, offset);
    canvas.restore();
  }

  void _renderSliceLine(Canvas canvas) {
    // Draw the slice line if it exists
    if (sliceStart != null && sliceEnd != null) {
      final slicePaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      final toLocal = absoluteCenter - size /2;

      final localStart = sliceStart! - toLocal;
      final localEnd = sliceEnd! - toLocal;

      canvas.drawLine(
        Offset(localStart.x, localStart.y),
        Offset(localEnd.x, localEnd.y),
        slicePaint,
      );
    }
  }
  
  @override
  void onTapDown(TapDownEvent event) {
    if (isDark) {
      onForbiddenTouch?.call();
    }
  }

  void touchAtPoint(List<Vector2> userPath) {
    if (userPath.length < 2 || isSliced) return;

    // Check if the user path slices through the rectangle
    final slicePoints = getSlicePoints(userPath);
    if (slicePoints != null) {
      if (isDark) {
        for (final p in userPath) {
          if (toRect().contains(Offset(p.x, p.y))) {
            onForbiddenTouch?.call();
            break;
          }
        }
        // 다크는 잘리지 않음
        return;
      }

      print('[SLICE] Rectangle at $position');

      // Store the slice line points
      sliceStart = slicePoints.start;
      sliceEnd = slicePoints.end;
      isSliced = true;

      // Remove after showing the slice effect
      Future.delayed(Duration(milliseconds: 400), () {
        removeFromParent();
        wasRemovedByUser = true;
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
      final intersections = getLineRectangleIntersections(
        start,
        end,
        rectBounds,
      );
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

  List<Vector2> getLineRectangleIntersections(
    Vector2 start,
    Vector2 end,
    Rect rect,
  ) {
    List<Vector2> intersections = [];

    // Check intersection with top edge
    final topIntersection = getLineIntersection(
      start,
      end,
      Vector2(rect.left, rect.top),
      Vector2(rect.right, rect.top),
    );
    if (topIntersection != null) intersections.add(topIntersection);

    // Check intersection with bottom edge
    final bottomIntersection = getLineIntersection(
      start,
      end,
      Vector2(rect.left, rect.bottom),
      Vector2(rect.right, rect.bottom),
    );
    if (bottomIntersection != null) intersections.add(bottomIntersection);

    // Check intersection with left edge
    final leftIntersection = getLineIntersection(
      start,
      end,
      Vector2(rect.left, rect.top),
      Vector2(rect.left, rect.bottom),
    );
    if (leftIntersection != null) intersections.add(leftIntersection);

    // Check intersection with right edge
    final rightIntersection = getLineIntersection(
      start,
      end,
      Vector2(rect.right, rect.top),
      Vector2(rect.right, rect.bottom),
    );
    if (rightIntersection != null) intersections.add(rightIntersection);

    return intersections;
  }

  Vector2? getLineIntersection(Vector2 p1, Vector2 p2, Vector2 p3, Vector2 p4) {
    final denom = (p1.x - p2.x) * (p3.y - p4.y) - (p1.y - p2.y) * (p3.x - p4.x);
    if (denom == 0) return null; // Lines are parallel

    final t =
        ((p1.x - p3.x) * (p3.y - p4.y) - (p1.y - p3.y) * (p3.x - p4.x)) / denom;
    final u =
        -((p1.x - p2.x) * (p1.y - p3.y) - (p1.y - p2.y) * (p1.x - p3.x)) /
        denom;

    // Check if intersection is within both line segments
    if (t >= 0 && t <= 1 && u >= 0 && u <= 1) {
      return Vector2(p1.x + t * (p2.x - p1.x), p1.y + t * (p2.y - p1.y));
    }

    return null;
  }
}

class SlicePoints {
  final Vector2 start;
  final Vector2 end;

  SlicePoints({required this.start, required this.end});
}
