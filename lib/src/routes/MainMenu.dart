import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // 주변을 떠다닐 도형들 (SVG 경로는 실제 프로젝트 구조에 맞게 수정)
  final List<String> shapes = [
    "assets/Circle (tap).svg",
    "assets/triangle.svg",
    "assets/hexagon.svg",
    "assets/Rectangle 3.svg",
    "assets/pentagon.svg",
  ];


  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 도형의 기본 위치값
  Alignment _baseAlignment(int index) {
    final alignments = [
      const Alignment(-0.8, -0.5),
      const Alignment(0.7, -0.3),
      const Alignment(-0.6, 0.7),
      const Alignment(0.8, 0.5),
      const Alignment(0.0, -0.7),
    ];
    return alignments[index % alignments.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF5),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque, // 빈 영역 터치도 인식
        onTap: () {
          Navigator.pushNamed(context, '/stages');
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 💠 주변 도형들
            ...List.generate(shapes.length, (index) {
              final base = _baseAlignment(index);
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final dx = sin(_controller.value * 2 * pi + index) * 0.03;
                  final dy = cos(_controller.value * 2 * pi + index) * 0.03;
                  return Align(
                    alignment: Alignment(base.x + dx, base.y + dy),
                    child: Opacity(
                      opacity: 0.9,
                      child: SvgPicture.asset(
                        shapes[index],
                        width: 90,
                        height: 90,
                      ),
                    ),
                  );
                },
              );
            }),

            // 🎮 중앙 게임 제목
            const Text(
              'Figure',
              style: TextStyle(
                fontFamily: 'Moulpali',
                fontSize: 48,
                fontWeight: FontWeight.w300,
                color: Colors.black,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
