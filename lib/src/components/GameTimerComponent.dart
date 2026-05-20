import 'dart:math';

import 'package:figureout/src/config.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class GameTimerComponent extends PositionComponent {
  late TextComponent timerText;

  double totalTime;
  double currentTime;

  bool _ready = false;
  double _flashPenaltyRemaining = 0.0;

  static const double _epsilon = 1e-3;
  static const double _textAreaWidth = 60.0;

  GameTimerComponent({
    required this.totalTime,
    required Vector2 position,
    Vector2? sizePx,
  })  : currentTime = totalTime,
        super(
          position: position,
          size: sizePx ?? Vector2(320, 28),
          anchor: Anchor.topLeft,
        );

  String _formatTime(double time) {
    final int seconds = time.floor();
    final int minutes = seconds ~/ 60;
    final int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    timerText = TextComponent(
      text: _formatTime(currentTime),
      anchor: Anchor.centerRight,
      position: Vector2(_textAreaWidth - 8, size.y / 2),
      priority: 10,
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 18,
          height: 21 / 16,
          color: Colors.black,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    add(timerText);

    _ready = true;
    updateTime(currentTime);
  }

  void updateTime(double remaining) {
    currentTime = remaining;
    if (!_ready) return;
    timerText.text = _formatTime(currentTime);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_flashPenaltyRemaining > 0) {
      _flashPenaltyRemaining =
          (_flashPenaltyRemaining - dt).clamp(0.0, double.infinity).toDouble();
    }
  }

  Path _buildWigglyPath(double barLeft, double barWidth, double barHeight) {
    const amp = 0.8;
    const freq = 0.7;
    const step = 4.0;
    final radius = barHeight / 2;
    final right = barLeft + barWidth;
    final cy = barHeight / 2;

    double wTop(double x) => sin(x * freq) * amp;
    double wBot(double x) => sin(x * freq + pi * 0.7) * amp;

    final path = Path();

    // Top edge: left-arc-end → right-arc-start
    path.moveTo(barLeft + radius, wTop(barLeft + radius));
    for (double x = barLeft + radius + step; x < right - radius; x += step) {
      path.lineTo(x, wTop(x));
    }
    path.lineTo(right - radius, wTop(right - radius));

    // Right semicircle
    for (int i = 1; i <= 12; i++) {
      final a = -pi / 2 + pi * i / 12;
      path.lineTo(right - radius + cos(a) * radius, cy + sin(a) * radius);
    }

    // Bottom edge: right-arc-start → left-arc-end
    path.lineTo(right - radius, barHeight + wBot(right - radius));
    for (double x = right - radius - step; x > barLeft + radius; x -= step) {
      path.lineTo(x, barHeight + wBot(x));
    }
    path.lineTo(barLeft + radius, barHeight + wBot(barLeft + radius));

    // Left semicircle
    for (int i = 1; i <= 12; i++) {
      final a = pi / 2 + pi * i / 12;
      path.lineTo(barLeft + radius + cos(a) * radius, cy + sin(a) * radius);
    }

    path.close();
    return path;
  }

  @override
  void render(Canvas canvas) {
    final barLeft = _textAreaWidth;
    final barWidth = size.x - _textAreaWidth;
    final ratio =
        totalTime > 0 ? (currentTime / totalTime).clamp(0.0, 1.0) : 0.0;
    final isDanger = currentTime <= 10.0 + _epsilon;
    final isWarning = !isDanger && ratio <= 0.5;
    final fillColor = (_flashPenaltyRemaining > 0 || isDanger)
        ? const Color(0xFFED613D)
        : isWarning
            ? const Color(0xFFF0C400)
            : const Color(0xFF63BE5D);

    final wigglyPath = _buildWigglyPath(barLeft, barWidth, size.y);

    if (ratio > 0) {
      canvas.save();
      canvas.clipPath(wigglyPath);
      canvas.drawRect(
        Rect.fromLTWH(barLeft, 0, barWidth * ratio, size.y),
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill,
      );
      canvas.restore();
    }

    canvas.drawPath(
      wigglyPath,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    super.render(canvas);
  }

  void flashPenalty({double durationSec = 0.4}) {
    if (!_ready) return;
    _flashPenaltyRemaining = durationSec;

    timerText.textRenderer = TextPaint(
      style: const TextStyle(
        fontFamily: 'Moulpali',
        fontSize: 16,
        height: 21 / 16,
        color: Colors.red,
        fontWeight: FontWeight.bold,
      ),
    );

    add(
      TimerComponent(
        period: durationSec,
        onTick: () {
          timerText.textRenderer = TextPaint(
            style: const TextStyle(
              fontFamily: 'Moulpali',
              fontSize: 16,
              height: 21 / 16,
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          );
        },
        removeOnFinish: true,
        repeat: false,
      ),
    );
  }

  void showDamageNumber(double damage) {
    if (!_ready) return;

    final damageText = TextComponent(
      text: '-${damage.toStringAsFixed(0)}',
      anchor: Anchor.center,
      position: Vector2(size.x - 18, -18),
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'Moulpali',
          fontSize: 18,
          color: Colors.red,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black54,
              offset: Offset(1, 1),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    );

    add(damageText);

    add(
      TimerComponent(
        period: 1.0,
        onTick: () => damageText.removeFromParent(),
        removeOnFinish: true,
        repeat: false,
      ),
    );
  }
}
