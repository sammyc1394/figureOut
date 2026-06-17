import 'dart:ui';

import 'package:figureout/src/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AftermathOverlayWidget extends StatelessWidget {
  final StageResult result;
  final int starCount;
  final int stgIndex;
  final int msnIndex;
  final bool isEndOfGame;
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
    required this.isEndOfGame,
    required this.onContinue,
    required this.onRetry,
    required this.onPlay,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = screenWidth * 0.84;
    final panelHeight = panelWidth * (550 / 600);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Container(
        color: Colors.black.withValues(alpha: 0.25),
        child: Center(
          child: SizedBox(
            width: panelWidth,
            height: panelHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Image.asset('assets/Results_box.png', fit: BoxFit.fill),
                ),
                _stageLabel(panelWidth, panelHeight),
                if (result == StageResult.success) ...[
                  _stars(panelWidth, panelHeight),
                  _completedText(panelWidth, panelHeight),
                ] else ...[
                  _heart(panelWidth, panelHeight),
                  _failTexts(panelWidth, panelHeight),
                ],
                _buttons(panelWidth, panelHeight),
              ],
            ),
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
      top: h * 0.28,
      left: w * 0.15,
      right: w * 0.15,
      child: Image.asset('assets/StageScreen_threestars.png', fit: BoxFit.fitWidth),
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
            fontWeight: FontWeight.bold,
            color: const Color(0xFF222222),
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _heart(double w, double h) {
    return Positioned(
      top: h * 0.25,
      left: 0,
      right: 0,
      child: Center(
        child: Image.asset('assets/Lose_brokenheart.png', height: w * 0.17),
      ),
    );
  }

  Widget _failTexts(double w, double h) {
    return Positioned(
      top: h * 0.47,
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
          const SizedBox(height: 6),
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

  Widget _buttons(double w, double h) {
    // Matches Flame version proportions:
    // side buttons: sq(0.12) at x=0.08/0.80, y=0.78 (top-left anchor)
    // pill: p(0.47, 0.15) centered at p(0.5, 0.85)
    final btnSize = w * 0.12;
    final pillW = w * 0.47;
    final pillH = h * 0.15;

    return Positioned(
      top: h * 0.775,
      left: w * 0.08,
      right: w * 0.08,
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
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF7BA6C5),
                  borderRadius: BorderRadius.circular(pillH * 0.45),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: result == StageResult.success
                      ? (isEndOfGame
                          // TODO: 에셋 추가 시 이 블록을 Finish/Complete 버튼으로 교체
                          ? [
                              Text(
                                'Finish',
                                style: TextStyle(
                                  fontFamily: appFontFamily,
                                  fontSize: pillH * 0.55,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE4E0D3),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ]
                          : [
                              Image.asset('assets/Next_button_icon.png', width: pillH * 0.6, height: pillH * 0.6),
                              SizedBox(width: pillW * 0.04),
                              Text(
                                'Next',
                                style: TextStyle(
                                  fontFamily: appFontFamily,
                                  fontSize: pillH * 0.55,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE4E0D3),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ])
                      : [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: pillW * 0.04, vertical: pillH * 0.12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF222222),
                              borderRadius: BorderRadius.circular(pillH * 0.12),
                            ),
                            child: Text(
                              'AD',
                              style: TextStyle(
                                fontFamily: appFontFamily,
                                fontSize: pillH * 0.40,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          SizedBox(width: pillW * 0.04),
                          Text(
                            'Continue',
                            style: TextStyle(
                              fontFamily: appFontFamily,
                              fontSize: pillH * 0.50,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                ),
              ),
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
