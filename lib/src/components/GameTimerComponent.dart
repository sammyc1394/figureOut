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

  // 막대기 부품 하나만 사용
  SvgComponent? bar;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 초록색 원본 막대 하나만 로드합니다.
    bar = SvgComponent(
      svg: await Svg.load('TimerBar_green.svg'),
      size: size,
    );

    clip = ClipComponent.rectangle(size: size);
    clip!.add(bar!);

    frame = SvgComponent(
      svg: await Svg.load(_frameOf('TimerBar_green.svg')),
      size: size,
      anchor: Anchor.topLeft,
    );

    timerText = TextComponent(
      text: _formatTime(currentTime),
      anchor: Anchor.topRight,
      position: Vector2(-8, (size.y - 21) / 2),
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
    updateTime(currentTime);
  }

  void updateTime(double remaining) {
    currentTime = remaining;
    if (!_ready || bar == null) return;

    final ratio = (totalTime > 0)
        ? (remaining / totalTime).clamp(0.0, 1.0)
        : 0.0;

    // 10초 이하일 때만 빨간색 필터를 입히고, 그 외에는 필터를 제거(null)합니다.
    // 이렇게 하면 평소에는 원본 초록색의 예쁜 색감이 그대로 유지됩니다.
    if (currentTime <= 10.0 + _epsilon) {
      bar!.paint = Paint()
        ..colorFilter = const ColorFilter.mode(Colors.red, BlendMode.srcIn);
    } else {
      // 10초보다 많으면 필터를 완전히 제거하여 원본 이미지를 보여줍니다.
      bar!.paint = Paint(); 
    }

    const double minWidth = 0.0001;
    clip!.size = Vector2(size.x * (ratio > 0 ? ratio : minWidth), size.y);

    timerText.text = _formatTime(currentTime);
  }

  // 더 이상 사용하지 않는 레거시 함수들 정리
  void _showOnly(SvgComponent? target) {}
  void _tint(Color color) {}
  void _changeState(String fillAsset) async {}
  
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
