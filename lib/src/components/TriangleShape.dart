import 'dart:math' as math;

import 'package:figureout/src/functions/UserRemovable.dart';
import 'package:figureout/src/functions/blink_alpha_target.dart';
import 'package:figureout/src/routes/OneSecondGame.dart';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../effect/AttackExplosionEffect.dart';
import '../functions/OverlapHighlightable.dart';
import 'shape_path_utils.dart';

class TriangleShape extends PositionComponent with TapCallbacks, UserRemovable, OverlapHighlightable, BlinkAlphaTarget {
  static final _images = Images(prefix: 'assets/');

  int energy = 0;
  TextComponent? _hpTextComponent;

  final bool isDark;
  final VoidCallback? onForbiddenTouch;
  final double? attackTime;
  final VoidCallback? onExplode;
  final int? order;
  final BlendMode blendMode;

  double _attackElapsed = 0.0;
  bool _attackDone = false;
  bool _penaltyFired = false; 
  bool isPaused = false;

  double _blinkAlpha = 1.0;
  double _shapeOpacity = 1.0;

  final Paint _overlapOutlinePaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;

  void setBlinkAlpha(double alpha){
    if (_isDisappearing) return;

    _blinkAlpha = alpha.clamp(0.0, 1.0);

    _hpTextComponent?.textRenderer = TextPaint(
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black.withValues(alpha: _blinkAlpha)),
    );
  }

  // ===== 사라짐 애니메이션 상태 (유저 제거용) =====
  bool _isDisappearing = false;
  double _disappearTime = 0.0;

  final double _disappearDuration = 0.8;

  static const double _shrinkEndT = 0.85;
  static const double _holdEndT = 0.97;
  static const double _minScale = 0.06;

  late double _startAngle;
  late Vector2 _startScale;

  double _baseRotationSpeed = 0.0;
  double _rotDir = 1.0;

  late Sprite _sprite;
  late Path _outlinePath;
  late Path _wobblePath;
  late double _outlineLength;

  final Paint _attackPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFFF2AC32);

  final Color baseColor = const Color(0xFFF2AC32);
  final Color dangerColor = const Color(0xFFEE0505);

  TriangleShape(
    Vector2 position,
    this.energy, {
    this.isDark = false,
    this.onForbiddenTouch,
    this.attackTime,
    this.onExplode,
    Vector2? customSize,
    this.order,
    this.blendMode = BlendMode.srcOver,
  }) : super(
          position: position,
          size: customSize ?? Vector2.all(70),
          anchor: Anchor(0.5, 0.62),
        );

  @override
  Future<void> onLoad() async {
    priority = 100 + (1000 - size.x).toInt();
    await super.onLoad();

    _sprite = await Sprite.load('shapes/Triangle_3x.png', images: _images);
    _outlinePath = _buildTrianglePath(size.toSize());
    _outlineLength =
        _outlinePath.computeMetrics().fold(0.0, (sum, m) => sum + m.length);
    _wobblePath = ShapePathUtils.wobble(_outlinePath, amplitude: size.x * 0.009);

    if (!isDark && energy >= 1) {
      // centroid of SVG triangle (top:3.5, bot:78.5 on 86h grid) = y * (3.5+78.5+78.5)/(86*3)
      _hpTextComponent = TextComponent(
        text: energy.toString(),
        anchor: Anchor.center,
        position: Vector2(size.x / 2, size.y * (3.5 + 78.5 * 2) / (86 * 3)),
        priority: 999,
        textRenderer: TextPaint(
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      );
      add(_hpTextComponent!);
    }
  }

  // ==========================================================
  // 유저 제거 트리거
  // ==========================================================
  void triggerDisappear() {
    if (_isDisappearing) return;

    // 에너지가 남아있으면 1 깎고 리턴 (아직 살아있음)
    if (energy > 1) {
      energy--;
      if (energy >= 1) {
        _hpTextComponent?.text = energy.toString();
      } else {
        _hpTextComponent?.removeFromParent();
        _hpTextComponent = null;
      }
      return;
    }

    _hpTextComponent?.removeFromParent();
    _hpTextComponent = null;
    _isDisappearing = true;
    wasRemovedByUser = true;

    final parentGame = findGame();
    if (parentGame is OneSecondGame) {
      parentGame.blinkingMap.remove(this);
    }

    _disappearTime = 0.0;
    _startScale = scale.clone();
    _startAngle = angle;

    _rotDir = math.Random().nextBool() ? 1.0 : -1.0;
    _baseRotationSpeed = math.pi * 2.2;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isPaused) return;

    // ======================================================
    // 유저 제거 애니메이션
    // ======================================================
    if (_isDisappearing) {
      _disappearTime += dt;
      final t = (_disappearTime / _disappearDuration).clamp(0.0, 1.0);

      final accel = 1.0 + (t * t) * 2.2;
      angle += (_baseRotationSpeed * accel * _rotDir) * dt;

      if (t <= _shrinkEndT) {
        final localT = (t / _shrinkEndT).clamp(0.0, 1.0);
        final eased = Curves.easeInCubic.transform(localT);
        final s = 1.0 - (1.0 - _minScale) * eased;
        scale = _startScale * s;
        _shapeOpacity = 1.0;
      } else if (t <= _holdEndT) {
        scale = _startScale * _minScale;
        _shapeOpacity = 1.0;
      } else {
        scale = _startScale * _minScale;
        final localT =
            ((t - _holdEndT) / (1.0 - _holdEndT)).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(localT);
        _shapeOpacity = 1.0 - eased;
      }

      if (t >= 1.0) {
        removeFromParent();
      }
      return;
    }

    // ======================================================
    // 공격 타이머 → 즉시 자폭
    // ======================================================
    if ((attackTime ?? 0) <= 0) return;

    _attackElapsed += dt;

    if (!_attackDone && _attackElapsed >= attackTime!) {
      _attackDone = true;

      if (!_penaltyFired) {
        _penaltyFired = true;
        onExplode?.call(); // 시간 패널티
      }

      // 타이머 자폭은 유저 제거 아님
      wasRemovedByUser = false;

      parent?.add(
        AttackExplosionEffect(
          basePath: _buildExplosionTrianglePath(),   // 삼각형 외곽 그대로 사용
          position: position.clone(),
          size: size.clone(),
          color: const Color(0xFFF2AC32),
        ),
      );

      removeFromParent();
      return;
    }

  }

  bool get _attackTimeHalfLeft {
    if ((attackTime ?? 0) <= 0) return false;
    final ratio =
        ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);
    return ratio <= 0.2;
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    final pts = [
      Vector2(size.x * (48.0 / 96.0), size.y * (3.5 / 86.0)),
      Vector2(size.x * (2.1 / 96.0),  size.y * (78.5 / 86.0)),
      Vector2(size.x * (93.9 / 96.0), size.y * (78.5 / 86.0)),
    ];
    return isPointInPolygon(point, pts);
  }

  @override
  static const double _borderHalo = 0.05;

  void render(Canvas canvas) {
    final alpha = (_blinkAlpha * _shapeOpacity).clamp(0.0, 1.0);

    _sprite.render(
      canvas,
      position: Vector2(-size.x * _borderHalo / 2, -size.y * _borderHalo / 2),
      size: size * (1 + _borderHalo),
      overridePaint: Paint()
        ..colorFilter = ColorFilter.mode(
          Color.fromARGB((alpha * 255).round(), 0xE4, 0xE0, 0xD3),
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
                0, 0, 0, alpha, 0,
              ]))
          : (Paint()
              ..blendMode = blendMode
              ..colorFilter = ColorFilter.mode(
                Color.fromARGB((alpha * 255).round(), 255, 255, 255),
                BlendMode.modulate,
              )),
    );

    if (!_attackDone && _attackTimeHalfLeft) {
      canvas.drawPath(
        _wobblePath,
        Paint()
          ..color = dangerColor.withValues(alpha: alpha * 0.5)
          ..style = PaintingStyle.fill
          ..blendMode = BlendMode.srcATop,
      );
    }

    super.render(canvas);

    if ((attackTime ?? 0) > 0 && !_attackDone && !_isDisappearing) {
      final ratio =
          ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);
      final drawLen = _outlineLength * ratio;
      _attackPaint.color =
          (ratio <= 0.2 ? dangerColor : baseColor)
              .withValues(alpha: _blinkAlpha);
      final partial = ShapePathUtils.extractPartial(_outlinePath, drawLen);
      canvas.drawPath(partial, _attackPaint);
    }
  }

  Path _buildTrianglePath(Size s) {
    final inset = _attackPaint.strokeWidth / 2;
    // SVG viewBox 96×86 기준 삼각형 꼭짓점
    // top: (48, 3.5), bottomLeft: (2.1, 78.5), bottomRight: (93.9, 78.5)
    const double svgW = 96, svgH = 86;

    final topX   = s.width  * (48.0  / svgW);
    final topY   = s.height * (3.5   / svgH) + inset;
    final botY   = s.height * (78.5  / svgH) - inset;
    final leftX  = s.width  * (2.1   / svgW) + inset;
    final rightX = s.width  * (93.9  / svgW) - inset;

    return Path()
      ..moveTo(topX,  topY)
      ..lineTo(leftX, botY)
      ..lineTo(rightX, botY)
      ..close();
  }

  // ===== 기존 삼각형 판정 로직 유지 =====
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

  Path _buildExplosionTrianglePath() {
    final w = size.x;
    final h = size.y;
    const double svgW = 96, svgH = 86;

    return Path()
      ..moveTo(w * (48.0  / svgW), h * (3.5  / svgH))
      ..lineTo(w * (2.1   / svgW), h * (78.5 / svgH))
      ..lineTo(w * (93.9  / svgW), h * (78.5 / svgH))
      ..close();
  }
  
  @override
  void onTapDown(TapDownEvent event) {
    event.continuePropagation = false;
    if (isDark) {
      onForbiddenTouch?.call();
      return;
    }
  }
}

