import 'package:figureout/src/functions/svgButton.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/text.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'OneSecondGame.dart';
import 'package:figureout/src/config.dart';

class AftermathScreen extends PositionComponent with TapCallbacks {
  // results
  final StageResult result;
  late final int starCount;
  late final int stgIndex;
  late final int msnIndex;

  // ui svgs
  late final SvgComponent background;
  late final SvgComponent levelStatus;
  late final SvgComponent menuButton;
  late final SvgComponent
  retryButton; // retry(if failed) or continue(if success)
  late final SvgComponent playButton;
  late final SvgComponent levelIcon; // heart(if failed) or stars(if success)

  // functions
  late final VoidCallback onContinue;
  late final VoidCallback onRetry;
  late final VoidCallback onPlay;
  late final VoidCallback onMenu;

  AftermathScreen({
    required this.result,
    required this.starCount,
    required this.onContinue,
    required this.onRetry,
    required this.onPlay,
    required this.onMenu,
    required Vector2 screenSize,
    required this.stgIndex,
    required this.msnIndex,
  }) : super(position: Vector2.zero(), size: screenSize) {
    priority = 5000;
  }

  @override
  Future<void> onLoad() async {
    if (result == StageResult.success) {
      await _loadSuccessScreen();
    } else {
      await _loadFailScreen();
    }
  }

  Future<void> _loadSuccessScreen() async {
    try {

      final bgSvg = await Svg.load('menu/common/bg.svg');
      background = SvgComponent(
        svg: bgSvg,
        size: size,
        position: Vector2.zero(),
        anchor: Anchor.topLeft,
      );
      add(background);

      final statusSvg = await Svg.load('Banner_levelComplete.svg');
      levelStatus = SvgComponent(
        svg: statusSvg,
        size: size / 2,
        position: Vector2(size.x * 0.5, size.y * 0.35),
        anchor: Anchor.center,
      );
      add(levelStatus);

      final levelTitle = TextComponent(
        text: "S ${stgIndex + 1} - M ${msnIndex}",
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'Moulpali',
            fontSize: 22,
            color: Colors.black,
          ),
        ),
        position: Vector2(size.x * 0.5, size.y * 0.35),
        anchor: Anchor.center,
      );
      add(levelTitle);

      final label = TextComponent(
        text: i18n.t('level_completed'),
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'Moulpali',
            fontSize: 22,
            color: Colors.black,
          ),
        ),
        position: Vector2(size.x * 0.5, size.y * 0.55),
        anchor: Anchor.center,
      );
      add(label);

      // Stars based on rating (centered)
      final starSvgTitle = _addStars();
      final levelIconSvg = await Svg.load(starSvgTitle);
      levelIcon = SvgComponent(
        svg: levelIconSvg,
        size: size / 2,
        position: Vector2(size.x * 0.5, size.y * 0.45),
        anchor: Anchor.center,
      );
      add(levelIcon);

      // bottom area button row
      final buttonX = size.x * 0.2;
      final buttonY = size.y * 0.55;
      final buttonSpacing = size.x * 0.25;

      final menuButton = SvgButton(
        assetPath: 'Menu_basic.svg',
        size: size / 8,
        position: Vector2(buttonX, buttonY),
        onTap: onMenu,
      );
      add(menuButton);

      final playNextButton = SvgButton(
        assetPath: 'Play_basic.svg',
        size: size / 8,
        position: Vector2(buttonX + buttonSpacing, buttonY),
        onTap: onPlay,
      );
      add(playNextButton);

      final retryButton = SvgButton(
        assetPath: 'Retry_default.svg',
        size: size / 8,
        position: Vector2(buttonX + buttonSpacing * 2, buttonY),
        onTap: onRetry,
      );
      add(retryButton);

    } catch (e) {
      print('Error loading success aftermath : $e');
    }
  }

  Future<void> _loadFailScreen() async {
    try {
      final bgSvg = await Svg.load('menu/common/bg.svg');
      background = SvgComponent(
        svg: bgSvg,
        size: size,
        position: Vector2.zero(),
        anchor: Anchor.topLeft,
      );
      add(background);


      final statusSvg = await Svg.load('Banner_levelFailed.svg');
      levelStatus = SvgComponent(
        svg: statusSvg,
        size: size / 2,
        position: Vector2(size.x * 0.5, size.y * 0.35),
        anchor: Anchor.center,
      );
      add(levelStatus);

      final levelLabel = TextComponent(
        text: "S ${stgIndex + 1} - M ${msnIndex}",
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'Moulpali',
            fontFamilyFallback: ['Moulpali'],
            fontSize: 22.0,
            color: Colors.black,
          ),
        ),
        position: Vector2(size.x * 0.5, size.y * 0.35),
        anchor: Anchor.center,
      );
      add(levelLabel);

      // Stars based on rating (centered)
      final levelIconSvg = await Svg.load('Heart_failed.svg');
      levelIcon = SvgComponent(
        svg: levelIconSvg,
        size: size / 4,
        position: Vector2(size.x * 0.5, size.y * 0.45),
        anchor: Anchor.center,
      );
      add(levelIcon);

      final label = TextComponent(
        text: i18n.t('almost_there'),
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'Moulpali',
            fontFamilyFallback: ['Moulpali'],
            fontSize: 22.0,
            color: Colors.black,
          ),
        ),
        position: Vector2(size.x * 0.5, size.y * 0.55),
        anchor: Anchor.center,
      );
      add(label);

      final label2 = TextComponent(
        text: i18n.t('resume_description'),
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'Moulpali',
            fontFamilyFallback: ['Moulpali'],
            fontSize: 22.0,
            color: Colors.black,
          ),
        ),
        position: Vector2(size.x * 0.5, size.y * 0.58),
        anchor: Anchor.center,
      );
      add(label2);

      // bottom area button row
      final buttonX = size.x * 0.2;
      final buttonY = size.y * 0.60;
      final buttonSpacing = size.x * 0.25;

      final menuButton = SvgButton(
        assetPath: 'Menu_basic.svg',
        size: size / 8,
        position: Vector2(buttonX, buttonY),
        onTap: onMenu,
      );
      add(menuButton);

      final continueButton = SvgButton(
        assetPath: 'Continue_basic.svg',
        size: size / 8,
        position: Vector2(buttonX + buttonSpacing, buttonY),
        onTap: onContinue,
      );
      add(continueButton);

      final retryButton = SvgButton(
        assetPath: 'Retry_default.svg',
        size: size / 8,
        position: Vector2(buttonX + buttonSpacing * 2, buttonY),
        onTap: onRetry,
      );
      add(retryButton);
    } catch (e) {
      print('Error loading fail aftermath : $e');
    }
  }

  String _addStars() {
    // temporary code while not scoring - if we starts scoring, will try sth else
    if (starCount == 0) {
      starCount = 3;
    }

    String ret;
    switch (starCount) {
      case 1:
        ret = 'Type=1 star.svg';
        break;
      case 2:
        ret = 'Type=2 star.svg';
        break;
      case 3:
        ret = 'Type=all star.svg';
        break;
      default:
        ret = 'Type=all star.svg';
        break;
    }

    print('score file name : $ret');
    return ret;
  }
}

// Custom SVG Button Component
class SvgButtonComponent extends PositionComponent with TapCallbacks {
  final Svg? svg;
  final VoidCallback onTap;
  final String? fallbackText;

  SvgButtonComponent({
    required this.svg,
    required this.onTap,
    required Vector2 position,
    required Anchor anchor,
  }) : fallbackText = null,
        super(position: position, anchor: anchor);

  SvgButtonComponent.fallback({
    required Vector2 position,
    required this.onTap,
    required this.fallbackText,
  }) : svg = null,
        super(position: position, anchor: Anchor.center, size: Vector2(120, 50));

  @override
  Future<void> onLoad() async {
    if (svg != null) {
      final svgComponent = SvgComponent(
        svg: svg,
        size: size,
        position: position,
      ); // SvgComponent
      add(svgComponent);

      size = svgComponent.size;
    } else if (fallbackText != null) {
      // Create fallback button
      final background = RectangleComponent(
        size: size,
        paint: Paint()..color = Colors.blue,
      );
      add(background);

      final text = TextComponent(
        text: fallbackText!,
        textRenderer: TextPaint(
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        anchor: Anchor.center,
        position: size / 2,
      );
      add(text);
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    onTap();
  }
}