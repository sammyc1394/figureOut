import 'package:flame/components.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';

class GameTimerComponent extends PositionComponent {
  SvgComponent? frame;
  SvgComponent? stateIndicator;
  ClipComponent? clip;

  late TextComponent timerText;

  double totalTime;
  double currentTime;

  String _currentFillAsset = 'TimerBar_green.svg';
  bool _ready = false;

  static const double _epsilon = 1e-3;

  GameTimerComponent({
    required this.totalTime,
    required Vector2 position,
    Vector2? sizePx,
  }) : currentTime = totalTime,
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

  String _frameOf(String fill) {
    if (fill.endsWith('.svg')) {
      final base = fill.substring(0, fill.length - 4);
      return '${base}_empty.svg';
    }
    return '${fill}_empty.svg';
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    stateIndicator = SvgComponent(
      svg: await Svg.load(_currentFillAsset),
      size: size,
      anchor: Anchor.topLeft,
    );

    print('Timer bar: ${position.toString()}');

    clip = ClipComponent.rectangle(size: size);
    clip!.add(stateIndicator!);

    frame = SvgComponent(
      // svg: await Svg.load('TimerBar_green_empty.svg'),
      svg: await Svg.load(_frameOf(_currentFillAsset)),
      size: size,
      anchor: Anchor.topLeft,
    );

    timerText = TextComponent(
      text: _formatTime(currentTime),
      anchor: Anchor.topRight,
      position: Vector2(-8, (size.y - 21) / 2), // 왼쪽에 살짝 붙여서 정렬
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'Moulpali',
          fontSize: 16,
          height: 21 / 16,
          letterSpacing: -0.32,
          color: Colors.black,
        ),
      ),
    );

    add(timerText);
    add(clip!);
    add(frame!);

    _ready = true;
  }

  void updateTime(double remaining) {
    currentTime = remaining;

    if (!_ready) return;

    final ratio = (totalTime > 0)
        ? (remaining / totalTime).clamp(0.0, 1.0)
        : 0.0;

    if (ratio <= 0.2) {
      _changeState('TimerBar_red.svg');
    } else if (ratio <= 0.5) {
      _changeState('TimerBar_yellow.svg');
    } else {
      _changeState('TimerBar_green.svg');
    }

    const double minWidth = 0.0001;
    clip!.size = Vector2(size.x * (ratio > 0 ? ratio : minWidth), size.y);

    stateIndicator!.size = size;

    timerText.text = _formatTime(currentTime);
  }

  void _changeState(String fillAsset) async {
    _currentFillAsset = fillAsset;
    if (!_ready) return;

    final fillSvg = await Svg.load(fillAsset);
    final frameSvg = await Svg.load(_frameOf(fillAsset));
    stateIndicator?.svg = fillSvg;
    frame?.svg = frameSvg;
  }
  
  void flashPenalty({double durationSec = 0.4}) {
    if (!_ready) return;
    timerText.textRenderer = TextPaint(
      style: const TextStyle(
        fontFamily: 'Moulpali',
        fontSize: 16,
        height: 21 / 16,
        letterSpacing: -0.32,
        color: Colors.red, // 빨간색
      ),
    );
    // 일정 시간 뒤 검정으로 복구
    add(
      TimerComponent(
        period: durationSec,
        onTick: () {
          timerText.textRenderer = TextPaint(
            style: const TextStyle(
              fontFamily: 'Moulpali',
              fontSize: 16,
              height: 21 / 16,
              letterSpacing: -0.32,
              color: Colors.black,
            ),
          );
        },
        removeOnFinish: true,
        repeat: false,
      ),
    );
  }
}
