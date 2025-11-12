import 'package:carousel_slider/carousel_slider.dart';
import 'package:figureout/src/routes/menuAppBar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

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
    "assets/menu/stage/Blue_Default.png",
    "assets/menu/stage/Black_Default.png",
    "assets/menu/stage/Pink_Default.png",
    "assets/menu/stage/Orange_Default.png",
  ];

  @override
  Widget build(BuildContext context) {
    final stages = widget.stages;

    return Scaffold(
      appBar: const Menuappbar(),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Text('Figure',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w300,
                letterSpacing: 0,
                color: Colors.black,
                fontFamily: "Moulpali",
              )
          ),
          const SizedBox(height: 8),
          CarouselSlider(
            options: CarouselOptions(
              height: 250,
              enlargeCenterPage: true,   // 가운데 있는 아이템을 크게
              enableInfiniteScroll: true,
              autoPlay: false,           // 자동 슬라이드 원하면 true
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 🎨 SVG 이미지
                        Image.asset(
                          svgPath,
                          width: 200,
                          height: 200,
                        ),
                        const SizedBox(height: 12),

                        // 🏷 Stage 이름
                        Text(
                          stage.name.isNotEmpty ?
                          stage.name : 'Stage ${index + 1}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Moulpali',
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            })
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
                      "assets/menu/common/Arrow back.svg",
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
                                ? "assets/menu/stage/Selected dot.svg"
                                : "assets/menu/stage/Not selected dot.svg",
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
