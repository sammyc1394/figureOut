import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:figureout/src/components/FallingClippedPiece.dart';
import 'package:figureout/src/functions/UserRemovable.dart';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flame_svg/svg_component.dart';
import 'package:flutter/material.dart';

class RectangleShape extends PositionComponent with TapCallbacks, UserRemovable {
  int energy = 0;
  late final SvgComponent svg;
  late final SpriteComponent _png;

  bool isSliced = false;
  Vector2? sliceStart;
  Vector2? sliceEnd;

  final bool isDark;
  final VoidCallback? onForbiddenTouch;

  final double? attackTime;
  final VoidCallback? onExplode;
  final int? order;

  double _attackElapsed = 0.0;
  bool _attackDone = false;
  bool _penaltyFired = false; 
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

  late final Svg _sourceSvg;

  RectangleShape(
    Vector2 position,
    this.energy, {
    this.isDark = false,
    this.onForbiddenTouch,
    this.attackTime,
    this.onExplode,
    Vector2? customSize,
    this.order,
  }) : super(
          position: position,
          size: customSize ?? Vector2(40, 80),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    priority = 100 + (1000 - size.x).toInt();
    await super.onLoad();

    final String asset = isDark ? 'DarkRectangle.svg' : 'Rectangle 3.svg';

    _sourceSvg = await Svg.load(asset);

    svg = SvgComponent(
      svg: _sourceSvg,
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

    // attackTime 있으면 PNG로 시작
    if ((attackTime ?? 0) > 0) {
      svg.opacity = 0;
      _png.opacity = 1;
    }

    _outlinePath = _buildRectPath(size.toSize());
    _outlineLength =
        _outlinePath.computeMetrics().fold(0.0, (sum, m) => sum + m.length);
  }

  Path _buildRectPath(Size s) {
    final inset = (_attackPaint.strokeWidth / 2) - 1.0;
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

    // ------------------------------------------------------------
    // 타이머 종료 시 자폭
    // ------------------------------------------------------------
    if (!_attackDone && _attackElapsed >= attackTime!) {
      _attackDone = true;

      if (!_penaltyFired) {
        _penaltyFired = true;
        onExplode?.call(); // 시간 패널티 유지
      }

      // 타이머 자폭으로 제거됨을 명확히
      wasRemovedByUser = false;

      // 즉시 제거
      removeFromParent();
      return;
    }

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

    // perimeter timer
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
    if (sliceStart != null && sliceEnd != null) {
      final slicePaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      final toLocal = absoluteCenter - size / 2;

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

    final slicePoints = getSlicePoints(userPath);
    if (slicePoints == null) return;

    if (isDark) {
      // 다크는 잘리지 않음 + 패널티
      for (final p in userPath) {
        if (toRect().contains(Offset(p.x, p.y))) {
          onForbiddenTouch?.call();
          break;
        }
      }
      return;
    }

    sliceStart = slicePoints.start;
    sliceEnd = slicePoints.end;
    isSliced = true;

    Future.delayed(const Duration(milliseconds: 50), () {
      if (!isMounted) return;

      final toLocal = absoluteCenter - size / 2;
      final localA = sliceStart! - toLocal; // 0..size 로컬
      final localB = sliceEnd! - toLocal;

      final paths = _splitRectToTwoClipPaths(localA, localB, size);
      if (paths == null) {
        wasRemovedByUser = true;
        removeFromParent();
        return;
      }

      final rand = math.Random();

      final baseVel = Vector2(
        (rand.nextDouble() * 500) - 250,
        -600 - rand.nextDouble() * 250,
      );

      final worldCenter = position.clone();

      // 각 조각의 bounds 기준으로 "조각 크기"와 "오프셋" 계산
      final bounds1 = paths.item1.getBounds();
      final bounds2 = paths.item2.getBounds();

      // 조각은 "원본 SVG를 clipPath로 잘라서" 떨어지게
      final piece1 = FallingClippedPiece(
        position: worldCenter +
            Vector2(
              bounds1.center.dx - size.x / 2,
              bounds1.center.dy - size.y / 2,
            ),
        sizePx: Vector2(bounds1.width, bounds1.height),
        sourceSvg: _sourceSvg,
        sourceSize: size.clone(), // 원본 SVG 렌더 사이즈
        clipPath: paths.item1,
        clipOffset: Vector2(bounds1.left, bounds1.top),
        velocity: baseVel.clone(),
        angularVelocity: rand.nextDouble() * 6 * (rand.nextBool() ? 1 : -1),
        fillColor: baseColor,
      );

      final piece2 = FallingClippedPiece(
        position: worldCenter +
            Vector2(
              bounds2.center.dx - size.x / 2,
              bounds2.center.dy - size.y / 2,
            ),
        sizePx: Vector2(bounds2.width, bounds2.height),
        sourceSvg: _sourceSvg,
        sourceSize: size.clone(),
        clipPath: paths.item2,
        clipOffset: Vector2(bounds2.left, bounds2.top),
        velocity: Vector2(-baseVel.x, baseVel.y),
        angularVelocity: rand.nextDouble() * 6 * (rand.nextBool() ? 1 : -1),
        fillColor: baseColor,
      );

      parent?.add(piece1);
      parent?.add(piece2);

      wasRemovedByUser = true;
      removeFromParent();
    });
  }

  ({Path item1, Path item2})? _splitRectToTwoClipPaths(
    Vector2 a,
    Vector2 b,
    Vector2 rectSize,
  ) {
    if (a.distanceTo(b) < 0.001) return null;

    final corners = <Vector2>[
      Vector2(0, 0),
      Vector2(rectSize.x, 0),
      Vector2(rectSize.x, rectSize.y),
      Vector2(0, rectSize.y),
    ];

    double side(Vector2 p) {
      final ab = b - a;
      final ap = p - a;
      return ab.x * ap.y - ab.y * ap.x;
    }

    final groupPos = <Vector2>[];
    final groupNeg = <Vector2>[];

    for (final c in corners) {
      final s = side(c);
      if (s >= 0) {
        groupPos.add(c);
      } else {
        groupNeg.add(c);
      }
    }

    groupPos.add(a);
    groupPos.add(b);
    groupNeg.add(a);
    groupNeg.add(b);

    List<Vector2> uniq(List<Vector2> pts) {
      final out = <Vector2>[];
      for (final p in pts) {
        final exist = out.any((q) => (q - p).length < 0.5);
        if (!exist) out.add(p);
      }
      return out;
    }

    List<Vector2> sortByAngle(List<Vector2> pts) {
      final u = uniq(pts);
      if (u.length < 3) return u;

      final centroid =
          u.fold(Vector2.zero(), (s, v) => s + v) / u.length.toDouble();

      u.sort((p, q) {
        final ap = math.atan2(p.y - centroid.y, p.x - centroid.x);
        final aq = math.atan2(q.y - centroid.y, q.x - centroid.x);
        return ap.compareTo(aq);
      });

      return u;
    }

    final p1 = sortByAngle(groupPos);
    final p2 = sortByAngle(groupNeg);

    if (p1.length < 3 || p2.length < 3) return null;

    Path build(List<Vector2> pts) {
      final path = Path()..moveTo(pts[0].x, pts[0].y);
      for (int i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].x, pts[i].y);
      }
      path.close();
      return path;
    }

    final path1 = build(p1);
    final path2 = build(p2);

    return (item1: path1, item2: path2);
  }

  SlicePoints? getSlicePoints(List<Vector2> userPath) {
    final rectBounds = toRect();
    final intersectionPoints = <Vector2>[];

    for (int i = 0; i < userPath.length - 1; i++) {
      final start = userPath[i];
      final end = userPath[i + 1];

      final intersections = getLineRectangleIntersections(
        start,
        end,
        rectBounds,
      );
      intersectionPoints.addAll(intersections);
    }

    if (intersectionPoints.length >= 2) {
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
    final intersections = <Vector2>[];

    final topIntersection = getLineIntersection(
      start,
      end,
      Vector2(rect.left, rect.top),
      Vector2(rect.right, rect.top),
    );
    if (topIntersection != null) intersections.add(topIntersection);

    final bottomIntersection = getLineIntersection(
      start,
      end,
      Vector2(rect.left, rect.bottom),
      Vector2(rect.right, rect.bottom),
    );
    if (bottomIntersection != null) intersections.add(bottomIntersection);

    final leftIntersection = getLineIntersection(
      start,
      end,
      Vector2(rect.left, rect.top),
      Vector2(rect.left, rect.bottom),
    );
    if (leftIntersection != null) intersections.add(leftIntersection);

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
    final denom =
        (p1.x - p2.x) * (p3.y - p4.y) - (p1.y - p2.y) * (p3.x - p4.x);
    if (denom == 0) return null;

    final t = ((p1.x - p3.x) * (p3.y - p4.y) -
            (p1.y - p3.y) * (p3.x - p4.x)) /
        denom;
    final u = -((p1.x - p2.x) * (p1.y - p3.y) -
            (p1.y - p2.y) * (p1.x - p3.x)) /
        denom;

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