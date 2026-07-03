import 'package:figureout/src/functions/UserRemovable.dart';
import 'package:figureout/src/functions/blink_alpha_target.dart';
import 'package:figureout/src/routes/OneSecondGame.dart';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import '../effect/AttackExplosionEffect.dart';
import '../effect/EncircleSliceEffect.dart';
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

  // 이중 트리거 방지
  bool _isDisappearing = false;

  final Paint _overlapOutlinePaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.0;

  void setBlinkAlpha(double alpha) {
    if (_isDisappearing) return;
    _blinkAlpha = alpha.clamp(0.0, 1.0);
    _hpTextComponent?.textRenderer = TextPaint(
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black.withValues(alpha: _blinkAlpha)),
    );
  }

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

  final Color baseColor = const Color(0xFFAE7F2D);
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
    // z-order(priority)는 스폰 시 생성 순서 기반으로 설정된다. (크기 무관)
    await super.onLoad();

    _sprite = await Sprite.load('shapes/Triangle_3x.png', images: _images);
    _outlinePath = _buildTrianglePath(size.toSize());
    _outlineLength =
        _outlinePath.computeMetrics().fold(0.0, (sum, m) => sum + m.length);
    _wobblePath = ShapePathUtils.wobble(_outlinePath, amplitude: size.x * 0.009);

    if (!isDark && energy >= 1) {
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
  // 유저 제거 트리거 — EncircleSliceEffect 스폰 후 즉시 제거
  // ==========================================================
  void triggerDisappear() {
    if (_isDisappearing) return;

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

    _isDisappearing = true;
    _hpTextComponent?.removeFromParent();
    _hpTextComponent = null;
    wasRemovedByUser = true;

    final parentGame = findGame();
    if (parentGame is OneSecondGame) {
      parentGame.blinkingMap.remove(this);
    }

    // 삼각형 centroid = anchor(0.5, 0.62) = position(world)
    const svgW = 96.0, svgH = 86.0;
    final pivotX = size.x * (48.0 + 2.1 + 93.9) / (3 * svgW);  // size.x / 2
    final pivotY = size.y * (3.5 + 78.5 + 78.5) / (3 * svgH);  // size.y * 0.622

    parent?.add(
      EncircleSliceEffect(
        basePath: _buildExplosionTrianglePath(),
        color: const Color(0xFFF2AC32),
        position: Vector2(position.x - 2.0, position.y),
        size: size.clone(),
        pivot: Offset(pivotX, pivotY),
        initialAngle: angle,
      ),
    );

    removeFromParent();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isPaused) return;

    // 공격 타이머 → 즉시 자폭 (AttackExplosionEffect)
    if ((attackTime ?? 0) <= 0) return;

    _attackElapsed += dt;

    if (!_attackDone && _attackElapsed >= attackTime!) {
      _attackDone = true;

      if (!_penaltyFired) {
        _penaltyFired = true;
        onExplode?.call();
      }

      wasRemovedByUser = false;

      const svgW = 96.0, svgH = 86.0;
      final pivotX = size.x * (48.0 + 2.1 + 93.9) / (3 * svgW);
      final pivotY = size.y * (3.5 + 78.5 + 78.5) / (3 * svgH);

      parent?.add(
        AttackExplosionEffect(
          basePath: _buildExplosionTrianglePath(),
          position: Vector2(position.x - 2.0, position.y),
          size: size.clone(),
          color: const Color(0xFFF2AC32),
          pivot: Offset(pivotX, pivotY),
          maxScale: 4.5,
          ringSpacing: 0.45,
          maxRings: 9,
          strokeMaxWidth: 0.9,
        ),
      );

      removeFromParent();
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

  @override
  void render(Canvas canvas) {
    final alpha = _blinkAlpha.clamp(0.0, 1.0);

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

    if ((attackTime ?? 0) > 0 && !_attackDone) {
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
    final inset = -3.0;
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
