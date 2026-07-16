import 'dart:ui';

import 'package:figureout/src/config.dart';
import 'package:flutter/material.dart';

class NoHeartsOverlay extends StatelessWidget {
  final VoidCallback onOk;

  const NoHeartsOverlay({super.key, required this.onOk});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = screenWidth * 0.84;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: SizedBox.expand(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.25),
          child: Center(
            child: Container(
              width: panelWidth,
              padding: EdgeInsets.symmetric(
                vertical: panelWidth * 0.09,
                horizontal: panelWidth * 0.09,
              ),
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/StageScreen_box.png'),
                  fit: BoxFit.fill,
                ),
              ),
              // 텍스트 길이(언어별)에 따라 카드 높이가 자연스럽게 늘어나도록
              // 절대 좌표 대신 Column으로 배치해 버튼과 절대 겹치지 않게 한다.
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/Lose_brokenheart.png', height: panelWidth * 0.20),
                  SizedBox(height: panelWidth * 0.06),
                  Text(
                    i18n.t('hearts_depleted_title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: appFontFamily,
                      fontSize: panelWidth * 0.084,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF222222),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  SizedBox(height: panelWidth * 0.02),
                  Text(
                    i18n.t('hearts_refill_description'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: appFontFamily,
                      fontSize: panelWidth * 0.062,
                      color: const Color(0xFF222222),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  SizedBox(height: panelWidth * 0.08),
                  GestureDetector(
                    onTap: onOk,
                    child: Container(
                      width: panelWidth * 0.47,
                      height: panelWidth * 0.145,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7BA6C5),
                        borderRadius: BorderRadius.circular(panelWidth * 0.145 * 0.45),
                      ),
                      child: Center(
                        child: Text(
                          'OK',
                          style: TextStyle(
                            fontFamily: appFontFamily,
                            fontSize: panelWidth * 0.145 * 0.50,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
