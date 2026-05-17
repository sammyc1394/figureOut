import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class GameTimerComponent extends PositionComponent {
  late TextComponent timerText;

  double totalTime;
  double currentTime;

  bool _ready = false;
  double _flashPenaltyRemaining = 0.0;

  static const double _epsilon = 1e-3;

  GameTimerComponent({
    required this.totalTime,
    required Vector2 position,
    Vector2? sizePx,
  })  : currentTime = totalTime,
        super(
          position: position,
          size: sizePx ?? Vector2(320, 28),
          anchor: Anchor.topCenter,
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
      anchor: Anchor.center,
      position: size / 2,
      priority: 10,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'Moulpali',
          fontSize: 16,
          height: 21 / 16,
          color: Colors.black,
          fontWeight: FontWeight.bold,
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

  @override
  void render(Canvas canvas) {
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final radius = Radius.circular(size.y / 2);
    final rrect = RRect.fromRectAndRadius(rect, radius);
    final ratio =
        totalTime > 0 ? (currentTime / totalTime).clamp(0.0, 1.0) : 0.0;
    final isDanger = currentTime <= 10.0 + _epsilon;
    final fillColor = (isDanger || _flashPenaltyRemaining > 0)
        ? const Color(0xFFE53935)
        : const Color(0xFF55C867);

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFFE8E8E8)
        ..style = PaintingStyle.fill,
    );

    if (ratio > 0) {
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x * ratio, size.y),
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill,
      );
      canvas.restore();
    }

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFF2E2E2E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
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
