import 'dart:math';
import 'dart:ui';
import 'dart:async' as async;
import 'package:figureout/src/functions/UserRemovable.dart';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';
import 'package:figureout/src/functions/BlinkingBehavior.dart';
import 'dart:typed_data';

class PentagonShape extends PositionComponent
    with HasPaint, TapCallbacks, UserRemovable, HasGameReference<FlameGame> {
  int energy = 0;
  bool _isLongPressing = false;
  late final SvgComponent svg;
  late SpriteComponent _png;

  final bool isDark;
  final VoidCallback? onForbiddenTouch;
  
  final double? attackTime;
  final VoidCallback? onExplode;

  double _attackElapsed = 0.0;
  bool _attackDone = false;
  bool isPaused = false;

  Rect? _pngOpaqueBounds;
  Offset _outlineCenter = Offset.zero;
  double _outlineRadius = 0.0;

  static const double _rotationDeg = 0.0;

  final Paint _attackPaint = Paint() 
    ..color = const Color(0xFFFFA6FC)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 6;

  late Path _pentagonPath;
  late double _perimeter;

  final Color baseColor = const Color(0xFFFFA6FC);
  final Color dangerColor = const Color(0xFFEE0505);


  PentagonShape(Vector2 position, int energy, {
    this.isDark = false,
    this.onForbiddenTouch,
    this.attackTime,
    this.onExplode,
  })
    : super(position: position, size: Vector2.all(100), anchor: Anchor.center) {
    this.energy = energy;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    final String asset = isDark ? 'DarkPentagon.svg' : 'pentagon.svg';
    final svgData = await Svg.load(asset);

    svg = SvgComponent(
      svg: svgData,
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
    add(svg);
    
    final images = Images(prefix: 'assets/');
    final img = await images.load('shapes/Pentagon.png');

    _png = SpriteComponent(
      sprite: Sprite(img),
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );

    _png.opacity = 0;
    add(_png);

    // -------------------------------
    // 3) attackTime 있으면 PNG 사용
    // -------------------------------
    if ((attackTime ?? 0) > 0) {
      svg.opacity = 0;
      _png.opacity = 1;
    }

    // ------------------------------------------------------------
    // 4) 오각형 Path 생성
    // ------------------------------------------------------------
    _pentagonPath = _buildPentagonPath(size.toSize());
    _perimeter = _calculatePerimeter(_pentagonPath);
  }

  Path _buildPentagonPath(Size size) {
    final cx = size.width / 2.2;
    final cy = size.height / 2;
    final r = size.width * 0.40;

    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (-90 + i * 70) * pi / 180;
      final x = cx + r * cos(angle);
      final y = cy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  double _calculatePerimeter(Path path) {
    return path
        .computeMetrics()
        .fold(0.0, (sum, m) => sum + m.length);
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
    return ratio <= 0.5;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // ------------------------------------------------------------
    // Path 기반 공격 타이머
    // ------------------------------------------------------------
    if ((attackTime ?? 0) > 0 && !_attackDone) {
      final ratio =
          ((attackTime! - _attackElapsed) / attackTime!).clamp(0.0, 1.0);

      final drawLength = _perimeter * ratio;

      _attackPaint.color =
          ratio <= 0.5 ? dangerColor : baseColor;

      final partial = _extractPartialPath(_pentagonPath, drawLength);
      canvas.drawPath(partial, _attackPaint);
    }

    if (!isDark && energy > 0) {
      _drawText(canvas, energy.toString());
    }
  }

  void _drawText(Canvas canvas, String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFFC100BA),
          fontSize: 20,
          textBaseline: TextBaseline.alphabetic,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final offset = Offset(
      (size.x - textPainter.width - 5) / 2,
      (size.y - textPainter.height) / 2,
    );

    canvas.save();
    textPainter.paint(canvas, offset);
    canvas.restore();
  }

  BlinkingBehaviorComponent? _myBlinking() {
    for (final b in game.children.whereType<BlinkingBehaviorComponent>()) {
      if (identical(b.shape, this)) return b;
    }
    return null;
  }
  
  @override
  void onTapDown(TapDownEvent event) { 
    // if (isDark && !_penaltyFired) {
    if (isDark) {
      // _penaltyFired = true;
      onForbiddenTouch?.call();
    }
  }

  @override
  void onLongTapDown(TapDownEvent event) {
    super.onLongTapDown(event);

    if (isDark) {
        onForbiddenTouch?.call();
      return;
    }

    print("presseddddd");
    _isLongPressing = true;
    _myBlinking()?.isPaused = true;

    _startLongPress(); // Consume the event
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);

    _myBlinking()?.isPaused = false;
    _stopLongPress();
  }

  void _startLongPress() {
    _isLongPressing = true;
    _startRepeatingDecrement();
  }

  void _stopLongPress() {
    _isLongPressing = false;
  }

  void _startRepeatingDecrement() {
    // Use Flame's built-in timer approach
    add(
      TimerComponent(
        period: 0.1, // 0.3 seconds
        repeat: _isLongPressing,
        onTick: () {
          if (energy > 0) {
            if (_isLongPressing) {
              energy -= 1;
              // print('Number decreased to: $energy, press status : $_isLongPressing');
            } else {
              _stopLongPress();
            }
          } else {
            wasRemovedByUser = true;
            removeFromParent();
          }
        },
      ),
    );
  }
}
