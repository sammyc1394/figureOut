import 'dart:math' as math;

import 'package:figureout/src/functions/svgButton.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/text.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';

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
    add(
      RectangleComponent(
        size: size,
        paint: Paint()..color = Colors.black.withValues(alpha: 0.52),
      ),
    );

    if (result == StageResult.success) {
      await _loadSuccessScreen();
    } else {
      await _loadFailScreen();
    }
  }

  Future<void> _loadSuccessScreen() async {
    final layout = await _loadPanelScaffold();

    final starSvgTitle = _addStars();
    final starSvg = await Svg.load(starSvgTitle);
    background.add(
      SvgComponent(
        svg: starSvg,
        size: layout.p(0.50, 0.23),
        position: layout.p(0.5, 0.31),
        anchor: Anchor.center,
      ),
    );

    _addCenteredLabel('Completed!', layout.p(0.5, 0.61), layout.scaleFont(24));
    _addBottomActions(layout, centerLabel: 'Next', onCenterTap: onPlay);
  }

  Future<void> _loadFailScreen() async {
    try {
      final layout = await _loadPanelScaffold();

      final levelIconSvg = await Svg.load('Heart_failed.svg');
      levelIcon = SvgComponent(
        svg: levelIconSvg,
        size: layout.sq(0.23),
        position: layout.p(0.5, 0.29),
        anchor: Anchor.center,
      );
      background.add(levelIcon);

      _addCenteredLabel(
        'Almost there!',
        layout.p(0.5, 0.54),
        layout.scaleFont(24),
      );
      _addCenteredLabel(
        'Continue from where you left off.',
        layout.p(0.5, 0.64),
        layout.scaleFont(16),
      );
      _addBottomActions(
        layout,
        centerLabel: 'Continue',
        showAdBadge: true,
        onCenterTap: onContinue,
      );
    } catch (e) {
      debugPrint('Error loading fail aftermath : $e');
    }
  }

  Future<_AftermathLayout> _loadPanelScaffold() async {
    const svgWidth = 349.0;
    const svgHeight = 308.0;

    final maxPanelWidth = size.x < 700 ? size.x * 0.84 : 460.0;
    final maxPanelHeight = size.y < 700 ? size.y * 0.58 : 406.0;
    final scale = math.min(
      maxPanelWidth / svgWidth,
      maxPanelHeight / svgHeight,
    );
    final renderSize = Vector2(svgWidth * scale, svgHeight * scale);

    background = SvgComponent(
      svg: await Svg.load('menu/common/bg.svg'),
      size: renderSize,
      position: Vector2(size.x * 0.5, size.y * 0.58),
      anchor: Anchor.center,
    );
    add(background);

    final layout = _AftermathLayout(background.size);
    final banner = _RibbonBannerComponent(
      stageLabel: '${stgIndex + 1}-$msnIndex',
      size: layout.p(1.14, 0.31),
      position: layout.p(0.5, -0.03),
      fontSize: layout.scaleFont(26),
    );
    background.add(banner);

    return layout;
  }

  void _addBottomActions(
    _AftermathLayout layout, {
    required String centerLabel,
    required VoidCallback onCenterTap,
    bool showAdBadge = false,
  }) {
    background.add(
      SvgButton(
        assetPath: 'Exit_basic.svg',
        size: layout.sq(0.12),
        position: layout.p(0.14, 0.78),
        onTap: onMenu,
      ),
    );

    background.add(
      _AftermathPillButton(
        label: centerLabel,
        showAdBadge: showAdBadge,
        size: layout.p(0.47, 0.15),
        position: layout.p(0.5, 0.855),
        onTap: onCenterTap,
      ),
    );

    background.add(
      SvgButton(
        assetPath: 'Retry_default.svg',
        size: layout.sq(0.12),
        position: layout.p(0.76, 0.78),
        onTap: onRetry,
      ),
    );
  }

  void _addCenteredLabel(String text, Vector2 position, double fontSize) {
    background.add(
      TextComponent(
        text: text,
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: appFontFamily,
            fontFamilyFallback: fallbackFontFamily,
            fontSize: fontSize,
            color: const Color(0xFF222222),
            fontWeight: FontWeight.bold,
          ),
        ),
        anchor: Anchor.center,
        position: position,
      ),
    );
  }

  String _addStars() {
    // temporary code while not scoring - if we starts scoring, will try sth else
    final effectiveStar = starCount == 0 ? 3 : starCount;

    String ret = "menu/mission/";
    switch (effectiveStar) {
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

    debugPrint('score file name : $ret');
    return ret;
  }
}

class _RibbonBannerComponent extends PositionComponent {
  final String stageLabel;
  final double fontSize;

  _RibbonBannerComponent({
    required this.stageLabel,
    required super.size,
    required super.position,
    required this.fontSize,
  }) : super(anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    add(
      TextComponent(
        text: stageLabel,
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: appFontFamily,
            fontFamilyFallback: fallbackFontFamily,
            fontSize: fontSize,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        anchor: Anchor.center,
        position: Vector2(size.x * 0.5, size.y * 0.42),
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final sidePaint = Paint()..color = const Color(0xFF75A8C9);
    final facePaint = Paint()..color = const Color(0xFF7FB1D0);
    final shadowPaint = Paint()..color = const Color(0x33000000);
    final center = Rect.fromLTWH(
      size.x * 0.17,
      size.y * 0.14,
      size.x * 0.66,
      size.y * 0.56,
    );
    final leftTail = Path()
      ..moveTo(size.x * 0.01, size.y * 0.28)
      ..lineTo(size.x * 0.20, size.y * 0.28)
      ..lineTo(size.x * 0.17, size.y * 0.50)
      ..lineTo(size.x * 0.20, size.y * 0.72)
      ..lineTo(size.x * 0.01, size.y * 0.72)
      ..lineTo(size.x * 0.05, size.y * 0.50)
      ..close();
    final rightTail = Path()
      ..moveTo(size.x * 0.99, size.y * 0.28)
      ..lineTo(size.x * 0.80, size.y * 0.28)
      ..lineTo(size.x * 0.83, size.y * 0.50)
      ..lineTo(size.x * 0.80, size.y * 0.72)
      ..lineTo(size.x * 0.99, size.y * 0.72)
      ..lineTo(size.x * 0.95, size.y * 0.50)
      ..close();

    canvas.drawPath(leftTail, sidePaint);
    canvas.drawPath(rightTail, sidePaint);
    canvas.drawRect(
      Rect.fromLTWH(
        center.left,
        center.bottom - size.y * 0.04,
        center.width,
        size.y * 0.05,
      ),
      shadowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(center, Radius.circular(size.y * 0.04)),
      facePaint,
    );
  }
}

class _AftermathPillButton extends PositionComponent with TapCallbacks {
  final String label;
  final bool showAdBadge;
  final VoidCallback onTap;

  _AftermathPillButton({
    required this.label,
    required this.showAdBadge,
    required super.size,
    required super.position,
    required this.onTap,
  }) : super(anchor: Anchor.center);

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    final radius = Radius.circular(size.y * 0.45);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = const Color(0xFF86B9D7),
    );

    final textStart = size.x * 0.62;
    if (showAdBadge) {
      final badge = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.x * 0.14,
          size.y * 0.22,
          size.x * 0.20,
          size.y * 0.56,
        ),
        Radius.circular(size.y * 0.12),
      );
      canvas.drawRRect(badge, Paint()..color = const Color(0xFF222222));
      _paintText(
        canvas,
        'AD',
        Offset(size.x * 0.24, size.y * 0.50),
        size.y * 0.34,
        Colors.white,
      );
    } else {
      final play = Path()
        ..moveTo(size.x * 0.28, size.y * 0.30)
        ..lineTo(size.x * 0.28, size.y * 0.70)
        ..lineTo(size.x * 0.42, size.y * 0.50)
        ..close();
      canvas.drawPath(play, Paint()..color = Colors.white);
    }

    _paintText(
      canvas,
      label,
      Offset(textStart, size.y * 0.50),
      size.y * 0.42,
      Colors.white,
    );
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: appFontFamily,
          fontFamilyFallback: fallbackFontFamily,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  void onTapUp(TapUpEvent event) {
    onTap();
    super.onTapUp(event);
  }
}

class _AftermathLayout {
  final Vector2 panelSize;

  const _AftermathLayout(this.panelSize);

  Vector2 p(double xPct, double yPct) {
    return Vector2(panelSize.x * xPct, panelSize.y * yPct);
  }

  Vector2 sq(double sidePct) {
    return Vector2.all(panelSize.x * sidePct);
  }

  double scaleFont(double designFontSize) {
    return designFontSize * (panelSize.x / 349.0);
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
