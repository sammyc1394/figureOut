import 'package:flutter/material.dart';

import 'package:figureout/src/config/config.dart';
import 'package:figureout/src/config/theme_mode_scope.dart';
import 'package:figureout/src/routes/tutorial_demos.dart';

/// In-game intro that plays tutorial demos one after another (tap for the
/// next one), in the same look as the tutorial screen.
class TutorialIntroOverlay extends StatefulWidget {
  const TutorialIntroOverlay({
    super.key,
    required this.demos,
    required this.onContinue,
  });

  final List<TutorialDemo> demos;
  final VoidCallback onContinue;

  @override
  State<TutorialIntroOverlay> createState() => _TutorialIntroOverlayState();
}

class _TutorialIntroOverlayState extends State<TutorialIntroOverlay> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ThemeModeScope.of(context);
    final fontSize = MediaQuery.of(context).size.width * 0.048;
    final last = _page == widget.demos.length - 1;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => last ? widget.onContinue() : setState(() => _page++),
      child: ColoredBox(
        color: Color(isDarkMode ? darkBgColor : bgColor),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: KeyedSubtree(
                  key: ValueKey(_page),
                  child: widget.demos[_page],
                ),
              ),
              const Spacer(),
              Text(
                i18n.t(last ? 'howto_tap_to_play' : 'tutorial_tap_next'),
                style: TextStyle(
                  fontFamily: appFontFamily,
                  fontSize: fontSize * 1.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFED613D),
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
