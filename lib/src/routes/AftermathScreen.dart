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
                      _buttons(panelWidth, panelHeight),
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
      left: w * 0.08,
      right: w * 0.08,
      child: Center(
        child: Text(
          i18n.t('level_completed'),
          textAlign: TextAlign.center,
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
      left: w * 0.08,
      right: w * 0.08,
      child: Column(
        children: [
          Text(
            i18n.t('almost_there'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: appFontFamily,
              fontSize: h * 0.09,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF222222),
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            i18n.t('resume_description'),
            textAlign: TextAlign.center,
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
            child: result == StageResult.success
                ? SizedBox(
                    width: pillW,
                    height: pillH,
                    child: Image.asset('assets/next_button.png', width: pillH, height: pillH),
                  )
                : _continueButton(pillW, pillH),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Image.asset('assets/Replay_button_blue.png', width: btnSize, height: btnSize),
          ),
        ],
      ),
    );
  }

  Widget _continueButton(double pillW, double pillH) {
    return Container(
      width: pillW,
      height: pillH,
      padding: EdgeInsets.symmetric(horizontal: pillW * 0.06),
      decoration: BoxDecoration(
        color: const Color(0xFF7BA6C5),
        borderRadius: BorderRadius.circular(pillH / 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: pillH * 0.16, vertical: pillH * 0.08),
            decoration: BoxDecoration(
              color: const Color(0xFF232323),
              borderRadius: BorderRadius.circular(pillH * 0.15),
            ),
            child: Text(
              'AD',
              style: TextStyle(
                fontFamily: appFontFamily,
                fontSize: pillH * 0.3,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          SizedBox(width: pillW * 0.05),
          Flexible(
            child: Text(
              i18n.t('continue'),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: appFontFamily,
                fontSize: pillH * 0.42,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE4E0D3),
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
