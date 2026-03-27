import 'package:figureout/src/functions/sheet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _MissionSelectScreenState extends State<MissionSelectScreen> {
  int? selectedIndex;
  Set<int> clearedMissions = {};

  bool isLoaded = false;

  final String defaultMsn =
      "assets/menu/mission/Mission_default_empty.svg";
  final String selectedMsn =
      "assets/menu/mission/Mission_selected_empty.svg";

  @override
  void initState() {
    super.initState();
    _loadMissionProgress();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadMissionProgress();
  }

  Future<void> _loadMissionProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final stage = widget.stages[widget.stageIndex];
    final loaded = <int>{};

    print('clearedMissions = $loaded');

    for (final missionNo in stage.missions.keys) {
      final key =
          'stage_${widget.stageIndex}_mission_${missionNo}_cleared';
      final isCleared = prefs.getBool(key) ?? false;
      if (isCleared) {
        loaded.add(missionNo);
      }
    }

    if (!mounted) return;
    setState(() {
      clearedMissions = loaded;
      isLoaded = true;
    });
  }

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

  bool _isBossLocked(StageData stage, int missionNo) {
  final isBossMission = stage.missionIsBoss[missionNo] ?? false;
  if (!isBossMission) return false;

  final missionNumbers = stage.missions.keys.toList()..sort();
  final bossIndex = missionNumbers.indexOf(missionNo);

  if (bossIndex <= 0) return false;

  final previousMissionNo = missionNumbers[bossIndex - 1];
  return !clearedMissions.contains(previousMissionNo);
}

  bool _isMissionCleared(int missionNo) {
    return clearedMissions.contains(missionNo);
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFFDFBF5),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    final stages = widget.stages;
    final stage = stages[widget.stageIndex];
    final missions = stage.missions;
    final missionNumbers = missions.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF5),
      appBar: const Menuappbar(),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1,
              ),
              itemCount: missionNumbers.length,
              itemBuilder: (context, index) {
                final missionNo = missionNumbers[index];
                final isSelected = selectedIndex == index;
                final rotationAngle = _rotationAngleFor(index);

                final isBossMission =
                    stage.missionIsBoss[missionNo] ?? false;
                final isLocked = _isBossLocked(stage, missionNo);
                final isCleared = _isMissionCleared(missionNo);

                return GestureDetector(
                  onTap: isLocked
                      ? null
                      : () async {
                          setState(() {
                            selectedIndex = index;
                          });

                          await Future.delayed(
                            const Duration(milliseconds: 800),
                          );

                          if (!mounted) return;

                          context.push('/game', extra: {
                            "stages": widget.stages,
                            "stageIndex": widget.stageIndex,
                            "missionIndex": missionNo - 1,
                          }).then((_) {
                            _loadMissionProgress();
                          });
                        },
                  child: Transform.rotate(
                    angle: rotationAngle,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
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
                                  BlendMode.multiply,
                                ),
                          child: SvgPicture.asset(
                            isSelected ? selectedMsn : defaultMsn,
                            width: 100,
                            height: 100,
                          ),
                        ),

                        Positioned(
                          top: 28,
                          child: Text(
                            isBossMission ? "Boss" : "$missionNo",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                              fontFamily: 'Gaegu',
                            ),
                          ),
                        ),

                        Positioned(
                          bottom: 10,
                          child: isBossMission
                              ? (isLocked
                                  ? Transform.translate(
                                      offset: const Offset(0, -4),
                                      child: SvgPicture.asset(
                                        "assets/menu/mission/lock.svg",
                                        width: 40,
                                        height: 40,
                                        colorFilter:
                                            const ColorFilter.mode(
                                          Colors.black54,
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    )
                                  : SvgPicture.asset(
                                      _difficultyStars(1),
                                      width: 50,
                                      height: 20,
                                    ))
                              : SvgPicture.asset(
                                  _difficultyStars(
                                    isCleared ? 3 : 1,
                                  ),
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
              bottom: 24,
              left: 24,
              right: 24,
            ),
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