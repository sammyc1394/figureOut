import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:go_router/go_router.dart';
import 'package:flame/components.dart';

import '../config.dart';
import '../functions/sheet_service.dart';
import '../functions/endless_game_controller.dart';
import '../functions/leaderboard_service.dart';
import 'OneSecondGame.dart';
import 'MainGameScreen.dart';
import 'HowToPlayOverlay.dart';
import 'PausedScreen.dart';

class EndlessGameScreen extends StatefulWidget {
  const EndlessGameScreen({super.key});

  @override
  State<EndlessGameScreen> createState() => _EndlessGameScreenState();
}

class _EndlessGameScreenState extends State<EndlessGameScreen> {
  late EndlessOneSecondGame endlessGame;
  bool _initialized = false;
  double _finalScore = 0.0;
  bool _isHighScore = false;
  String _userNickname = '익명';

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  Future<void> _initGame() async {
    _userNickname = await LeaderboardService.getOrCreateNickname();
    endlessGame = EndlessOneSecondGame(
      navigatorContext: context,
      onGameOver: _handleGameOver,
    );
    setState(() => _initialized = true);
  }

  int _playerRank = 1;

  Future<void> _handleGameOver(double survivedTime) async {
    final isNewHigh = await LeaderboardService.saveScore(survivedTime);
    final rank = await LeaderboardService.getPlayerRank(survivedTime);
    if (mounted) {
      setState(() {
        _finalScore = survivedTime;
        _isHighScore = isNewHigh;
        _playerRank = rank;
      });
      endlessGame.overlays.add('endless_aftermath');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Color(bgColor),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/stages');
          }
        }
      },
      child: ColoredBox(
        color: const Color(bgColor),
        child: Stack(
          children: [
            GameWidget(
              game: endlessGame,
              overlayBuilderMap: {
                'pause': (context, game) {
                  return PauseOverlayWidget(
                    onResume: endlessGame.handlePauseResume,
                    onRetry: endlessGame.restartEndlessGame,
                    onMenu: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/stages');
                      }
                    },
                  );
                },
                'endless_aftermath': (context, game) {
                  return _EndlessAftermathOverlay(
                    score: _finalScore,
                    rank: _playerRank,
                    isHighScore: _isHighScore,
                    nickname: _userNickname,
                    onRetry: endlessGame.restartEndlessGame,
                    onMenu: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/stages');
                      }
                    },
                  );
                },
              },
              backgroundBuilder: (context) => Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: const Color(bgColor)),
                  Opacity(
                    opacity: 0.15,
                    child: ColorFiltered(
                      colorFilter: const ColorFilter.matrix([
                        -1,  0,  0, 0, 255,
                         0, -1,  0, 0, 255,
                         0,  0, -1, 0, 255,
                         0,  0,  0, 1,   0,
                      ]),
                      child: Image.asset(
                        'assets/noise_texture.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: ShapeCounterOverlay(notifier: endlessGame.shapeCountNotifier),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 무한모드 전용 FlameGame 엔진
class EndlessOneSecondGame extends OneSecondGame {
  final void Function(double survivedTime) onGameOver;
  final EndlessGameController controller = EndlessGameController();
  final ValueNotifier<double> survivedTimeNotifier = ValueNotifier(0.0);

  double elapsedGameTime = 0.0;
  bool _isEndlessActive = false;
  Timer? _spawnTimer;

  EndlessOneSecondGame({
    required super.navigatorContext,
    required this.onGameOver,
  }) : super(
          stages: [],
          stageIndex: 0,
          missionIndex: 0,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    startEndlessMode();
  }

  void startEndlessMode() {
    elapsedGameTime = 0.0;
    survivedTimeNotifier.value = 0.0;
    _isEndlessActive = true;

    // 60초 남은체력 타이머 세팅 & 1초 단위 레코드 텍스트 설정
    initialMaxTime = 60.0;
    currentMissionTime = 60.0;
    remainingTime = 60.0;

    timerBar.totalTime = 60.0;
    timerBar.isCountUpMode = true;
    timerBar.updateTime(60.0, record: 0.0);

    _startEndlessSpawnLoop();
  }

  void _startEndlessSpawnLoop() async {
    while (_isEndlessActive && !isPausedGlobally) {
      if (currentMissionTime <= 0) {
        _isEndlessActive = false;
        onGameOver(elapsedGameTime);
        break;
      }

      final burstCount = controller.getBurstCount(elapsedGameTime);
      for (int i = 0; i < burstCount; i++) {
        final enemy = controller.generateRandomEnemy(elapsedGameTime, 1);
        final flipY = (Vector2 v) => Vector2(v.x, -v.y);
        final toPlayArea = (Vector2 v, double r, {bool clampInside = true}) {
          return Vector2(
            playArea.position.x + v.x * playAreaScaleX,
            playArea.position.y + v.y * playAreaScaleY,
          );
        };

        final prepared = buildPreparedEnemy(
          enemy: enemy,
          flipY: flipY,
          toPlayArea: toPlayArea,
          checkBehavior: checkBehavior,
        );

        if (prepared != null) {
          await spawnPreparedEnemy(
            prepared,
            {},
            {},
            runId: 0,
          );
        }
      }

      final interval = controller.getSpawnInterval(elapsedGameTime);
      await Future.delayed(Duration(milliseconds: (interval * 1000).toInt()));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isEndlessActive) {
      elapsedGameTime += dt;
      currentMissionTime -= dt;
      if (currentMissionTime > 60.0) {
        currentMissionTime = 60.0;
      }
      survivedTimeNotifier.value = elapsedGameTime;
      updateTimerUI();

      if (currentMissionTime <= 0) {
        currentMissionTime = 0.0;
        _isEndlessActive = false;
        onGameOver(elapsedGameTime);
      }
    }
  }

  @override
  void applyTimePenalty(double seconds) {
    super.applyTimePenalty(seconds);
  }

  /// 도형 성공 처치 시 시간 보상 (+1.0초)
  void addTimeReward(double seconds) {
    if (currentMissionTime <= 0) return;
    currentMissionTime += seconds;
    remainingTime = currentMissionTime;
    updateTimerUI();
  }

  void restartEndlessGame() {
    overlays.remove('endless_aftermath');
    overlays.remove('pause');
    removeAll(children.where((c) => c is PositionComponent && c != screenArea && c != playArea && c != timerBar && c != pauseButton && c != refreshButton));
    _isEndlessActive = false;
    resetGameState();
    startEndlessMode();
  }
}

/// 기존 게임 에셋(Results_box.png 등)을 사용하는 무한모드 결과 오버레이
class _EndlessAftermathOverlay extends StatefulWidget {
  final double score;
  final int rank;
  final bool isHighScore;
  final String nickname;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  const _EndlessAftermathOverlay({
    required this.score,
    required this.rank,
    required this.isHighScore,
    required this.nickname,
    required this.onRetry,
    required this.onMenu,
  });

  @override
  State<_EndlessAftermathOverlay> createState() => _EndlessAftermathOverlayState();
}

class _EndlessAftermathOverlayState extends State<_EndlessAftermathOverlay> {
  late String _currentNickname;

  @override
  void initState() {
    super.initState();
    _currentNickname = widget.nickname;
  }

  void _showEditNicknameDialog(BuildContext context) {
    final controller = TextEditingController(text: _currentNickname);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('✏️ 닉네임 수정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                maxLength: 12,
                decoration: const InputDecoration(
                  labelText: '사용할 닉네임',
                  hintText: '예: 피자먹는 고양이1234',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final newRandom = await LeaderboardService.generateRandomNickname();
                  controller.text = newRandom;
                },
                icon: const Icon(Icons.casino, size: 18),
                label: const Text('무작위 닉네임 생성'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                final trimmed = controller.text.trim();
                if (trimmed.isNotEmpty) {
                  await LeaderboardService.updateNickname(trimmed);
                  await LeaderboardService.saveScore(widget.score);
                  setState(() {
                    _currentNickname = trimmed;
                  });
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  void _showLeaderboardDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFFFAF8F5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 320,
            height: 440,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  '🏆 무한모드 명예의 전당 🏆',
                  style: TextStyle(
                    fontFamily: appFontFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF222222),
                    decoration: TextDecoration.none,
                  ),
                ),
                const Divider(height: 20),
                Expanded(
                  child: FutureBuilder<List<LeaderboardEntry>>(
                    future: LeaderboardService.fetchTopScores(limit: 50),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final list = snapshot.data ?? [];
                      if (list.isEmpty) {
                        return Center(
                          child: Text(
                            '등록된 랭킹 기록이 없습니다.',
                            style: TextStyle(fontFamily: appFontFamily),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final item = list[index];
                          final rankNum = index + 1;
                          final isTop3 = rankNum <= 3;
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isTop3 ? const Color(0xFFFFF4E5) : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isTop3 ? Colors.orangeAccent : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '$rankNum위',
                                  style: TextStyle(
                                    fontFamily: appFontFamily,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isTop3 ? Colors.deepOrange : Colors.black87,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.nickname,
                                    style: TextStyle(
                                      fontFamily: appFontFamily,
                                      fontSize: 14,
                                      color: Colors.black87,
                                      decoration: TextDecoration.none,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '${item.score.toStringAsFixed(1)}초',
                                  style: TextStyle(
                                    fontFamily: appFontFamily,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: const Color(0xFF7BA6C5),
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    '닫기',
                    style: TextStyle(
                      fontFamily: appFontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final base = constraints.biggest.shortestSide;
            final panelWidth = base * 0.95;
            final panelHeight = panelWidth * (550 / 600);

            return SizedBox(
              width: panelWidth,
              height: panelHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/Results_box.png',
                      fit: BoxFit.fill,
                    ),
                  ),
                  // 상단 타이틀 래벨
                  Positioned(
                    top: panelHeight * 0.04,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'Special Stage',
                        style: TextStyle(
                          fontFamily: appFontFamily,
                          fontSize: panelHeight * 0.08,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFE4E0D3),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),

                  // 본문 정보 (첫째 줄: 순위, 둘째 줄: 닉네임 터치/더블클릭 수정, 셋째 줄: 생존시간)
                  Positioned(
                    top: panelHeight * 0.28,
                    left: panelWidth * 0.08,
                    right: panelWidth * 0.08,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => _showLeaderboardDialog(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7E6),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFFA94D), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '🏆 순위: ${widget.rank}위',
                                  style: TextStyle(
                                    fontFamily: appFontFamily,
                                    fontSize: panelHeight * 0.065,
                                    fontWeight: FontWeight.bold,
                                    color: widget.rank <= 3 ? Colors.deepOrange : const Color(0xFF222222),
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '(전체 랭킹 보기 >)',
                                  style: TextStyle(
                                    fontFamily: appFontFamily,
                                    fontSize: panelHeight * 0.045,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFD97706),
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: panelHeight * 0.02),
                        GestureDetector(
                          onTap: () => _showEditNicknameDialog(context),
                          onDoubleTap: () => _showEditNicknameDialog(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '플레이어: $_currentNickname',
                                  style: TextStyle(
                                    fontFamily: appFontFamily,
                                    fontSize: panelHeight * 0.055,
                                    color: const Color(0xFF333333),
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.edit, size: 16, color: Color(0xFF64748B)),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: panelHeight * 0.02),
                        Text(
                          '생존 시간: ${widget.score.toStringAsFixed(1)}초',
                          style: TextStyle(
                            fontFamily: appFontFamily,
                            fontSize: panelHeight * 0.075,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF222222),
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 하단 버튼 구성 (왼쪽: 메뉴, 중앙: AD Retry, 오른쪽: Replay)
                  Positioned(
                    top: panelHeight * 0.76,
                    left: panelWidth * 0.08,
                    right: panelWidth * 0.08,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: widget.onMenu,
                          child: Image.asset(
                            'assets/Home_button_blue.png',
                            width: panelWidth * 0.12,
                            height: panelWidth * 0.12,
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onRetry,
                          child: Container(
                            width: panelWidth * 0.48,
                            height: panelHeight * 0.16,
                            padding: EdgeInsets.symmetric(horizontal: panelWidth * 0.04),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7BA6C5),
                              borderRadius: BorderRadius.circular((panelHeight * 0.16) / 2),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned(
                                  left: panelWidth * 0.03,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF232323),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'AD',
                                      style: TextStyle(
                                        fontFamily: appFontFamily,
                                        fontSize: panelHeight * 0.045,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Text(
                                    'Retry',
                                    style: TextStyle(
                                      fontFamily: appFontFamily,
                                      fontSize: panelHeight * 0.065,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFE4E0D3),
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onRetry,
                          child: Image.asset(
                            'assets/Replay_button_blue.png',
                            width: panelWidth * 0.12,
                            height: panelWidth * 0.12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
