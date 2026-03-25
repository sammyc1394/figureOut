import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:figureout/src/effect/FallingClippedPiece.dart';
import 'package:figureout/src/functions/UserRemovable.dart';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';

import '../effect/AttackExplosionEffect.dart';

import '../config.dart';
import '../functions/OrderableShape.dart';

class RectangleShape extends PositionComponent
    with TapCallbacks, UserRemovable
    implements OrderableShape {
  int count = 0;

  // Base rectangle is rendered as either:
  // 1) single stretched PNG for narrow width
  // 2) 3-slice PNG for wider width
  final List<SpriteComponent> _baseSlices = [];

  // Attack rectangle image (kept as-is for now).
  late final SpriteComponent _pngAttack;

  late PositionComponent _orderBadge;

  double _blinkAlpha = 1.0;
  CircleComponent? _orderBadgeBg;
  TextComponent? _orderBadgeText;

  bool isSliced = false;
  Vector2? sliceStart;
  Vector2? sliceEnd;

  final bool isDark;
  final VoidCallback? onForbiddenTouch;
  final bool isAttackable;
  final bool Function(OrderableShape shape)? onInteracted;
  final void Function()? onRemoved;

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

  // Keep SVG source only for sliced-piece effect.
  late final Svg _sourceSvg;

  RectangleShape(
    Vector2 position,
    this.count, {
    this.isDark = false,
    this.isAttackable = false,
    this.onForbiddenTouch,
    this.attackTime,
    this.onExplode,
    Vector2? customSize,
    this.order,
    this.onRemoved,
    this.onInteracted,
  }) : super(
          position: position,
          size: customSize ?? Vector2(40, 80),
          anchor: Anchor.center,
        );

  bool get _usesPngLayer => (attackTime ?? 0) > 0;

  Paint _makeCrispPaint() {
    return Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none;
  }

  void _setBaseSlicesOpacity(double value) {
    for (final slice in _baseSlices) {
      slice.opacity = value;
    }
  }

  void setBlinkAlpha(double alpha) {
    _blinkAlpha = alpha.clamp(0.0, 1.0);

    if (_usesPngLayer) {
      _setBaseSlicesOpacity(0.0);
      _pngAttack.opacity = _blinkAlpha;
    } else {
      _setBaseSlicesOpacity(_blinkAlpha);
      _pngAttack.opacity = 0.0;
    }

    if (_orderBadgeBg != null) {
      _orderBadgeBg!.paint.color =
          const Color(0xFF4680FF).withValues(alpha: _blinkAlpha);
    }

    if (_orderBadgeText != null) {
      _orderBadgeText!.textRenderer = TextPaint(
        style: TextStyle(
          fontSize: 18,
          fontFamily: appFontFamily,
          fontWeight: FontWeight.bold,
          color: Colors.white.withValues(alpha: _blinkAlpha),
        ),
      );
    }
  }

  @override
  Future<void> onLoad() async {
    priority = 100 + (1000 - size.x).toInt();
    await super.onLoad();

    // Keep SVG for slice piece effect.
    final String svgAsset =
        isDark ? 'Rectangle_dark.svg' : 'Rectangle_basic.svg';
    _sourceSvg = await Svg.load(svgAsset);

    final images = Images(prefix: 'assets/');

    // Base rectangle PNG with border/art.
    final String basePngAsset =
        isDark ? 'Rectangle_dark.png' : 'Rectangle_basic.png';
    final imgBase = await images.load(basePngAsset);

    // Pixel-align size to reduce border tearing.
    final double targetWidth = size.x.roundToDouble();
    final double targetHeight = size.y.roundToDouble();

    // Base slice setup
    const double baseEdgeWidth = 12.0;

    // If width is too narrow, 3-slice looks broken.
    // In that case, use a single stretched sprite instead.
    const double singleSpriteThreshold = 56.0;

    if (targetWidth < singleSpriteThreshold) {
      final single = SpriteComponent(
        sprite: Sprite(imgBase),
        size: Vector2(targetWidth, targetHeight),
        anchor: Anchor.topLeft,
        position: Vector2.zero(),
        paint: _makeCrispPaint(),
      );

      _baseSlices.add(single);
      add(single);
    } else {
      final double edgeWidth = baseEdgeWidth;
      final double centerWidth =
          math.max(0.0, targetWidth - edgeWidth * 2).roundToDouble();

      // LEFT slice
      final left = SpriteComponent(
        sprite: Sprite(
          imgBase,
          srcPosition: Vector2.zero(),
          srcSize: Vector2(edgeWidth, imgBase.height.toDouble()),
        ),
        size: Vector2(edgeWidth, targetHeight),
        anchor: Anchor.topLeft,
        position: Vector2(0.0, 0.0),
        paint: _makeCrispPaint(),
      );

      // CENTER slice
      final center = SpriteComponent(
        sprite: Sprite(
          imgBase,
          srcPosition: Vector2(edgeWidth, 0),
          srcSize: Vector2(
            imgBase.width.toDouble() - edgeWidth * 2,
            imgBase.height.toDouble(),
          ),
        ),
        size: Vector2(centerWidth, targetHeight),
        anchor: Anchor.topLeft,
        position: Vector2(edgeWidth.roundToDouble(), 0.0),
        paint: _makeCrispPaint(),
      );

      // RIGHT slice
      final right = SpriteComponent(
        sprite: Sprite(
          imgBase,
          srcPosition: Vector2(imgBase.width.toDouble() - edgeWidth, 0),
          srcSize: Vector2(edgeWidth, imgBase.height.toDouble()),
        ),
        size: Vector2(edgeWidth, targetHeight),
        anchor: Anchor.topLeft,
        position: Vector2((targetWidth - edgeWidth).roundToDouble(), 0.0),
        paint: _makeCrispPaint(),
      );

      _baseSlices.addAll([left, center, right]);
      add(left);
      add(center);
      add(right);
    }

    // Attack PNG stays as current implementation.
    final imgAttack = await images.load('shapes/Rectangle.png');
    _pngAttack = SpriteComponent(
      sprite: Sprite(imgAttack),
      size: size,
      anchor: Anchor.center,
      position: size / 2,
      paint: _makeCrispPaint(),
    )..opacity = 0.0;
    add(_pngAttack);

    if (order != null) {
      _addOrderBadge(order!);
    }

    if (_usesPngLayer) {
      _setBaseSlicesOpacity(0.0);
      _pngAttack.opacity = 1.0;
    } else {
      _setBaseSlicesOpacity(1.0);
      _pngAttack.opacity = 0.0;
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
    if (isDark) return;
    if (!isAttackable) return;

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

      parent?.add(
        AttackExplosionEffect(
          basePath: _buildExplosionRectanglePath(),
          position: position.clone(),
          size: size.clone(),
          color: const Color(0xFF4680FF),
        ),
      );

      // 즉시 제거
      removeFromParent();
      return;
    }

    // ------------------------------------------------------------
    // 절반 이하 → 빨간 tint
    // ------------------------------------------------------------
    if (!_attackDone && _attackTimeHalfLeft) {
      _pngAttack.paint = Paint()
        ..isAntiAlias = false
        ..filterQuality = FilterQuality.none
        ..colorFilter = ColorFilter.mode(
          dangerColor,
          BlendMode.srcIn,
        );
    } else {
      _pngAttack.paint = _makeCrispPaint();
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
      _attackPaint.color =
          _attackPaint.color.withAlpha((_blinkAlpha * 255).toInt());

      final partial = _extractPartialPath(_outlinePath, drawLen);
      canvas.drawPath(partial, _attackPaint);
    }

    _renderSliceLine(canvas);
  }

  void _renderRectangleShape(Canvas canvas) {
    if (!isDark && count > 1) {
      _drawText(canvas, count.toString());
    }
  }

  void _drawText(Canvas canvas, String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF4680FF)
              .withAlpha((_blinkAlpha * 255).toInt()),
          fontSize: 20,
        ),
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
        ..color = Colors.black.withAlpha((_blinkAlpha * 255).toInt())
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
    print("=== RUNNING TOUCHATPOINT ==============");
    if (userPath.length < 2 || isSliced) return;

    // ===== A 좌표계 문제 확인 =====
    final r = toRect();
    print("rectBounds: $r");
    print("path first=${userPath.first}, last=${userPath.last}");
    print(
      "firstInside=${r.contains(Offset(userPath.first.x, userPath.first.y))}",
    );
    print(
      "lastInside=${r.contains(Offset(userPath.last.x, userPath.last.y))}",
    );

    // ===== B 교차점이 몇 개인지 =====
    final a = userPath.first;
    final b = userPath.last;
    final ints = getLineRectangleIntersections(a, b, r);
    print("line intersections=${ints.length}  $ints");

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
    isSliced = onInteracted?.call(this) ?? false;
    print("=== slice check : $isSliced ============");
    if (isSliced) {
      applyValidInteraction();
    } else {
      onForbiddenTouch?.call();
      return;
    }

    // ------------------------------------------------------------
    // Rectangle dead
    // ------------------------------------------------------------
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

    if (count <= 0) {
      // ------------------------------------------------------------
      // Rectangle disappear effect
      // ------------------------------------------------------------
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
      if (order != null) onRemoved?.call();
      removeFromParent();
    }
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

    if (denom.abs() < 0.000001) return null;

    final t = ((p1.x - p3.x) * (p3.y - p4.y) -
            (p1.y - p3.y) * (p3.x - p4.x)) /
        denom;

    final u = -((p1.x - p2.x) * (p1.y - p3.y) -
            (p1.y - p2.y) * (p1.x - p3.x)) /
        denom;

    const eps = 0.01;

    if (t >= -eps && t <= 1 + eps && u >= -eps && u <= 1 + eps) {
      return Vector2(
        p1.x + t * (p2.x - p1.x),
        p1.y + t * (p2.y - p1.y),
      );
    }

    return null;
  }

  void _addOrderBadge(int order) {
    const badgeSizeRatio = 0.32;
    final badgeSize = size.y * badgeSizeRatio;

    _orderBadge = PositionComponent(
      size: Vector2.all(badgeSize),
      anchor: Anchor.bottomRight,
      position: Vector2(
        badgeSize * 0.7,
        badgeSize * 0.7,
      ),
    );

    final center = _orderBadge.size / 2;

    final bg = CircleComponent(
      radius: badgeSize / 2,
      paint: Paint()..color = const Color(0xFF4680FF),
      anchor: Anchor.center,
      position: center,
    );

    final text = TextComponent(
      text: order.toString(),
      anchor: Anchor.center,
      position: center,
      textRenderer: TextPaint(
        style: TextStyle(
          fontSize: 18,
          fontFamily: appFontFamily,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );

    _orderBadge.add(bg);
    _orderBadge.add(text);
    add(_orderBadge);

    _orderBadgeBg = bg;
    _orderBadgeText = text;
  }

  void applyValidInteraction() {
    print("=== VALID MOVE ==============");
    count--;

    Future.delayed(const Duration(milliseconds: 1), () {
      isSliced = false;
      sliceStart = null;
      sliceEnd = null;
    });
    return;
  }

  Path _buildExplosionRectanglePath() {
    final w = size.x;
    final h = size.y;

    return Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
  }
}

class SlicePoints {
  final Vector2 start;
  final Vector2 end;

  SlicePoints({required this.start, required this.end});
}