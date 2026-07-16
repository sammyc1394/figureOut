
import 'dart:ui';
import 'package:figureout/src/config.dart';
import 'package:flutter/material.dart';

class PauseOverlayWidget extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  const PauseOverlayWidget({
    super.key,
    required this.onResume,
    required this.onRetry,
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
            builder: (context, constraints) {
              final boxW = constraints.maxWidth * 0.85;
              final boxH = boxW * 0.45;
              final iconSize = boxW * 0.12;
              final resumeW = boxW * 0.50;
              final gap = boxW * 0.05;

              return SizedBox(
                width: boxW,
                height: boxH,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      'assets/Pasued_box.png',
                      width: boxW,
                      height: boxH,
                      fit: BoxFit.fill,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: onMenu,
                          child: Image.asset(
                            'assets/Home_button_beige.png',
                            width: iconSize,
                            height: iconSize,
                          ),
                        ),
                        SizedBox(width: gap),
                        GestureDetector(
                          onTap: onResume,
                          child: Container(
                            width: resumeW,
                            height: boxW * 0.14,
                            padding: EdgeInsets.symmetric(horizontal: resumeW * 0.08),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE4E0D3),
                              borderRadius: BorderRadius.all(Radius.circular(999)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  color: const Color(0xFF7BA6C5),
                                  size: boxW * 0.09,
                                ),
                                SizedBox(width: resumeW * 0.04),
                                Text(
                                  i18n.t('resume'),
                                  style: TextStyle(
                                    fontFamily: appFontFamily,
                                    fontSize: boxW * 0.055,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF232323),
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: gap),
                        GestureDetector(
                          onTap: onRetry,
                          child: Image.asset(
                            'assets/Replay_button beige.png',
                            width: iconSize,
                            height: iconSize,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
