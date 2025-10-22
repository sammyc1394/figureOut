import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';
import 'package:figureout/src/functions/UserRemovable.dart';

class CircleShape extends PositionComponent with TapCallbacks, UserRemovable {
  int count;
  final bool isDark;
  final VoidCallback? onForbiddenTouch;

  final double? attackSeconds;
  final VoidCallback? onAttackTimeout;

  double _attackElapsed = 0.0;
  bool _attackDone = false;
  bool _penaltyFired = false;
  bool isPaused = false;

  late SvgComponent _svg;
  String _currentAsset = '';

  CircleShape(
    Vector2 position,
    this.count, {
    this.isDark = false,
    this.onForbiddenTouch,
    this.attackSeconds,
    this.onAttackTimeout,
  }) : super(position: position, size: Vector2.all(80), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final String initial = isDark ? 'DarkCircle.svg' : 'Circle (tap).svg';
    _currentAsset = initial;

    _svg = SvgComponent(
      svg: await Svg.load(initial),
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_svg);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if(isPaused) return;
    if ((attackSeconds ?? 0) <= 0) return;

    _attackElapsed += dt;
    final remain = max(0.0, attackSeconds! - _attackElapsed);
    final ratio = (remain / attackSeconds!).clamp(0.0, 1.0);

    if (!_attackDone) {
      // 타이머 진행 중 → attack SVG 프레임으로 교체
      final int frame = max(1, (ratio * 14).ceil());
      final String frameAsset = '$frame.svg';
      if (_currentAsset != frameAsset) {
        _replaceSvg(frameAsset);
      }

      if (_attackElapsed >= attackSeconds!) {
        _attackDone = true;
        if (!_penaltyFired) {
          _penaltyFired = true;
          onAttackTimeout?.call();
        }

        // 타이머 끝나면 원래 원으로 복귀
        final String reset = isDark ? 'DarkCircle.svg' : 'Circle (tap).svg';
        _replaceSvg(reset);
      }
    }
  }

  Future<void> _replaceSvg(String asset) async {
    _currentAsset = asset;
    final newSvg = await Svg.load(asset);
    _svg.svg = newSvg;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 숫자 (다크 도형 제외)
    if (!isDark && count > 0) {
      final tp = TextPainter(
        text: TextSpan(
          text: count.toString(),
          style: const TextStyle(
            color: Color(0xFFFF9D33),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        Offset((size.x - tp.width) / 2, (size.y - tp.height) / 2),
      );
    }
  }

  @override
  void onTapDown(TapDownEvent e) {
    if (isDark) {
      onForbiddenTouch?.call();
      return;
    }

    count--;
    if (count <= 0) {
      wasRemovedByUser = true;
      removeFromParent();
    }
  }
}
