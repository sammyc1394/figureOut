
import 'package:figureout/src/components/svgButton.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';

import 'OneSecondGame.dart';
import 'config.dart';

class AftermathScreen extends PositionComponent with TapCallbacks {

  // results
  final StageResult result;
  late final int starCount;
  late final int stgIndex;

  // ui svgs
  late final SvgComponent background;
  late final SvgComponent levelStatus;
  late final SvgComponent menuButton;
  late final SvgComponent retryButton; // retry(if failed) or continue(if success)
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
  }) : super(
    position: Vector2.zero(),
    size: screenSize,
  );

  @override
  Future<void> onLoad() async {

    if(result == StageResult.success) {
      await _loadSuccessScreen();
    } else {
      await _loadFailScreen();
    }
  }

  Future<void> _loadSuccessScreen() async {
    try {

      final bgSvg = await Svg.load('bg.svg');
      background = SvgComponent(
        svg: bgSvg,
        size: size,
        position: Vector2.zero(),
      );
      add(background);

      final statusSvg = await Svg.load('Type=Level complete.svg');
      levelStatus = SvgComponent(
        svg: statusSvg,
        size: size/2,
        position: Vector2(size.x * 0.5, size.y * 0.2),
        anchor: Anchor.center,
      );
      add(levelStatus);

      // Stars based on rating (centered)
      String starSvgTitle = _addStars();
      final levelIconSvg = await Svg.load(starSvgTitle);
      levelIcon = SvgComponent(
        svg: levelIconSvg,
        size: size/4,
        position: Vector2(size.x * 0.5, size.y * 0.5),
        anchor: Anchor.center,
      );
      add(levelIcon);

      // bottom area button row
      final buttonX = size.x * 0.2;
      final buttonY = size.y * 0.75;
      final buttonSpacing = size.x * 0.25;

      final menuButton = SvgButton(assetPath: 'State=Default, Type=Menu.svg',
          size: size/8,
          position: Vector2(buttonX, buttonY),
          onTap: onMenu);
      add(menuButton);

      final retryButton = SvgButton(assetPath: 'State=Default, Type=Retry.svg',
          size: size/8,
          position: Vector2(buttonX + buttonSpacing, buttonY),
          onTap: onRetry);
      add(retryButton);

      final playNextButton = SvgButton(assetPath: 'State=Default, Type=Play.svg',
          size: size/8,
          position: Vector2(buttonX + buttonSpacing * 2, buttonY),
          onTap: onPlay);
      add(playNextButton);

    } catch (e) {
      print('Error loading success aftermath : $e');
    }
  }

  Future<void> _loadFailScreen() async {
    try {



      final bgSvg = await Svg.load('bg.svg');
      background = SvgComponent(
        svg: bgSvg,
        size: size,
        position: Vector2.zero(),
      );
      add(background);

      final statusSvg = await Svg.load('Type=Level complete.svg');
      levelStatus = SvgComponent(
        svg: statusSvg,
        size: size/2,
        position: Vector2(size.x * 0.5, size.y * 0.2),
        anchor: Anchor.center,
      );
      add(levelStatus);

      // Stars based on rating (centered)
      String starSvgTitle = _addStars();
      final levelIconSvg = await Svg.load(starSvgTitle);
      levelIcon = SvgComponent(
        svg: levelIconSvg,
        size: size/4,
        position: Vector2(size.x * 0.5, size.y * 0.5),
        anchor: Anchor.center,
      );
      add(levelIcon);

      // bottom area button row
      final buttonX = size.x * 0.2;
      final buttonY = size.y * 0.75;
      final buttonSpacing = size.x * 0.25;

      final menuButton = SvgButton(assetPath: 'State=Default, Type=Menu.svg',
          size: size/8,
          position: Vector2(buttonX, buttonY),
          onTap: () {
            print('menuButton Pressed ');
          });
      add(menuButton);

      final retryButton = SvgButton(assetPath: 'State=Default, Type=Retry.svg',
          size: size/8,
          position: Vector2(buttonX + buttonSpacing, buttonY),
          onTap: () {
            print('retry Pressed ');
          });
      add(retryButton);

      final playNextButton = SvgButton(assetPath: 'State=Default, Type=Play.svg',
          size: size/8,
          position: Vector2(buttonX + buttonSpacing * 2, buttonY),
          onTap: () {
            print('play next Pressed ');
          });
      add(playNextButton);


    } catch (e) {
      print('Error loading fail aftermath : $e');
    }
  }

  Future<SvgButtonComponent> _createSvgButton(
      String svgPath,
      Vector2 position,
      VoidCallback onTap
      ) async {
    try {
      final svg = await Svg.load(svgPath);
      return SvgButtonComponent(
        svg: svg,
        position: position,
        anchor: Anchor.center,
        onTap: onTap,
      );
    } catch (e) {
      print('Error loading button SVG $svgPath: $e');

      // TODO : temporary - to be removed
      String text = svgPath.split(',').last.split('=').last.split('.').first.toUpperCase();
      print('button text = $text');

      // Fallback to simple rectangle button
      return SvgButtonComponent.fallback(
        position: position,
        onTap: onTap,
        fallbackText: svgPath.split(',').last.split('=').last.split('.').first.toUpperCase(),
      );
    }
  }

  String _addStars() {
    // temporary code while not scoring - if we starts scoring, will try sth else
    if(starCount == 0) {
      starCount = 3;
    }

    String ret;
    switch (starCount) {
      case 1 :
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
  })
      : fallbackText = null,
        super(position: position, anchor: anchor);

  SvgButtonComponent.fallback({
    required Vector2 position,
    required this.onTap,
    required this.fallbackText,
  })
      : svg = null,
        super(
        position: position,
        anchor: Anchor.center,
        size: Vector2(120, 50),
      );

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
        paint: Paint()
          ..color = Colors.blue,
      );
      add(background);

      final text = TextComponent(
        text: fallbackText!,
        textRenderer: TextPaint(
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
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

extension AftermathScreenExtensions on OneSecondGame {

  // Method to show aftermath screen with SVG assets
  void showAftermathScreen(StageResult result, int starCount, int stgIndex) {

    print('stage done : starting aftermath screen');

    final aftermathScreen = AftermathScreen(
      result: result,
      starCount: starCount,
      screenSize: size,
      onContinue: () => _handleContinue(),
      onRetry: () => _handleRetry(),
      onMenu: () => _handleMenu(),
      onPlay: () => _handleNextLevel(),
      stgIndex: stgIndex,
    );

    add(aftermathScreen);
  }

  void _handleContinue() {
    _removeAftermathScreen();
    // Continue with current progress
    refreshGame();
  }

  void _handleRetry() {
    _removeAftermathScreen();
    // Retry current stage
    refreshGame();
  }

  void _handleMenu() {
    _removeAftermathScreen();
    // Go to main menu (implement your menu logic)
    print("Going to menu...");

    // Todo : change it to move to main stage
    refreshGame();
  }

  void _handleNextLevel() {
    _removeAftermathScreen();
    // Load next level (implement your level progression logic)
    print("Loading next level...");
    refreshGame(); // or load next stage
  }

  void _removeAftermathScreen() {
    children.whereType<AftermathScreen>().forEach((screen) {
      screen.removeFromParent();
    });
  }
}
