import 'dart:ui';
import 'dart:async' as async;
import 'package:figureout/src/functions/UserRemovable.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';
import 'package:figureout/src/functions/BlinkingBehavior.dart';

class PentagonShape extends PositionComponent
    with HasPaint, TapCallbacks, UserRemovable {
  int energy = 0;
  bool _isLongPressing = false;
  late final SvgComponent svg;

  PentagonShape(Vector2 position, int energy)
    : super(position: position, size: Vector2.all(100), anchor: Anchor.center) {
    this.energy = energy;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final svgData = await Svg.load('pentagon.svg');

    svg = SvgComponent(
      svg: svgData,
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );
    add(svg);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // svg.render(canvas);

    if (energy > 0) {
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

  @override
  void onLongTapDown(TapDownEvent event) {
    super.onLongTapDown(event);

    print("presseddddd");
    _isLongPressing = true;
    final blinking = parent?.children
        .whereType<BlinkingBehaviorComponent>()
        .cast<BlinkingBehaviorComponent?>()
        .firstWhere((b) => b?.shape == this, orElse: () => null);
    if (blinking != null) {
      blinking.isPaused = true; // Pause blinking behavior
    }

    _startLongPress(); // Consume the event
  }

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);

    final blinking = parent?.children
        .whereType<BlinkingBehaviorComponent>()
        .cast<BlinkingBehaviorComponent?>()
        .firstWhere((b) => b?.shape == this, orElse: () => null);
    if (blinking != null) {
      blinking.isPaused = false; // Pause blinking behavior
    }
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
        period: 0.03, // 0.3 seconds
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
