import 'package:figureout/src/functions/sheet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'menuAppBar.dart';

class MissionSelectScreen extends StatefulWidget {
  final List<StageData> stages;
  final int stageIndex;

  const MissionSelectScreen({
    super.key,
    required this.stages,
    required this.stageIndex,
  });

  @override
  State<MissionSelectScreen> createState() =>
      _MissionSelectScreenState();
}

class _MissionSelectScreenState
    extends State<MissionSelectScreen> {
  int? selectedIndex;

  final String defaultMsn =
      "assets/menu/mission/Mission_default_empty.svg";
  final String selectedMsn =
      "assets/menu/mission/Mission_selected_empty.svg";

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

  double _rotationAngleFor(int index) {
    final angles = [
      -0.06, 0.04, -0.03, 0.05,
      -0.05, 0.03, -0.04, 0.06,
      -0.02, 0.04, -0.05, 0.02
    ];
    return angles[index % angles.length];
  }

  @override
  Widget build(BuildContext context) {
    final stages = widget.stages;
    final stage = stages[widget.stageIndex];
    final missions = stage.missions;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF5),
      appBar: const Menuappbar(),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1,
              ),
              itemCount: missions.length,
              itemBuilder: (context, index) {
                final isSelected = selectedIndex == index;
                final rotationAngle = _rotationAngleFor(index);

                /// 🔥 핵심: Boss 판별
                final isBossMission =
                    stage.missionIsBoss[index + 1] ?? false;

                /// 🔥 락 (원하면 조건 바꿔)
                final isLocked = isBossMission;

                return GestureDetector(
                  onTap: isLocked
                      ? null
                      : () async {
                          setState(() {
                            selectedIndex = index;
                          });

                          await Future.delayed(
                              const Duration(milliseconds: 800));

                          if (!mounted) return;

                          context.push('/game', extra: {
                            "stages": widget.stages,
                            "stageIndex": widget.stageIndex,
                            "missionIndex": index,
                          });
                        },
                  child: Transform.rotate(
                    angle: rotationAngle,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        /// 🎨 회색 처리
                        ColorFiltered(
                          colorFilter: isLocked
                              ? const ColorFilter.matrix([
                                  0.3, 0.3, 0.3, 0, 0,
                                  0.3, 0.3, 0.3, 0, 0,
                                  0.3, 0.3, 0.3, 0, 0,
                                  0,   0,   0,   1, 0,
                                ])
                              : const ColorFilter.mode(
                                  Colors.transparent,
                                  BlendMode.multiply),
                          child: SvgPicture.asset(
                            isSelected ? selectedMsn : defaultMsn,
                            width: 100,
                            height: 100,
                          ),
                        ),

                        /// 🔥 Boss or 번호
                        Positioned(
                          top: 28,
                          child: Text(
                            isBossMission
                                ? "Boss"
                                : "${index + 1}",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                              fontFamily: 'Gaegu',
                            ),
                          ),
                        ),

                        /// ⭐ 별 (보스는 제거)
                        // if (!isBossMission)
                        Positioned(
                          bottom: 10,
                          child: isBossMission
                        ? Transform.translate(
                            offset: const Offset(0, -4), // 위로 6px
                            child: SvgPicture.asset(
                              "assets/menu/mission/lock.svg",
                              width: 40,
                              height: 40,
                              
                              colorFilter: const ColorFilter.mode(
                                Colors.black54,
                                BlendMode.srcIn,
                              ),
                            )
                        )
                        : SvgPicture.asset(
                            _difficultyStars(1),
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

          Padding(
            padding: const EdgeInsets.only(
                bottom: 24, left: 24, right: 24),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () =>
                        context.push('/stages', extra: stages),
                    child: SvgPicture.asset(
                      "assets/menu/common/Arrow_prev.svg",
                      width: 40,
                      height: 40,
                    ),
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