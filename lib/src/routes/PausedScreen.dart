import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';
import '../functions/svgButton.dart';

class PausedScreen extends PositionComponent {
  final VoidCallback onResume;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  PausedScreen({
    required Vector2 screenSize,
    required this.onResume,
    required this.onRetry,
    required this.onMenu,
  }) : super(size: screenSize, position: Vector2.zero());

  @override
  Future<void> onLoad() async {
    // 반투명 배경
    final overlayBg = RectangleComponent(
      size: size,
      paint: Paint()..color = Colors.black.withOpacity(0.5),
    );
    add(overlayBg);

    // Pause 창 패널
    final panelSvg = await Svg.load('Paused window.svg');
    final panelSize = Vector2(size.x * 0.8, size.y*0.6);
    final panel = SvgComponent(
      svg: panelSvg,
      size: panelSize,
      anchor: Anchor.center,
      position: size / 2,
    );
    add(panel);

    final buttonSize = Vector2(panelSize.x * 0.2, panelSize.x * 0.2);

    final centerY = panelSize.y / 2;

    // 버튼 배치
    final buttonY = centerY;
    final spacing = panelSize.x * 0.3;

    final menuButton = SvgButton(
      assetPath: 'State=Default, Type=Menu.svg',
      size: buttonSize ,
      position: Vector2(panelSize.x / 2 - spacing, buttonY),
      onTap: onMenu,
    )..anchor=Anchor.center;
    panel.add(menuButton);

    final resumeButton = SvgButton(
      assetPath: 'State=Default, Type=Resume.svg',
      size: buttonSize,
      position: Vector2(panelSize.x / 2, buttonY),
      onTap: onResume,
    )..anchor=Anchor.center;
    panel.add(resumeButton);

    final retryButton = SvgButton(
      assetPath: 'State=Default, Type=Retry.svg',
      size: buttonSize,
      position: Vector2(panelSize.x / 2+spacing, buttonY),
      onTap: onRetry,
    )..anchor=Anchor.center;
    panel.add(retryButton);
  }
}
