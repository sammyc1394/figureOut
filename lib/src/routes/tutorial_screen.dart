import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:figureout/main.dart' show cachedStages;
import 'package:figureout/src/config/config.dart';
import 'package:figureout/src/config/theme_mode_scope.dart';
import 'package:figureout/src/routes/tutorial_demos.dart';

const _accent = Color(0xFFED613D);

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ThemeModeScope.of(context);
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: Color(isDarkMode ? darkBgColor : bgColor),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Image.asset(
                        'assets/Back_button_beige.png',
                        width: 37,
                        height: 37,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      i18n.t('settings_tutorial'),
                      style: TextStyle(
                        fontFamily: appFontFamily,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                indicatorColor: _accent,
                labelColor: textColor,
                unselectedLabelColor: textColor.withValues(alpha: 0.45),
                labelStyle: TextStyle(
                  fontFamily: appFontFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: TextStyle(
                  fontFamily: appFontFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                tabs: [
                  Tab(text: i18n.t('tutorial_section_shapes')),
                  Tab(text: i18n.t('tutorial_section_dark')),
                  Tab(text: i18n.t('tutorial_section_move')),
                  Tab(text: i18n.t('tutorial_section_timer')),
                  Tab(text: i18n.t('tutorial_section_order')),
                ],
              ),
              Expanded(
                // Tabs change by tapping only; swiping belongs to the demo pager.
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _DemoPager(demos: shapeDemos()),
                    _DemoPager(demos: darkDemos()),
                    _DemoPager(demos: movementDemos()),
                    _DemoPager(demos: timerDemos()),
                    _DemoPager(demos: orderDemos(), isLastTab: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows one demo at a time; swipe to go to the next one.
class _DemoPager extends StatefulWidget {
  const _DemoPager({required this.demos, this.isLastTab = false});

  final List<TutorialDemo> demos;
  final bool isLastTab;

  @override
  State<_DemoPager> createState() => _DemoPagerState();
}

class _DemoPagerState extends State<_DemoPager> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // The hint shows again after the next cycle ends.
  void _resetHints() {
    for (final d in widget.demos) {
      d.ended.value = false;
    }
  }

  // Tapping blank space goes to the next demo.
  void _next() {
    final count = widget.demos.length;
    final onLast = count < 2 || _page == count - 1;
    _resetHints();
    // End of the last tab: go play stage 1.
    if (onLast && widget.isLastTab) {
      if (cachedStages.isEmpty) return;
      context.go('/stages', extra: cachedStages);
      return;
    }
    // On the last demo, move on to the next tutorial tab.
    if (onLast) {
      final tabs = DefaultTabController.of(context);
      tabs.animateTo((tabs.index + 1) % tabs.length);
      return;
    }
    _controller.animateToPage(
      (_page + 1) % count,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ThemeModeScope.of(context);
    final dotColor = isDarkMode ? Colors.white : Colors.black;
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _next,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _controller,
                  itemCount: widget.demos.length,
                  onPageChanged: (i) {
                    _resetHints();
                    setState(() => _page = i);
                  },
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(child: widget.demos[i]),
                  ),
                ),
                // Between the caption and the dots; stays once the first cycle ends.
                Align(
                  alignment: const Alignment(0, 0.72),
                  child: IgnorePointer(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: widget.demos[_page].ended,
                      builder: (context, ended, _) => Opacity(
                        opacity: ended ? 1 : 0,
                        child: Text(
                          i18n.t(
                            widget.isLastTab && _page == widget.demos.length - 1
                                ? 'tutorial_go_game'
                                : 'tutorial_tap_next',
                          ),
                          style: TextStyle(
                            fontFamily: appFontFamily,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.demos.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.demos.length; i++)
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _page ? _accent : dotColor.withValues(alpha: 0.2),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}
