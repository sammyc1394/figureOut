import 'dart:ui';

import 'package:figureout/src/functions/UserRemovable.dart';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';

class TriangleShape extends PositionComponent with TapCallbacks, UserRemovable {
  late final SvgComponent svg;
  int energy = 0;

  late final SpriteComponent _png;

  final bool isDark;
  final VoidCallback? onForbiddenTouch;

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
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFFFFD84D);

  final Color baseColor = const Color(0xFFFFD84D);
  final Color dangerColor = const Color(0xFFEE0505);

  TriangleShape(Vector2 position, this.energy, {
    this.isDark = false,
    this.onForbiddenTouch,
    this.attackTime,
    this.onExplode,
  })
    : super(position: position, size: Vector2.all(70), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // final svgData = await Svg.load('triangle.svg');
    final String asset = isDark ? 'DarkPolygon.svg' : 'triangle.svg';
    final svgData = await Svg.load(asset);
    svg = SvgComponent(
      svg: svgData,
      size: size,
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y / 2),
    );
    add(svg);

    final images = Images(prefix: 'assets/');
    final img = await images.load('shapes/Polygon.png');

    _png = SpriteComponent(
      sprite: Sprite(img),
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
    _png.opacity = 0;
    add(_png);

    // attackTime 있으면 PNG부터
    if ((attackTime ?? 0) > 0) {
      svg.opacity = 0;
      _png.opacity = 1;
    }

    // 삼각형 외곽 Path 생성
    _outlinePath = _buildTrianglePath(size.toSize());
    _outlineLength = _outlinePath
        .computeMetrics()
        .fold(0.0, (sum, m) => sum + m.length);
  }

  Path _buildTrianglePath(Size s) {
    final inset = _attackPaint.strokeWidth / 2;

    final cx = s.width / 2;
    final cy = s.height / 2;

    final r = (s.width / 2) - inset;

    final p1 = Offset(cx, cy - r);
    final p2 = Offset(cx - r, cy + r);
    final p3 = Offset(cx + r, cy + r);

    return Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
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

    // 타이머 종료
    if (!_attackDone && _attackElapsed >= attackTime!) {
      _attackDone = true;

      // PNG → SVG 복귀
      _png.opacity = 0;
      svg.opacity = 1;

      onExplode?.call();
    }

    // 절반 이하일 때 PNG 빨간 tint
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
  void onTapDown(TapDownEvent event) {
    onForbiddenTouch?.call();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 외곽 타이머 렌더
    if ((attackTime ?? 0) > 0 && !_attackDone) {
      final ratio =
          ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);

      final drawLen = _outlineLength * ratio;
      _attackPaint.color = ratio <= 0.2 ? dangerColor : baseColor;

      final partial = _extractPartialPath(_outlinePath, drawLen);
      canvas.drawPath(partial, _attackPaint);
    }
  }

  List<Vector2> getTriangleVertices() {
    final center = svg.absoluteCenter;
    final halfWidth = svg.size.x / 2;
    final halfHeight = svg.size.y / 2;

    final top = center + Vector2(0, -halfHeight);
    final bottomLeft = center + Vector2(-halfWidth, halfHeight);
    final bottomRight = center + Vector2(halfWidth, halfHeight);

    return [top, bottomLeft, bottomRight];
  }

  bool isFullyEnclosedByUserPath(List<Vector2> userPath) {
    // 사용자가 그린 경로가 삼각형 꼭짓점을 모두 포함하는지 검사
    for (final v in getTriangleVertices()) {
      if (!isPointInPolygon(v, userPath)) return false;
    }
    return true;
  }

  bool isPointInPolygon(Vector2 point, List<Vector2> polygon) {
    int intersectCount = 0;
    for (int i = 0; i < polygon.length; i++) {
      Vector2 a = polygon[i];
      Vector2 b = polygon[(i + 1) % polygon.length];

      if (((a.y > point.y) != (b.y > point.y)) &&
          (point.x <
              (b.x - a.x) * (point.y - a.y) / (b.y - a.y + 0.0001) + a.x)) {
        intersectCount++;
      }
    }
    return intersectCount % 2 == 1;
  }
}
