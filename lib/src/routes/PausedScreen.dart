
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
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 45),
            decoration: BoxDecoration(
              color: const Color(0xFF7BA6C5),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: onMenu,
                  child: Image.asset(
                    'assets/Home_button_beige.png',
                    width: 44,
                    height: 44,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: onResume,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5EDD8),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/Resume_button_icon.png',
                          width: 22,
                          height: 22,
                          // color: const Color(0xFF555555),
                          colorBlendMode: BlendMode.srcIn,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Resume',
                          style: TextStyle(
                            fontFamily: appFontFamily,
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF555555),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: onRetry,
                  child: Image.asset(
                    'assets/Replay_button beige.png',
                    width: 44,
                    height: 44,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
