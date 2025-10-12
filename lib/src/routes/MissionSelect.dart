import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;

class MissionSelectScreen extends StatefulWidget {
  const MissionSelectScreen({super.key});

  @override
  State<MissionSelectScreen> createState() => _MissionSelectScreenState();
}

class _MissionSelectScreenState extends State<MissionSelectScreen> {
  int? selectedIndex;

  // TODO: 나중에 Google Sheet에서 데이터 받아오기
  final List<Map<String, dynamic>> missions = List.generate(12, (index) {
    return {
      "name": "Stage ${index + 1}",
      "difficulty": (index % 3) + 1, // 1~3 반복
    };
  });

  final String defaultMsn = "assets/menu/mission/Type 1_default_Empty.svg";
  final String selectedMsn = "assets/menu/mission/Type 1_selected_Empty.svg";

  String _difficultyStars(int level) {
    switch (level) {
      case 1:
        return "assets/menu/mission/Star_1.svg";
      case 2:
        return "assets/menu/mission/Star_2.svg";
      case 3:
        return "assets/menu/mission/Star_3.svg";
      default:
        return "assets/menu/mission/Star_0.svg";
    }
  }

  /// 각 미션 포스트잇의 기울기 (자연스럽게 랜덤한 느낌)
  double _rotationAngleFor(int index) {
    final angles = [-0.06, 0.04, -0.03, 0.05, -0.05, 0.03, -0.04, 0.06, -0.02, 0.04, -0.05, 0.02];
    return angles[index % angles.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF5),
      appBar: AppBar(
        title: const Text(
          "Stage 1",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, "/settings");
            },
            icon: SvgPicture.asset(
              "assets/menu/common/Setting.svg",
              width: 24,
              height: 24,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1,
              ),
              itemCount: missions.length,
              itemBuilder: (context, index) {
                final mission = missions[index];
                final isSelected = selectedIndex == index;
                final rotationAngle = _rotationAngleFor(index);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedIndex = index;
                    });
                  },
                  child: Transform.rotate(
                    angle: rotationAngle,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 포스트잇 배경
                        SvgPicture.asset(
                          isSelected ? selectedMsn : defaultMsn,
                          width: 100,
                          height: 100,
                        ),

                        // 스테이지 번호
                        Positioned(
                          top: 28,
                          child: Text(
                            "${index + 1}",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),

                        // 난이도 별
                        Positioned(
                          bottom: 10,
                          child: SvgPicture.asset(
                            _difficultyStars(mission["difficulty"]),
                            width: 50,
                            height: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 하단 버튼 영역
          Padding(
            padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 뒤로가기 버튼
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: SvgPicture.asset(
                    "assets/menu/common/Arrow back.svg",
                    width: 40,
                    height: 40,
                  ),
                ),

                if (selectedIndex != null)
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        "/game",
                      );
                    },
                    child: SvgPicture.asset(
                      "assets/menu/mission/Play_default.svg",
                      width: 120,
                      height: 40,
                    ),
                  ),
                ],
            ),
          ),
        ],
      ),
    );
  }
}
