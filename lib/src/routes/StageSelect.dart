import 'package:carousel_slider/carousel_slider.dart';
import 'package:figureout/src/routes/menuAppBar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class StageSelectScreen extends StatefulWidget {
  const StageSelectScreen({super.key});

  @override
  State<StageSelectScreen> createState() => _StageSelectScreenState();
}

class _StageSelectScreenState extends State<StageSelectScreen> {
  int _currentIndex = 0;

  // SVG 파일 목록 (assets 폴더에 미리 넣어야 함)
  final List<String> stages = [
    "assets/menu/stage/Black_Default.svg",
    "assets/menu/stage/Blue_Default.svg",
    "assets/menu/stage/Orange_Default.svg",
    "assets/menu/stage/Pink_Default.svg"
  ];

  @override
  Widget build(BuildContext context) {
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
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
            items: stages.map((file) {
              return Builder(
                builder: (BuildContext context) {
                  return GestureDetector(
                    onTap: () {
                      // 여기서 해당 스테이지 선택 시 이동
                      Navigator.pushNamed(
                        context,
                        "/missions",
                        arguments: {"stage": file}, // stage 정보 전달
                      );
                    },
                    child: SvgPicture.asset(
                      file,
                      width: 200,
                      height: 200,
                    ),
                  );
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          // 기존 Row 전체를 이 코드로 교체
          Padding(
            padding: const EdgeInsets.only(bottom: 24), // 하단 여백 추가
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ⬅️ 왼쪽: 뒤로가기 버튼
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: SvgPicture.asset(
                    "assets/menu/common/Arrow back.svg",
                    width: 36,
                    height: 36,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SvgPicture.asset(
                      "assets/menu/stage/Dots.svg",
                      width: 80,
                      height: 16,
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
