import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:figureout/src/components/user_removable.dart';
import 'package:figureout/src/components/blink_alpha_target.dart';
import 'package:figureout/src/components/attack_timer_gate.dart';
import 'dart:math' as math;

import '../effect/attack_explosion_effect.dart';
import '../effect/hexagon_burst_effect.dart';
import 'package:figureout/src/components/resizable_shape.dart';
import '../services/audio_manager.dart';
import 'shape_path_utils.dart';

enum HexagonState {
  normal,
  shrinkingBack,
  disappearing,
}

class HexagonShape extends PositionComponent
    with DragCallbacks, TapCallbacks, UserRemovable, BlinkAlphaTarget, AttackTimerGate
    implements ResizableShape {

  static final _images = Images(prefix: 'assets/');

  double dragScale = 1.0;

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

  late Sprite _sprite;
  late Path _outlinePath;
  late double _outlineLength;

  final Paint _attackPaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = const Color(0xFF398A63);

  final Color dangerColor = const Color(0xFFEE0505);
  final Color baseColor   = const Color(0xFF235A40);

  HexagonState _state = HexagonState.normal;

  /// One stretch SFX loop per pinch gesture (burst plays pop on destroy).
  bool _stretchSfxPlaying = false;

  double _disappearT = 0.0;
  double _shrinkBackT = 0.0;
  double _shrinkStartScale = 1.0;

  int _currentHp = 0;

  double _finalScale = 1.0;
  double _opacity = 1.0;

  static const double _hexAngleOffset = 0.0;
  static const double extraDisappearScale = 1.25;

  // ============================
  // BLINKING
  // ============================
  @override
  double get blinkAlpha => _blinkAlpha;
  double _blinkAlpha = 1.0;

  @override
  void setBlinkAlpha(double alpha) {
    _blinkAlpha = alpha.clamp(0.0, 1.0);

    _hpTextComponent?.textRenderer = TextPaint(
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black.withValues(alpha: _blinkAlpha)),
    );
  }

  HexagonShape(
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
          size: customSize ?? Vector2.all(100),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    // z-order(priority)는 스폰 시 생성 순서 기반으로 설정된다. (크기 무관)
    await super.onLoad();

    _sprite = await Sprite.load('shapes/Hexagon_3x.png', images: _images);
    _rebuildGeometry();

    _currentHp = energy;

    if (!isDark && energy >= 1) {
      _hpTextComponent = TextComponent(
        text: energy.toString(),
        anchor: Anchor.center,
        position: size / 2,
        priority: 999,
        textRenderer: TextPaint(
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      );
      add(_hpTextComponent!);
    }
  }

  @override
  void onRemove() {
    _stopStretchSound();
    super.onRemove();
  }

  // For size-change command S(...): update size and rebuild size-derived caches.
  @override
  void setShapeSize(Vector2 newSize) {
    size.setFrom(newSize);
    // Before onLoad, onLoad will build caches from the new size.
    if (!isLoaded) return;
    _rebuildGeometry();
  }

  // Values derived from size; cached instead of recomputed every frame.
  void _rebuildGeometry() {
    _outlinePath = _buildHexagonPath(size.toSize());
    _outlineLength =
        _outlinePath.computeMetrics().fold(0.0, (s, m) => s + m.length);
    _attackPaint.strokeWidth = size.x * 0.06;
    _hpTextComponent?.position = size / 2;
  }

  Path _buildHexagonPath(Size s) {

    final center = Offset(s.width / 2, s.height / 2);

    final inset = -(s.width * 0.02);

    final radius = (s.width / 2) - inset;

    final path = Path();

    for (int i = 0; i < 6; i++) {

      final angle = (math.pi / 3) * i + _hexAngleOffset;

      final p = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    path.close();

    return path;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_blinkAlpha <= 0) {
      event.continuePropagation = true;
      return;
    }
    event.continuePropagation = false;
    if (isDark && !isPaused) onForbiddenTouch?.call();
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    // Visible hexagons consume drags that start on them so the game does not
    // interpret a finger of the pinch as a slice or an encircling gesture.
    event.continuePropagation = _blinkAlpha <= 0;
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (isDark && !isPaused && _blinkAlpha > 0) onForbiddenTouch?.call();
  }

  bool get canPinch =>
      isMounted &&
      !isRemoving &&
      !isDark &&
      !isPaused &&
      _blinkAlpha > 0 &&
      (_state == HexagonState.normal || _state == HexagonState.shrinkingBack);

  void beginPinch() {
    _state = HexagonState.normal;
  }

  void updatePinchScale(double nextScale) {
    if (!canPinch || _state != HexagonState.normal || nextScale == dragScale) {
      return;
    }
    if (!_stretchSfxPlaying) {
      _stretchSfxPlaying = true;
      AudioManager.instance.startHexagonStretch();
    }

    dragScale = energy > 0 ? math.min(nextScale, 1.0 + energy * 0.2) : nextScale;
    scale = Vector2.all(dragScale);

    if (energy >= 1) {
      final stage = _stretchDamage(dragScale);
      final newHp = energy - stage;
      if (newHp != _currentHp) {
        _currentHp = newHp;
        _hpTextComponent?.text = _currentHp > 0 ? '$_currentHp' : '';
        if (_currentHp <= 0) {
          wasRemovedByUser = true;
          _finalScale = dragScale;
          _stopStretchSound();
          _state = HexagonState.disappearing;
        }
      }
    }
  }

  int _stretchDamage(double currentScale) =>
      ((currentScale - 1.0) * 5 + 1e-9).floor().clamp(0, energy);

  void endPinch() {
    _stopStretchSound();
    if (_state != HexagonState.normal) return;

    if (dragScale > 1.0) {
      _shrinkStartScale = dragScale;
      _shrinkBackT = 0.0;
      _state = HexagonState.shrinkingBack;
    }
  }

  void _stopStretchSound() {
    if (!_stretchSfxPlaying) return;
    _stretchSfxPlaying = false;
    AudioManager.instance.stopHexagonStretch();
  }

  @override
  void update(double dt) {

    super.update(dt);

    if (isPaused) {
      _stopStretchSound();
      return;
    }

    // ============================
    // ATTACK TIMER → 즉시 자폭
    // ============================

    if (!waitingForInitialMovement && (attackTime ?? 0) > 0 && !_attackDone) {

      _attackElapsed += dt;

      final ratio =
          ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);

      final isDanger = ratio <= 0.2;

      _attackPaint.color = isDanger ? dangerColor : baseColor;

      if (_attackElapsed >= attackTime!) {

        _attackDone = true;

        if (!_penaltyFired) {
          _penaltyFired = true;
          onExplode?.call();
        }

        wasRemovedByUser = false;

        parent?.add(
          AttackExplosionEffect(
            basePath: _buildExplosionHexagonPath(),
            position: position.clone(),
            size: size.clone(),
            color: const Color(0xFF398A63),
          ),
        );

        removeFromParent();

        return;
      }
    }

    // ============================
    // SHRINK BACK
    // ============================

    if (_state == HexagonState.shrinkingBack) {

      _shrinkBackT += dt / 0.6;

      final t = Curves.easeOut.transform(_shrinkBackT.clamp(0.0, 1.0));

      final curScale = _shrinkStartScale + t * (1.0 - _shrinkStartScale);

      dragScale = curScale;
      scale = Vector2.all(curScale);

      if (energy >= 1) {
        final stage = _stretchDamage(curScale);
        final displayHp = energy - stage;
        if (displayHp != _currentHp) {
          _currentHp = displayHp;
          _hpTextComponent?.text = '$_currentHp';
        }
      }

      if (_shrinkBackT >= 1.0) {
        dragScale = 1.0;
        scale = Vector2.all(1.0);
        _currentHp = energy;
        if (energy >= 1) _hpTextComponent?.text = '$energy';
        _state = HexagonState.normal;
      }
    }

    // ============================
    // USER REMOVE
    // ============================

    if (_state == HexagonState.disappearing) {

      _disappearT += dt / 0.35;

      final t = _disappearT.clamp(0.0, 1.0);

      final extraT = (t / 0.25).clamp(0.0, 1.0);

      final extraScale =
          Curves.easeOut.transform(extraT) * (extraDisappearScale - 1.0);

      scale = Vector2.all(_finalScale * (1.0 + extraScale));

      _opacity = 1.0 - Curves.easeIn.transform(t);

      if (_disappearT >= 1.0) {

        // 일반 제거: 육각형 꼭짓점 방향으로 6갈래 파티클 버스트
        parent?.add(
          HexagonBurstEffect(
            position: position.clone(),
            radius: (size.x / 2) * scale.x,
            color: const Color(0xFF398A63),
          ),
        );

        removeFromParent();
      }
    }
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    if (!isDark) {
      // Match the sprite's flat top and bottom, with 5% total touch padding.
      final x = (point.x / size.x - 0.5).abs();
      final y = (point.y / size.y - 0.5).abs();
      return y <= 0.525 && x + y * 0.5 <= 0.525;
    }
    final cx = size.x / 2;
    final cy = size.y / 2;
    const inset = 13.0;
    final r = (size.x / 2) - inset;
    final pts = List.generate(6, (i) {
      final a = (math.pi / 3) * i + _hexAngleOffset;
      return Vector2(cx + r * math.cos(a), cy + r * math.sin(a));
    });
    return _pointInPolygon(point, pts);
  }

  bool _pointInPolygon(Vector2 p, List<Vector2> poly) {
    int count = 0;
    for (int i = 0; i < poly.length; i++) {
      final a = poly[i];
      final b = poly[(i + 1) % poly.length];
      if (((a.y > p.y) != (b.y > p.y)) &&
          (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y + 0.0001) + a.x)) {
        count++;
      }
    }
    return count.isOdd;
  }

  static const double _borderHalo = 0.05;

  @override
  void render(Canvas canvas) {
    final alpha = (_blinkAlpha * _opacity).clamp(0.0, 1.0);

    if ((attackTime ?? 0) <= 0 || _attackDone) {
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
    }

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

    super.render(canvas);

    if ((attackTime ?? 0) > 0 && !_attackDone) {

      final ratio =
          ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);

      final drawLen = _outlineLength * ratio;

      final partial = ShapePathUtils.extractPartial(_outlinePath, drawLen);

      canvas.drawPath(partial, _attackPaint);
    }
  }

  @override
  Rect toRect() {

    return Rect.fromCenter(
      center: Offset(position.x, position.y),
      width: size.x * scale.x,
      height: size.y * scale.y,
    );
  }

  Path _buildExplosionHexagonPath() {

    final w = size.x;
    final h = size.y;

    return Path()
      ..moveTo(w * 0.25, 0)
      ..lineTo(w * 0.75, 0)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.75, h)
      ..lineTo(w * 0.25, h)
      ..lineTo(0, h * 0.5)
      ..close();
  }
}

