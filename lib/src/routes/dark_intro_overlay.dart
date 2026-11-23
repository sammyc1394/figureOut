import 'package:flutter/material.dart';

import 'package:figureout/src/config/config.dart';
import 'package:figureout/src/routes/tutorial_demos.dart';

/// Black-shapes intro shown once at the start of stage 1 mission 2.
class DarkIntroOverlay extends StatelessWidget {
  const DarkIntroOverlay({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final fontSize = MediaQuery.of(context).size.width * 0.048;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onContinue,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.65),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: darkDemo(),
              ),
              const Spacer(),
              Text(
                i18n.t('howto_tap_to_play'),
                style: TextStyle(
                  fontFamily: appFontFamily,
                  fontSize: fontSize * 2,
                  fontWeight: FontWeight.w200,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: fontSize * 3),
            ],
          ),
        ),
      ),
    );
  }
}
