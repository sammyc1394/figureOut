import 'package:figureout/src/functions/UserRemovable.dart';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_svg/svg.dart';
import 'package:flame_svg/svg_component.dart';
import 'package:flutter/material.dart';

class RectangleShape extends PositionComponent with TapCallbacks,UserRemovable {
  int energy = 0;
  late final SvgComponent svg;
  late final SpriteComponent _png;

  bool isSliced = false;
  Vector2? sliceStart;
  Vector2? sliceEnd;

  final bool isDark;
  final VoidCallback? onForbiddenTouch;
  bool _penaltyFired = false;

  final double? attackTime;
  final VoidCallback? onExplode;

  double _attackElapsed = 0.0;
  bool _attackDone = false;
  bool isPaused = false;

  late Path _outlinePath;
  late double _outlineLength;

  final Paint _attackPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xFF7CA6FF);

  final Color dangerColor = const Color(0xFFEE0505);
  final Color baseColor = const Color(0xFF7CA6FF);

  RectangleShape(Vector2 position, this.energy, {
    this.isDark = false,
    this.onForbiddenTouch,
    this.attackTime,
    this.onExplode,
  })
  // RectangleShape(Vector2 position)
    : super(position: position, size: Vector2(40, 80),anchor: Anchor.center,);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // final svgData = await Svg.load('Rectangle 3.svg');
    final String asset = isDark ? 'DarkRectangle.svg' : 'Rectangle 3.svg';
    final svgData = await Svg.load(asset);
    svg = SvgComponent(
      svg: svgData,
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );

    add(svg);

    final images = Images(prefix: 'assets/');
    final img = await images.load('shapes/Rectangle.png');

    _png = SpriteComponent(
      sprite: Sprite(img),
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
    _png.opacity = 0;
    add(_png);

    // ===== attackTime 있으면 PNG로 시작 =====
    if ((attackTime ?? 0) > 0) {
      svg.opacity = 0;
      _png.opacity = 1;
    }

    // ===== build rectangle outline path =====
    _outlinePath = _buildRectPath(size.toSize());
    _outlineLength = _outlinePath
        .computeMetrics()
        .fold(0.0, (sum, m) => sum + m.length);
  }

  Path _buildRectPath(Size s) {
    final inset = (_attackPaint.strokeWidth / 2)-1.0;
    return Path()
      ..moveTo(inset, inset)
      ..lineTo(s.width - inset, inset)
      ..lineTo(s.width - inset, s.height - inset)
      ..lineTo(inset, s.height - inset)
      ..close();
  }

  Path _extractPartialPath(Path path, double length) {
    final result = Path();
    double remaining = length;

    for (final metric in path.computeMetrics()) {
      if (remaining <= 0) break;
      final len = remaining.clamp(0.0, metric.length);
      result.addPath(metric.extractPath(0, len), Offset.zero);
      remaining -= len;
    }
    return result;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isPaused) return;
    if ((attackTime ?? 0) <= 0) return;

    _attackElapsed += dt;

    if (!_attackDone && _attackElapsed >= attackTime!) {
      _attackDone = true;

      _png.opacity = 0;
      svg.opacity = 1;
      
      onExplode?.call();
    }

    // 절반 이하 → 빨간 tint
    if (!_attackDone && _attackTimeHalfLeft) {
      _png.paint = Paint()
        ..colorFilter = ColorFilter.mode(
          dangerColor,
          BlendMode.srcIn,
        );
    }
  }

  bool get _attackTimeHalfLeft {
    if ((attackTime ?? 0) <= 0) return false;
    final ratio =
        ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);
    return ratio <= 0.2;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    _renderRectangleShape(canvas);

    // ===== perimeter timer =====
    if ((attackTime ?? 0) > 0 && !_attackDone) {
      final ratio =
          ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);
      final drawLen = _outlineLength * ratio;

      _attackPaint.color = ratio <= 0.2 ? dangerColor : baseColor;

      final partial = _extractPartialPath(_outlinePath, drawLen);
      canvas.drawPath(partial, _attackPaint);
    }

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

      // Convert absolute coordinates to local coordinates
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
      // if (isDark&& !_penaltyFired) {
      if (isDark) {
        for (final p in userPath) {
          if (toRect().contains(Offset(p.x, p.y))) {
            // _penaltyFired = true;
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
      // return;
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
