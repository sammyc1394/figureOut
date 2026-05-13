import 'package:carousel_slider/carousel_slider.dart';
import 'package:figureout/src/routes/menuAppBar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../functions/sheet_service.dart';

class StageSelectScreen extends StatefulWidget {
  final List<StageData> stages;

  const StageSelectScreen({super.key, required this.stages});

  @override
  State<StageSelectScreen> createState() => _StageSelectScreenState();
}

class _StageSelectScreenState extends State<StageSelectScreen> {
  int _currentIndex = 0;

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
  Widget build(BuildContext context) {
    final stages = widget.stages;

    return Scaffold(
      appBar: const Menuappbar(),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          SizedBox(
            height: 450,
            child: CarouselSlider(
                options: CarouselOptions(
                  height: 450,
                  viewportFraction: 0.48,
                  enlargeCenterPage: true,
                  enlargeFactor: 0.5,
                  enableInfiniteScroll: false,
                  padEnds: true,
                  autoPlay: false,
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
                      context.push('/missions', extra: {
                        "stages": stages,
                        "index": _currentIndex,
                      });
                    },
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: index == _currentIndex ? 1.0 : 0.2,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 250),
                        scale: index == _currentIndex ? 1.0 : 0.82,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [

                            SizedBox(
                              width: 220,
                              height: 220,
                              child: Center(
                                child: Image.asset(
                                  svgPath,
                                  width: 220,
                                  height: 220,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: index == _currentIndex ? 1.0 : 0.0,
                              child: SizedBox(
                                width: 150,
                                height: 60,
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
                                        fontSize: 28,
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
          const SizedBox(height: 20),
          // 기존 Row 전체를 이 코드로 교체
          Padding(
            padding: const EdgeInsets.only(bottom: 24), // 하단 여백 추가
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // : 뒤로가기 버튼
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => context.push('/'),
                    child: SvgPicture.asset(
                      "assets/menu/common/Arrow_prev.svg",
                      width: 40,
                      height: 40,
                    ),
                  ),
                ),

                Expanded(
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(stages.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: SvgPicture.asset(
                            _currentIndex == index
                                ? "assets/menu/stage/carousel_selected.svg"
                                : "assets/menu/stage/carousel_notSelected.svg",
                            width: 12,
                            height: 12,
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                // 오른쪽 여백 확보용 (정렬 균형)
                const SizedBox(width: 48),
              ],
            ),
          ),

        ],
      ),
    );
  }
}
