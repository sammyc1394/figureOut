import 'package:carousel_slider/carousel_slider.dart';
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

  // SVG 파일 목록 (assets 폴더에 미리 넣어야 함)
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
  }

  @override
  Widget build(BuildContext context) {
    final stages = widget.stages;

    final size = MediaQuery.sizeOf(context);
    final screenWidth = size.width;
    final screenHeight = size.height;
    final shortestSide = size.shortestSide;

    final isTablet = shortestSide >= 600;

    final appBarHeight = kToolbarHeight;
    final topGap = screenHeight * 0.012;
    final bottomGap = screenHeight * 0.024;

    final imageSize = (shortestSide * (isTablet ? 0.75 : 0.45))
        .clamp(180.0, isTablet ? 300.0 : 240.0);
    final imageInnerSize = imageSize * 0.90;

    final stageTitleWidth = imageSize * 0.55;
    final stageTitleHeight = imageSize * 0.18;
    final titleFontSize = (imageSize * 0.10).clamp(18.0, 26.0);

    final indicatorSize = (shortestSide * 0.028).clamp(10.0, 16.0);
    final indicatorGap = shortestSide * 0.010;

    final arrowSize = (shortestSide * 0.095).clamp(36.0, 52.0);
    final rightSpacerWidth = arrowSize + indicatorGap * 2;

    final carouselHeight = (screenHeight * (isTablet ? 0.52 : 0.64))
        .clamp(360.0, isTablet ? 560.0 : 480.0);
    final viewportFraction = isTablet ? 0.5: 0.5;

    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(bgColor),
          appBar: const Menuappbar(),
          body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: topGap),
              SizedBox(
                child: CarouselSlider(
                    options: CarouselOptions(
                      height: carouselHeight,
                      viewportFraction: viewportFraction,
                      enlargeCenterPage: true,
                      enlargeFactor: 0.36,
                      enableInfiniteScroll: false,
                      padEnds: true,
                      autoPlay: false,
                      initialPage: widget.initialStageIndex,
                      onPageChanged: (index, reason) {
                        setState(() => _currentIndex = index);
                      },
                    ),
                items: List.generate(stages.length, (index) {
                  final svgPath = stagesSVG[index % stagesSVG.length];
                  final stage = stages[index];

                  return Builder(
                    builder: (context) {
                      return GestureDetector(
                        onTap: () {
                          context.push(
                            '/missions',
                            extra: MissionRouteArgs(
                              stages: stages,
                              stageIndex: _currentIndex,
                            ),
                          );
                        },
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: index == _currentIndex ? 1.0 : 0.2,
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 250),
                            scale: index == _currentIndex ? 1.3 : 0.7,
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

                                SizedBox(height: imageSize * 0.04),

                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: index == _currentIndex ? 1.0 : 0.0,
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
                                          stage.name.isNotEmpty
                                              ? stage.name
                                              : 'Stage ${index + 1}',
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
                  );

                })
              ),
        ),
            SizedBox(height: bottomGap),
            Padding(
              padding: EdgeInsets.only(bottom: bottomGap), // 하단 여백 추가
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // : 뒤로가기 버튼
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => context.canPop() ? context.pop() : context.go('/'),
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
                            padding: EdgeInsets.symmetric(horizontal: indicatorGap),
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

                  // 오른쪽 여백 확보용 (정렬 균형)
                  SizedBox(width: rightSpacerWidth),
                ],
              ),
            ),
          ],
        ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.15,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    -1, 0, 0, 0, 255,
                     0,-1, 0, 0, 255,
                     0, 0,-1, 0, 255,
                     0, 0, 0, 1,   0,
                  ]),
                child: Image.asset('assets/noise_texture.png', fit: BoxFit.cover),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
