import 'dart:ui';

import 'package:figureout/src/config.dart';
import 'package:flutter/material.dart';

class NoHeartsOverlay extends StatelessWidget {
  final VoidCallback onOk;

  const NoHeartsOverlay({super.key, required this.onOk});

  // Results_box.png 상단 리본이 전체 이미지 높이의 약 15%를 차지함.
  // 이미지를 위로 밀고 ClipRect으로 리본 영역을 잘라낸다.
  static const double _ribbonFrac = 0.24;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = screenWidth * 0.84;
    final fullH = panelWidth * (550 / 600); // 원본 이미지 기준 높이
    final visibleH = fullH ; // 리본 제거 후 보이는 높이

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: SizedBox.expand(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.25),
          child: Center(
            child: ClipRect(
              child: SizedBox(
                width: panelWidth,
                height: visibleH,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // 이미지를 ribbonFrac 만큼 위로 밀어 리본을 숨긴다
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: SizedBox(
                        width: panelWidth,
                        height: fullH,
                        child: Image.asset('assets/StageScreen_box.png', fit: BoxFit.fill),
                      ),
                    ),
                    _heartIcon(panelWidth, visibleH),
                    _texts(panelWidth, visibleH),
                    _okButton(panelWidth, visibleH),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _heartIcon(double w, double h) {
    return Positioned(
      top: h * 0.08,
      left: 0,
      right: 0,
      child: Center(
        child: Image.asset('assets/Lose_brokenheart.png', height: w * 0.20),
      ),
    );
  }

  Widget _texts(double w, double h) {
    return Positioned(
      top: h * 0.38,
      left: w * 0.08,
      right: w * 0.08,
      child: Column(
        children: [
          Text(
            'No Hearts Left',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: appFontFamily,
              fontSize: h * 0.10,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF222222),
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your hearts will refill over time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: appFontFamily,
              fontSize: h * 0.062,
              color: const Color(0xFF222222),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _okButton(double w, double h) {
    final pillW = w * 0.47;
    final pillH = h * 0.17;

    return Positioned(
      top: h * 0.74,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: onOk,
          child: SizedBox(
            width: pillW,
            height: pillH,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF7BA6C5),
                borderRadius: BorderRadius.circular(pillH * 0.45),
              ),
              child: Center(
                child: Text(
                  'OK',
                  style: TextStyle(
                    fontFamily: appFontFamily,
                    fontSize: pillH * 0.50,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
