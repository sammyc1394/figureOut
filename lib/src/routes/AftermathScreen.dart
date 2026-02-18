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
  late final String msnTitle;

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
    required this.msnTitle,
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
    // --------------------------
    // bg 로딩
    // --------------------------
    final bgSvg = await Svg.load('menu/common/bg.svg');

    final svgWidth = 349.0;
    final svgHeight = 308.0;

    final scaleX = size.x / svgWidth;
    final scaleY = size.y / svgHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final double marginFactor = 0.92; // 배너 뒤에 배경창이 삐져나가지 않도록

    final renderSize = Vector2(
        svgWidth * scale * marginFactor,
        svgHeight * scale * marginFactor
    );

    background = SvgComponent(
      svg: bgSvg,
      size: renderSize,
      position: size / 2,
      anchor: Anchor.center,
    );

    add(background);

    // --------------------------
    // 좌표 계산 (bg 기준)
    // --------------------------
    Vector2 p(double xPct, double yPct) =>
        Vector2(background.size.x * xPct,
            background.size.y * yPct);

    Vector2 sq(double sidePct) =>
        Vector2.all(background.size.x * sidePct);

    // --------------------------
    // 1) 상단 타이틀
    // --------------------------
    final bannerSvg = await Svg.load('Banner_levelComplete.svg');

    final banner = SvgComponent(
      svg: bannerSvg,
      size: p(1.18, 0.6),
      position: p(0.5,0.02),
      anchor: Anchor.center,
    );

    background.add(banner);

    final titleText = TextComponent(
      text: "S ${stgIndex + 1} - M $msnIndex: ${msnTitle}",
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 24,
          color: Colors.black,
        ),
      ),
      anchor: Anchor.center,
      position: p(0.5, 0.01),
    );
    background.add(titleText);

    // --------------------------
    // 2) 스코어
    // --------------------------
    final starSvgTitle = _addStars();
    final starSvg = await Svg.load(starSvgTitle);

    final starIcon = SvgComponent(
      svg: starSvg,
      size: p(0.6,0.3),
      position: p(0.5, 0.35),
      anchor: Anchor.center,
    );

    background.add(starIcon);

    // --------------------------
    // 3) Level Completed 텍스트
    // --------------------------
    final completedText = TextComponent(
      text: i18n.t('level_completed'),
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 22,
          color: Colors.black,
        ),
      ),
      anchor: Anchor.center,
      position: p(0.5, 0.6),
    );

    background.add(completedText);

    // --------------------------
    // 4) 하단 버튼들
    // --------------------------

    // 좌측 Exit 버튼
    final exitButton = SvgButton(
      assetPath: 'Exit_basic.svg',
      size: sq(0.12),
      position: p(0.10, 0.8),
      onTap: onMenu,
    );

    background.add(exitButton);

    // 중앙 Next 버튼 (가장 강조)
    final nextButton = SvgButton(
      assetPath: 'Next_basic.svg', // 초록 버튼 SVG로 교체 가능
      size: p(0.32, 0.12),
      position: p(0.35, 0.80),
      onTap: onPlay,
    );

    background.add(nextButton);

    // 우측 Retry 버튼
    final retryButton = SvgButton(
      assetPath: 'Retry_default.svg',
      size: sq(0.12),
      position: p(0.8, 0.8),
      onTap: onRetry,
    );

    background.add(retryButton);
  }


  Future<void> _loadFailScreen() async {
    try {
      // --------------------------
      // bg 로딩
      // --------------------------
      final bgSvg = await Svg.load('menu/common/bg.svg');

      final svgWidth = 349.0;
      final svgHeight = 308.0;

      final scaleX = size.x / svgWidth;
      final scaleY = size.y / svgHeight;
      final scale = scaleX < scaleY ? scaleX : scaleY;

      final double marginFactor = 0.92; // 배너 뒤에 배경창이 삐져나가지 않도록

      final renderSize = Vector2(
          svgWidth * scale * marginFactor,
          svgHeight * scale * marginFactor
      );

      background = SvgComponent(
        svg: bgSvg,
        size: renderSize,
        position: size / 2,
        anchor: Anchor.center,
      );

      add(background);

      // --------------------------
      // 좌표 계산 (bg 기준)
      // --------------------------
      Vector2 p(double xPct, double yPct) =>
          Vector2(background.size.x * xPct,
              background.size.y * yPct);

      Vector2 sq(double sidePct) =>
          Vector2.all(background.size.x * sidePct);

      final statusSvg = await Svg.load('Banner_levelFailed.svg');
      levelStatus = SvgComponent(
        svg: statusSvg,
        size: p(1.18, 0.6),
        position: p(0.5,0.02),
        anchor: Anchor.center,
      );
      background.add(levelStatus);
      
      final levelLabel = TextComponent(
        text: "S ${stgIndex + 1} - M ${msnIndex} : ${msnTitle}",
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: appFontFamily,
            fontFamilyFallback: fallbackFontFamily,
            fontSize: 24.0,
            color: Colors.black,
          ),
        ),
        position: p(0.5, 0.01),
        anchor: Anchor.center,
      );
      background.add(levelLabel);

      // Stars based on rating (centered)
      final levelIconSvg = await Svg.load('Heart_failed.svg');
      levelIcon = SvgComponent(
        svg: levelIconSvg,
        size: sq(0.25),
        position:p(0.5, 0.4),
        anchor: Anchor.center,
      );
      background.add(levelIcon);

      final label = TextComponent(
        text: i18n.t('almost_there'),
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: appFontFamily,
            fontFamilyFallback: fallbackFontFamily,
            fontSize: 22.0,
            color: Colors.black,
          ),
        ),
        position: p(0.5,0.55),
        anchor: Anchor.center,
      );
      background.add(label);

      final label2 = TextComponent(
        text: i18n.t('resume_description'),
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: appFontFamily,
            fontFamilyFallback: fallbackFontFamily,
            fontSize: 22.0,
            color: Colors.black,
          ),
        ),
        position: p(0.5,0.62),
        anchor: Anchor.center,
      );
      background.add(label2);

      final menuButton = SvgButton(
        assetPath: 'Exit_basic.svg',
        size: sq(0.10),
        position: p(0.1, 0.8),
        onTap: onMenu,
      );
      background.add(menuButton);

      final continueButton = SvgButton(
        assetPath: 'Continue_basic.svg',
        size: p(0.4, 0.2),
        position: p(0.30, 0.75),
        onTap: onContinue,
      );
      background.add(continueButton);

      final retryButton = SvgButton(
        assetPath: 'Retry_default.svg',
        size: sq(0.10),
        position: p(0.8, 0.8),
        onTap: onRetry,
      );
      background.add(retryButton);

    } catch (e) {
      print('Error loading fail aftermath : $e');
    }
  }

  String _addStars() {
    // temporary code while not scoring - if we starts scoring, will try sth else
    if (starCount == 0) {
      starCount = 3;
    }

    String ret="menu/mission/";
    switch (starCount) {
      case 1:
        ret += 'Star_1.svg';
        break;
      case 2:
        ret += 'Star_2.svg';
        break;
      case 3:
        ret += 'Star_full.svg';
        break;
      default:
        ret += 'Star_full.svg';
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