import 'dart:math' as math;
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

  // ===== 사라짐 애니메이션 상태 =====
  bool _isDisappearing = false;
  double _disappearTime = 0.0;

  // 단계형 연출을 위해 duration 유지 + 구간 분할
  final double _disappearDuration = 0.8;

  // shrink/hold/fade 타이밍 (0~1)
  static const double _shrinkEndT = 0.85;
  static const double _holdEndT = 0.97;
  static const double _minScale = 0.06; // 끝까지 0으로 안 보내고 "작게 남겨두기"

  late double _startAngle;
  late Vector2 _startScale;

  // 회전 가속용
  double _baseRotationSpeed = 0.0; // rad/sec
  double _rotDir = 1.0;

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

  TriangleShape(
    Vector2 position,
    this.energy, {
    this.isDark = false,
    this.onForbiddenTouch,
    this.attackTime,
    this.onExplode,
  }) : super(
          position: position,
          size: Vector2.all(70),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final asset = isDark ? 'DarkPolygon.svg' : 'triangle.svg';
    final svgData = await Svg.load(asset);

    svg = SvgComponent(
      svg: svgData,
      size: size,
      anchor: Anchor.center,
      position: size / 2,
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

    if ((attackTime ?? 0) > 0) {
      svg.opacity = 0;
      _png.opacity = 1;
    }

    _outlinePath = _buildTrianglePath(size.toSize());
    _outlineLength = _outlinePath
        .computeMetrics()
        .fold(0.0, (sum, m) => sum + m.length);
  }

  // ==========================================================
  // 사라짐 트리거
  // ==========================================================
  void triggerDisappear() {
    if (_isDisappearing) return;

    _isDisappearing = true;
    wasRemovedByUser = true;

    _disappearTime = 0.0;
    _startScale = scale.clone();
    _startAngle = angle;

    // 회전 방향 + 기본 속도 설정 (후반 가속은 update에서)
    _rotDir = math.Random().nextBool() ? 1.0 : -1.0;
    _baseRotationSpeed = math.pi * 2.2; // 초반엔 과하지 않게 (약 1.1회전/초)
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isPaused) return;

    // ===== 사라짐 애니메이션 =====
    if (_isDisappearing) {
      _disappearTime += dt;
      final t = (_disappearTime / _disappearDuration).clamp(0.0, 1.0);

      // 1) 회전 가속 (후반으로 갈수록 더 빨라짐)
      // t^2로 가속감 주기
      final accel = 1.0 + (t * t) * 2.2; // 마지막엔 약 3.2배
      angle += (_baseRotationSpeed * accel * _rotDir) * dt;

      // 2) scale → hold → fade 구조
      if (t <= _shrinkEndT) {
        // SHRINK: 0 ~ 0.60
        final localT = (t / _shrinkEndT).clamp(0.0, 1.0);

        // 초반에 "확실히 줄어드는" 느낌: easeIn + 살짝 빠르게
        final eased = Curves.easeInCubic.transform(localT);

        final s = 1.0 - (1.0 - _minScale) * eased; // 1.0 -> _minScale
        scale = _startScale * s;

        // 이 구간은 절대 페이드 금지
        svg.opacity = 1.0;
      } else if (t <= _holdEndT) {
        // HOLD: 0.60 ~ 0.80
        scale = _startScale * _minScale;
        svg.opacity = 1.0;
      } else {
        // FADE: 0.80 ~ 1.00
        scale = _startScale * _minScale;

        final localT = ((t - _holdEndT) / (1.0 - _holdEndT)).clamp(0.0, 1.0);
        // 마지막에만 빠르게 사라지게
        final eased = Curves.easeOutCubic.transform(localT);
        svg.opacity = 1.0 - eased;
      }

      if (t >= 1.0) {
        removeFromParent();
      }
      return;
    }

    // ===== 기존 공격 타이머 로직 =====
    if ((attackTime ?? 0) <= 0) return;

    _attackElapsed += dt;

    if (!_attackDone && _attackElapsed >= attackTime!) {
      _attackDone = true;
      _png.opacity = 0;
      svg.opacity = 1;
      onExplode?.call();
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

    if ((attackTime ?? 0) > 0 && !_attackDone && !_isDisappearing) {
      final ratio =
          ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);
      final drawLen = _outlineLength * ratio;
      _attackPaint.color = ratio <= 0.2 ? dangerColor : baseColor;
      final partial = _extractPartialPath(_outlinePath, drawLen);
      canvas.drawPath(partial, _attackPaint);
    }
  }

  Path _buildTrianglePath(Size s) {
    final inset = _attackPaint.strokeWidth / 2;
    final cx = s.width / 2;
    final cy = s.height / 2;
    final r = (s.width / 2) - inset;

    return Path()
      ..moveTo(cx, cy - r)
      ..lineTo(cx - r, cy + r)
      ..lineTo(cx + r, cy + r)
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

  List<Vector2> getTriangleVertices() {
    final c = absoluteCenter;
    final hw = size.x / 2;
    final hh = size.y / 2;
    return [
      c + Vector2(0, -hh),
      c + Vector2(-hw, hh),
      c + Vector2(hw, hh),
    ];
  }

  bool isFullyEnclosedByUserPath(List<Vector2> userPath) {
    for (final v in getTriangleVertices()) {
      if (!isPointInPolygon(v, userPath)) return false;
    }
    return true;
  }

  bool isPointInPolygon(Vector2 p, List<Vector2> poly) {
    int count = 0;
    for (int i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      if (((a.y > p.y) != (b.y > p.y)) &&
          (p.x <
              (b.x - a.x) * (p.y - a.y) / (b.y - a.y + 0.0001) + a.x)) {
        count++;
      }
    }
    return count.isOdd;
  }
}
