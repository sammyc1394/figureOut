import 'package:figureout/src/functions/sheet_service.dart';
import 'package:figureout/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import 'menuAppBar.dart';
import 'route_args.dart';
import 'NoHeartsOverlay.dart';

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
  bool _isNavigating = false;

  static const _missionBg = Color(0xFF7BAED0);

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

    debugPrint('clearedMissions = $loaded');

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
    // 사이즈 컴포넌트
    final size = MediaQuery.sizeOf(context);
    final screenHeight = size.height;
    final shortestSide = size.shortestSide;

    final isTablet = shortestSide >= 600;

    final double imageSize =
    (shortestSide * (isTablet ? 0.75 : 0.65)).clamp(220.0, 330.0);

    final stageTitleWidth = imageSize * 0.55;
    final stageTitleHeight = imageSize * 0.18;
    final titleFontSize = (imageSize * 0.10).clamp(18.0, 40.0);

    if (!isLoaded) {
      return const Scaffold(
        backgroundColor: _missionBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final stages = widget.stages;
    final stage = stages[widget.stageIndex];
    final missions = stage.missions;
    final missionNumbers = missions.keys.toList()..sort();

    return Stack(
      children: [
        Scaffold(
          backgroundColor: _missionBg,
          appBar: const Menuappbar(backgroundColor: _missionBg),
          body: Column(
            children: [
              // Stage label
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Transform.scale(
                  scale: 1.3,
                  child: SizedBox(
                  width: stageTitleWidth,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                        child: Image.asset(
                          "assets/menu/stage/stage_name_outline.png",
                          fit: BoxFit.contain,
                        ),
                      ),
                      Text(
                        stage.name.isNotEmpty
                            ? stage.name
                            : 'Stage ${widget.stageIndex + 1}',
                        style: TextStyle(
                          fontFamily: appFontFamily,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          // decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              ),

              // Mission grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: missionNumbers.length,
                  itemBuilder: (context, index) {
                    final missionNo = missionNumbers[index];
                    final isBossMission = stage.missionIsBoss[missionNo] ?? false;
                    final isLocked = _isBossLocked(stage, missionNo);
                    final isCleared = _isMissionCleared(missionNo);

                    return GestureDetector(
                      onTap: isLocked
                          ? null
                          : () async {
                              if (_isNavigating) return;
                              setState(() => _isNavigating = true);
                              try {
                              // 하트 0개면 입장 차단
                              final prefs = await SharedPreferences.getInstance();
                              final hearts = (prefs.getInt('hearts') ?? maxHearts).clamp(0, maxHearts);
                              if (!mounted) return;
                              if (hearts <= 0) {
                                showGeneralDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  barrierColor: Colors.transparent,
                                  transitionDuration: Duration.zero,
                                  pageBuilder: (ctx, _, __) => Material(
                                    color: Colors.transparent,
                                    child: NoHeartsOverlay(
                                      onOk: () => Navigator.of(ctx).pop(),
                                    ),
                                  ),
                                );
                                return;
                              }

                              setState(() => selectedIndex = index);

                              // 해당 스테이지 최신 데이터 fetch
                              List<StageData> freshStages = widget.stages;
                              if (widget.stageIndex < cachedStageSheetNames.length) {
                                try {
                                  final sheetName = cachedStageSheetNames[widget.stageIndex];
                                  final freshStage = await SheetService()
                                      .fetchSingleStage(sheetName)
                                      .timeout(const Duration(seconds: 5));
                                  if (freshStage != null) {
                                    freshStages = List.of(widget.stages)..[widget.stageIndex] = freshStage;
                                    cachedStages = freshStages;
                                  }
                                } catch (e) {
                                  debugPrint('[Sheet] Stage re-fetch failed, using cached: $e');
                                }
                              }

                              await Future.delayed(const Duration(milliseconds: 300));
                              if (!mounted) return;
                              await context.push(
                                '/game',
                                extra: GameRouteArgs(
                                  stages: freshStages,
                                  stageIndex: widget.stageIndex,
                                  missionIndex: missionNo - 1,
                                ),
                              );
                              if (mounted) _loadMissionProgress();
                              } finally {
                                if (mounted) setState(() => _isNavigating = false);
                              }
                            },
                      child: Opacity(
                        opacity: isLocked ? 0.45 : 1.0,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                'assets/StageScreen_box.png',
                                fit: BoxFit.fill,
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    isBossMission ? 'Boss' : '$missionNo',
                                    style: const TextStyle(
                                      fontFamily: 'Gaegu',
                                      fontSize: 28,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Image.asset(
                                    isCleared
                                        ? 'assets/Win_stars.png'
                                        : 'assets/StageScreen_emptystars.png',
                                    width: 80,
                                    height: 30,
                                    fit: BoxFit.contain,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Back button
              Padding(
                padding: const EdgeInsets.only(bottom: 24, left: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Image.asset(
                      'assets/Back_button_beige.png',
                      width: 40,
                      height: 40,
                    ),
                  ),
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

