import 'package:figureout/src/routes/menuAppBar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../functions/sheet_service.dart';
import 'route_args.dart';

class StageSelectScreen extends StatefulWidget {
  final List<StageData> stages;
  final int initialStageIndex;

  const StageSelectScreen({
    super.key,
    required this.stages,
    this.initialStageIndex = 0,
  });

  @override
  State<StageSelectScreen> createState() => _StageSelectScreenState();
}

class _StageSelectScreenState extends State<StageSelectScreen> {
  late int _currentIndex;
  late final PageController _pageController;

  final List<String> stagesSVG = [
    "assets/menu/stage/stage_1.png",
    "assets/menu/stage/stage_2.png",
    "assets/menu/stage/stage_3.png",
    "assets/menu/stage/stage_4.png",
    "assets/menu/stage/stage_5.png",
    "assets/menu/stage/stage_6.png",
    "assets/menu/stage/stage_7.png",
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialStageIndex;
    _pageController = PageController(
      initialPage: widget.initialStageIndex,
      viewportFraction: 0.5,
    );
  }

  @override
  void didUpdateWidget(covariant StageSelectScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // go('/stages') 재진입 시 State가 재사용되면 initState가 다시 호출되지 않으므로,
    // initialStageIndex가 바뀌면 해당 스테이지로 강제 이동시킨다.
    if (widget.initialStageIndex != oldWidget.initialStageIndex &&
        widget.initialStageIndex != _currentIndex) {
      _currentIndex = widget.initialStageIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(widget.initialStageIndex);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stages = widget.stages;

    final size = MediaQuery.sizeOf(context);
    final screenHeight = size.height;
    final shortestSide = size.shortestSide;

    final isTablet = shortestSide >= 600;

    final topGap = screenHeight * 0.012;
    final bottomGap = screenHeight * 0.024;

    final double imageSize =
    (shortestSide * (isTablet ? 0.75 : 0.65)).clamp(220.0, 330.0);
    final imageInnerSize = imageSize * 0.90;

    final stageTitleWidth = imageSize * 0.55;
    final stageTitleHeight = imageSize * 0.18;
    final titleFontSize = (imageSize * 0.10).clamp(18.0, 40.0);

    final indicatorSize = (shortestSide * 0.028).clamp(10.0, 16.0);
    final indicatorGap = shortestSide * 0.010;

    final arrowSize = (shortestSide * 0.095).clamp(36.0, 52.0);
    final rightSpacerWidth = arrowSize + indicatorGap * 2;

    final carouselHeight =
    (screenHeight * (isTablet ? 0.52 : 0.64)).clamp(360.0, isTablet ? 560.0 : 480.0);

    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: const Color(bgColor)),
        ),

        Positioned.fill(
            child: Opacity(
                opacity: 0.50,
              child: Image.asset(
                grainTexture,
                fit: BoxFit.cover,
              ),
            ),
        ),


        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: const Menuappbar(),
          body:
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: topGap),

                  SizedBox(
                    height: carouselHeight,
                    child: PageView.builder(
                      controller: _pageController,
                      clipBehavior: Clip.none,
                      itemCount: stages.length,
                      onPageChanged: (index) {
                        setState(() => _currentIndex = index);
                      },
                      itemBuilder: (context, index) {
                        final svgPath = stagesSVG[index % stagesSVG.length];
                        final isSelected = index == _currentIndex;

                        return GestureDetector(
                          onTap: () {
                            context.push(
                              '/missions',
                              extra: MissionRouteArgs(
                                stages: stages,
                                stageIndex: index,
                              ),
                            );
                          },
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 250),
                            opacity: isSelected ? 1.0 : 0.4,
                            child: AnimatedScale(
                              duration: const Duration(milliseconds: 250),
                              scale: isSelected ? 1.3 : 0.65,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: imageSize,
                                    height: imageSize,
                                    child: Center(
                                      child: Image.asset(
                                        svgPath,
                                        width: imageInnerSize,
                                        height: imageInnerSize,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),

                                  SizedBox(height: imageSize * 0.02),

                                  AnimatedOpacity(
                                    duration: const Duration(milliseconds: 200),
                                    opacity: isSelected ? 1.0 : 0.0,
                                    child: SizedBox(
                                      width: stageTitleWidth,
                                      height: stageTitleHeight,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Image.asset(
                                            "assets/menu/stage/stage_name_outline.png",
                                            fit: BoxFit.contain,
                                          ),
                                          Text(
                                            '${i18n.t('stage')} ${index + 1}',
                                            style: TextStyle(
                                              fontSize: titleFontSize,
                                              fontWeight: FontWeight.w500,
                                              fontFamily: appFontFamily,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(height: bottomGap),

                  Padding(
                    padding: EdgeInsets.only(bottom: bottomGap),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () =>
                            context.canPop() ? context.pop() : context.go('/'),
                            child: SvgPicture.asset(
                              "assets/menu/common/Arrow_prev.svg",
                              width: arrowSize,
                              height: arrowSize,
                            ),
                          ),
                        ),

                        Expanded(
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(stages.length, (index) {
                                return Padding(
                                  padding:
                                  EdgeInsets.symmetric(horizontal: indicatorGap),
                                  child: SvgPicture.asset(
                                    _currentIndex == index
                                        ? "assets/menu/stage/carousel_selected.svg"
                                        : "assets/menu/stage/carousel_notSelected.svg",
                                    width: indicatorSize,
                                    height: indicatorSize,
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),

                        SizedBox(width: rightSpacerWidth),
                      ],
                    ),
                  ),
                ],
              ),
        ),
      ],
    );
  }
}