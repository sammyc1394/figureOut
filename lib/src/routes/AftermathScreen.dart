import 'dart:ui';

import 'package:figureout/src/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AftermathOverlayWidget extends StatelessWidget {
  final StageResult result;
  final int starCount;
  final int stgIndex;
  final int msnIndex;
  final VoidCallback onContinue;
  final VoidCallback onRetry;
  final VoidCallback onPlay;
  final VoidCallback onMenu;

  const AftermathOverlayWidget({
    super.key,
    required this.result,
    required this.starCount,
    required this.stgIndex,
    required this.msnIndex,
    required this.onContinue,
    required this.onRetry,
    required this.onPlay,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final isKr = Localizations.localeOf(context).languageCode == 'ko';

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Container(
        color: Colors.black.withValues(alpha: 0.25),
        child: Center(
          child: LayoutBuilder(
              builder:(context, constraints) {
                final base = constraints.biggest.shortestSide;

                final panelWidth = base * 0.97;
                final panelHeight = panelWidth * (550 / 600);

                return SizedBox(
                  width: panelWidth,
                  height: panelHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          'assets/Results_box.png',
                          fit: BoxFit.fill,
                        ),
                      ),
                      _stageLabel(panelWidth, panelHeight),
                      if (result == StageResult.success) ...[
                        _stars(panelWidth, panelHeight),
                        _completedText(panelWidth, panelHeight),
                      ] else ...[
                        _heart(panelWidth, panelHeight),
                        _failTexts(panelWidth, panelHeight),
                      ],
                      _buttons(panelWidth, panelHeight, isKr),
                    ],
                  ),
                );
              }
          ),
        ),
      ),
    );
  }

  Widget _stageLabel(double w, double h) {
    return Positioned(
      top: h * 0.04,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          '${stgIndex + 1}-$msnIndex',
          style: TextStyle(
            fontFamily: appFontFamily,
            fontSize: h * 0.10,
            fontWeight: FontWeight.w800,
            color: Color(0xFFE4E0D3),
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _stars(double w, double h) {
    return Positioned(
      top: h * 0.25,
      left: 0,
      right: 0,
      child: Center(
        child: Transform.scale(
          scale: 0.85,
          child: Image.asset(
            'assets/StageScreen_threestars.png',
            width: w * 0.70,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _completedText(double w, double h) {
    return Positioned(
      top: h * 0.60,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          'Completed!',
          style: TextStyle(
            fontFamily: appFontFamily,
            fontSize: h * 0.09,
            // fontWeight: FontWeight.bold,
            color: const Color(0xFF222222),
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _heart(double w, double h) {
    return Positioned(
      top: h * 0.3,
      left: 0,
      right: 0,
      child: Center(
        child: Image.asset('assets/Lose_brokenheart.png', height: w * 0.17),
      ),
    );
  }

  Widget _failTexts(double w, double h) {
    return Positioned(
      top: h * 0.5,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Text(
            'Almost there!',
            style: TextStyle(
              fontFamily: appFontFamily,
              fontSize: h * 0.09,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF222222),
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 0.8),
          Text(
            'Continue from where you left off.',
            style: TextStyle(
              fontFamily: appFontFamily,
              fontSize: h * 0.055,
              color: const Color(0xFF222222),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buttons(double w, double h, isKr) {
    // Matches Flame version proportions:
    final btnSize = w * 0.10;
    final pillW = w * 0.47;
    final pillH = h * 0.15;

    return Positioned(
      top: h * 0.775,
      left: w * 0.10,
      right: w * 0.10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onMenu,
            child: Image.asset('assets/Home_button_blue.png', width: btnSize, height: btnSize),
          ),
          GestureDetector(
            onTap: result == StageResult.success ? onPlay : onContinue,
            child: SizedBox(
              width: pillW,
              height: pillH,
              child: result == StageResult.success ?
                Image.asset('assets/next_button.png', width: pillH, height: pillH) :
                isKr ? Image.asset('assets/kr_continue_button.png', width: pillH, height: pillH) :
                        Image.asset('assets/continue_button.png', width: pillH, height: pillH)
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Image.asset('assets/Replay_button_blue.png', width: btnSize, height: btnSize),
          ),
        ],
      ),
    );
  }
}
