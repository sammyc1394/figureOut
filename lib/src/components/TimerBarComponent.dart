import 'package:flame/components.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';

class TimerBarComponent extends PositionComponent {
  late final SvgComponent barBackground;
  late final SvgComponent stateIndicator;
  late final ClipComponent clip;

  double totalTime;
  double currentTime;
  String _currentAsset = 'Type=Full.svg';

  static const double _epsilon = 1e-3; // 0 너비 회피용

  TimerBarComponent({
    required this.totalTime,
    required Vector2 position,
    Vector2? sizePx,
  }) : currentTime = totalTime,
       super(
         position: position,
         size: sizePx ?? Vector2(320, 28),
         anchor: Anchor.topCenter,
       );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    stateIndicator = SvgComponent(
      svg: await Svg.load(_currentAsset),
      size: size,
      anchor: Anchor.topLeft,
    );

    clip = ClipComponent.rectangle(size: size);
    clip.add(stateIndicator);

    // add(barBackground);
    add(clip);
  }

  void updateTime(double remaining) {
    currentTime = remaining;
    final ratio = (totalTime > 0)
        ? (remaining / totalTime).clamp(0.0, 1.0)
        : 0.0;

    if (ratio <= 0.2) {
      _changeState('Timer Bar-1.svg');
    } else if (ratio <= 0.5) {
      _changeState('Timer Bar.svg');
    } else {
      _changeState('Timer Bar-2.svg');
    }

    // ratio가 0이면 완전히 줄이되 NaN 방지용 최소값 유지
    const double minWidth = 0.0001;
    clip.size = Vector2(size.x * (ratio > 0 ? ratio : minWidth), size.y);
  }

  void _changeState(String assetName) async {
    stateIndicator.svg = await Svg.load(assetName);
  }
}
