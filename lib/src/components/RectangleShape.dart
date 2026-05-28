import 'dart:async';
import 'dart:math' as math;

import 'package:figureout/src/effect/FallingClippedPiece.dart';
import 'package:figureout/src/functions/UserRemovable.dart';
import 'package:figureout/src/functions/blink_alpha_target.dart';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../effect/AttackExplosionEffect.dart';
import '../config.dart';
import '../functions/OrderableShape.dart';
import '../functions/OverlapHighlightable.dart';
import 'shape_path_utils.dart';

class RectangleShape extends PositionComponent
    with TapCallbacks, UserRemovable, OverlapHighlightable, BlinkAlphaTarget
    implements OrderableShape {
  static final _images = Images(prefix: 'assets/');

  int count = 0;

  late PositionComponent _orderBadge;

  double _blinkAlpha = 1.0;
  CircleComponent? _orderBadgeBg;
  TextComponent? _orderBadgeText;
  TextComponent? _hpTextComponent;

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
  @override
  final int? order;
  final BlendMode blendMode;

  double _attackElapsed = 0.0;
  bool _attackDone = false;
  bool _penaltyFired = false;
  bool isPaused = false;

  late Sprite _sprite;
  late Path _outlinePath;
  late Path _wobblePath;
  late double _outlineLength;

  final Paint _attackPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xFF7CA6FF);

  final Color dangerColor = const Color(0xFFEE0505);
  final Color baseColor = const Color(0xFF345983);

  final Paint _overlapOutlinePaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;

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
    this.blendMode = BlendMode.srcOver,
    double angle = 0.0,
  }) : super(
          position: position,
          size: customSize ?? Vector2(40, 80),
          anchor: Anchor.center,
          angle: angle,
        );

  void setBlinkAlpha(double alpha) {
    _blinkAlpha = alpha.clamp(0.0, 1.0);

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

    if (_hpTextComponent != null) {
      _hpTextComponent!.textRenderer = TextPaint(
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black.withValues(alpha: _blinkAlpha),
        ),
      );
    }
  }

  @override
  Future<void> onLoad() async {
    priority = 100 + (1000 - size.x).toInt();
    await super.onLoad();

    if (order != null) {
      _addOrderBadge(order!);
    }

    if (!isDark && count >= 1) {
      _hpTextComponent = TextComponent(
        text: count.toString(),
        anchor: Anchor.center,
        position: size / 2,
        priority: 999,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      );
      add(_hpTextComponent!);
    }

    _sprite = await Sprite.load('shapes/Rectangle_3x.png', images: _images);
    _outlinePath = _buildRectPath(size.toSize());
    _outlineLength =
        _outlinePath.computeMetrics().fold(0.0, (sum, m) => sum + m.length);
    _wobblePath = ShapePathUtils.wobble(_outlinePath, amplitude: size.x * 0.009);
  }

  Path _buildRectPath(Size s) {
    final inset = (_attackPaint.strokeWidth / 2) - 1.0;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      s.width - inset * 2,
      s.height - inset * 2,
    );
    final shortestSide = s.width < s.height ? s.width : s.height;
    final radius = Radius.circular((shortestSide * 0.08).clamp(4.0, 8.0));

    return Path()..addRRect(RRect.fromRectAndRadius(rect, radius));
  }

  @override
  void update(double dt) {
    super.update(dt);

    if ((attackTime ?? 0) <= 0) return;
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
  }

  bool get _attackTimeHalfLeft {
    if ((attackTime ?? 0) <= 0) return false;
    final ratio =
        ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);
    return ratio <= 0.2;
  }

  @override
  void render(Canvas canvas) {
    _renderRectangleShape(canvas);

    super.render(canvas);

    // perimeter timer
    if ((attackTime ?? 0) > 0 && !_attackDone) {
      final ratio =
          ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);
      final drawLen = _outlineLength * ratio;

      _attackPaint.color = (ratio <= 0.2 ? dangerColor : baseColor)
          .withValues(alpha: _blinkAlpha);

      final partial = ShapePathUtils.extractPartial(_outlinePath, drawLen);
      canvas.drawPath(partial, _attackPaint);
    }

    _renderSliceLine(canvas);
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    const inset = 4.0;
    return point.x >= inset && point.x <= size.x - inset &&
           point.y >= inset && point.y <= size.y - inset;
  }

  static const double _borderHalo = 0.08;

  void _renderRectangleShape(Canvas canvas) {
    _sprite.render(
      canvas,
      position: Vector2(-size.x * _borderHalo / 2, -size.y * _borderHalo / 2),
      size: size * (1 + _borderHalo),
      overridePaint: Paint()
        ..colorFilter = ColorFilter.mode(
          Color.fromARGB((_blinkAlpha * 255).round(), 0xE4, 0xE0, 0xD3),
          BlendMode.srcIn,
        ),
    );

    _sprite.render(
      canvas,
      size: size,
      overridePaint: isDark
          ? (Paint()
              ..blendMode = blendMode
              ..colorFilter = ColorFilter.matrix([
                0.33, 0.33, 0.33, 0, 0,
                0.33, 0.33, 0.33, 0, 0,
                0.33, 0.33, 0.33, 0, 0,
                0, 0, 0, _blinkAlpha, 0,
              ]))
          : (Paint()
              ..blendMode = blendMode
              ..colorFilter = ColorFilter.mode(
                Color.fromARGB((_blinkAlpha * 255).round(), 255, 255, 255),
                BlendMode.modulate,
              )),
    );

    if (!_attackDone && _attackTimeHalfLeft) {
      canvas.drawPath(
        _wobblePath,
        Paint()
          ..color = dangerColor.withValues(alpha: _blinkAlpha * 0.5)
          ..style = PaintingStyle.fill
          ..blendMode = BlendMode.srcATop,
      );
    }
  }


  void _renderSliceLine(Canvas canvas) {
    if (sliceStart != null && sliceEnd != null) {
      final slicePaint = Paint()
        ..color = Colors.black.withValues(alpha: _blinkAlpha)
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
    event.continuePropagation = false;
    if (isDark) {
      onForbiddenTouch?.call();
    }
  }

  void touchAtPoint(List<Vector2> userPath) {
    debugPrint("=== RUNNING TOUCHATPOINT ==============");
    if (userPath.length < 2 || isSliced) return;

    // ===== A 좌표계 문제 확인 =====
    final r = toRect();
    debugPrint("rectBounds: $r");
    debugPrint("path first=${userPath.first}, last=${userPath.last}");
    debugPrint(
      "firstInside=${r.contains(Offset(userPath.first.x, userPath.first.y))}",
    );
    debugPrint(
      "lastInside=${r.contains(Offset(userPath.last.x, userPath.last.y))}",
    );

    // ===== B 교차점이 몇 개인지 =====
    final a = userPath.first;
    final b = userPath.last;
    final ints = getLineRectangleIntersections(a, b, r);
    debugPrint("line intersections=${ints.length}  $ints");

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
    debugPrint("=== slice check : $isSliced ============");
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
        sourceSize: size.clone(),
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
    debugPrint("=== VALID MOVE ==============");
    count--;

    if (count >= 1) {
      _hpTextComponent?.text = count.toString();
    } else {
      _hpTextComponent?.removeFromParent();
      _hpTextComponent = null;
    }

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


