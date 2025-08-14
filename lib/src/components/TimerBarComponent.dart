import 'package:flame/components.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';

class TimerBarComponent extends PositionComponent {
  SvgComponent? frame;
  SvgComponent? stateIndicator;
  ClipComponent? clip;

  double totalTime;
  double currentTime;

  String _currentFillAsset = 'Timer Bar-2.svg';
  bool _ready = false;

  static const double _epsilon = 1e-3;

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

  String _frameOf(String fill) {
    if (fill.endsWith('.svg')) {
      final base = fill.substring(0, fill.length - 4);
      return '$base - Empty.svg';
    }
    return '${fill} - Empty.svg';
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    stateIndicator = SvgComponent(
      svg: await Svg.load(_currentFillAsset),
      size: size,
      anchor: Anchor.topLeft,
    );

    clip = ClipComponent.rectangle(size: size);
    clip!.add(stateIndicator!);

    frame = SvgComponent(
      svg: await Svg.load(_frameOf(_currentFillAsset)),
      size: size,
      anchor: Anchor.topLeft,
    );

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
      _changeState('Timer Bar-1.svg');
    } else if (ratio <= 0.5) {
      _changeState('Timer Bar.svg');
    } else {
      _changeState('Timer Bar-2.svg');
    }

    const double minWidth = 0.0001;
    clip!.size = Vector2(size.x * (ratio > 0 ? ratio : minWidth), size.y);

    stateIndicator!.size = size;
  }

  void _changeState(String fillAsset) async {
    _currentFillAsset = fillAsset;
    if (!_ready) return;

    final fillSvg = await Svg.load(fillAsset);
    final frameSvg = await Svg.load(_frameOf(fillAsset));
    stateIndicator?.svg = fillSvg;
    frame?.svg = frameSvg;
  }
}
