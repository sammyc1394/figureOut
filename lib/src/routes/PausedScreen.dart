
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
    final isKr = Localizations.localeOf(context).languageCode == 'ko';

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
                          child: Image.asset(
                            isKr
                                ? 'assets/kr_resume_button.png'
                                : 'assets/resume_button.png',
                            width: resumeW,
                            fit: BoxFit.contain,
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
