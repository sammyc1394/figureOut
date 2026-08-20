
import 'package:figureout/src/routes/OneSecondGame.dart';
import 'package:figureout/src/routes/AftermathScreen.dart';
import 'package:figureout/src/routes/HowToPlayOverlay.dart';
import 'package:figureout/src/routes/PausedScreen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../functions/analytics_service.dart';
import '../functions/sheet_service.dart';
import '../services/ad_manager.dart';
import '../services/play_time_tracker.dart';

class MainGameScreen extends StatefulWidget {
  final List<StageData> stages;
  final int stageIndex;
  final int missionIndex;

  const MainGameScreen({
    super.key,
    required this.stages,
    required this.stageIndex,
    required this.missionIndex,
  });

  @override
  State<MainGameScreen> createState() => _MainGameScreenState();
}

class _MainGameScreenState extends State<MainGameScreen> with WidgetsBindingObserver {
  bool _initialized = false;
  late OneSecondGame oneSec;
  final _playTimeTracker = PlayTimeTracker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _playTimeTracker.start();
    _decreaseHeartOnStart();

    _runAnalytics();

    oneSec = OneSecondGame(
      navigatorContext: context,
      stages: widget.stages,
      stageIndex: widget.stageIndex,
      missionIndex: widget.missionIndex,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _playTimeTracker.resume();
    } else {
      _playTimeTracker.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playTimeTracker.stopAndPersist();
    super.dispose();
  }

  Future<void> _runAnalytics() async {
    print("[ANALYTICS] running analytics - stage start");

    await AnalyticsService.instance.logEvent(
      'stage_start',
      properties: {
        'stage_id': widget.stageIndex + 1,
        'mission_id': widget.missionIndex + 1,
      },
    );
  }

  /// 체크포인트 이어하기(Continue) 전에 리워드 광고를 먼저 보여준다.
  /// 체크포인트 재개 로직(g.handleAftermathContinue) 자체는 건드리지 않는다.
  void _continueAfterAd(OneSecondGame g) {
    bool rewardEarned = false;
    AdManager.instance.showRewardedAd(
      onUserEarnedReward: () {
        rewardEarned = true;
      },
      onAdClosed: () {
        if (rewardEarned) {
          g.handleAftermathContinue();
        }
        // 보상을 못 받았으면(광고를 중간에 닫음) 화면은 그대로 두어 다시 시도할 수 있게 한다.
      },
      onAdUnavailable: () {
        // 광고가 아직 준비되지 않았을 때 진행이 막히지 않도록 바로 이어서 진행한다.
        g.handleAftermathContinue();
      },
    );
  }

  Future<void> _decreaseHeartOnStart() async {
    final prefs = await SharedPreferences.getInstance();
    int currentHearts = (prefs.getInt('hearts') ?? maxHearts).clamp(0, maxHearts);

    if (currentHearts > 0) {
      currentHearts -= 1;
      await prefs.setInt('hearts', currentHearts);

      // 하트 타이머가 없으면 시작
      if (currentHearts < maxHearts) {
        final nextHeartTime = prefs.getInt('next_heart_time');
        if (nextHeartTime == null) {
          await prefs.setInt(
            'next_heart_time',
            DateTime.now().millisecondsSinceEpoch + heartRefillIntervalSec * 1000,
          );
        }
      }
    }

    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      child: ColoredBox(
        color: const Color(bgColor),
        child: Stack(
          children: [
            GameWidget(
              game: oneSec,
              overlayBuilderMap: {
                'howto': (context, game) {
                  final g = game as OneSecondGame;
                  return HowToPlayOverlay(
                    onContinue: g.handleHowToPlayContinue,
                  );
                },
                'pause': (context, game) {
                  final g = game as OneSecondGame;
                  return PauseOverlayWidget(
                    onResume: g.handlePauseResume,
                    onRetry: g.handlePauseRetry,
                    onMenu: g.handlePauseMenu,
                  );
                },
                'aftermath': (context, game) {
                  final g = game as OneSecondGame;
                  return AftermathOverlayWidget(
                    result: g.currentAftermathResult!,
                    starCount: g.currentAftermathStars,
                    stgIndex: g.currentAftermathStgIndex,
                    msnIndex: g.currentAftermathMsnIndex,
                    onContinue: () => _continueAfterAd(g),
                    onRetry: g.handleAftermathRetry,
                    onPlay: g.handleAftermathPlay,
                    onMenu: g.handleAftermathMenu,
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
                child: ShapeCounterOverlay(notifier: oneSec.shapeCountNotifier),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShapeCounterOverlay extends StatelessWidget {
  final ValueNotifier<Map<String, int>> notifier;

  const ShapeCounterOverlay({super.key, required this.notifier});

  static const _shapeOrder = ['Circle', 'Pentagon', 'Hexagon', 'Rectangle', 'Triangle'];
  static const _shapeSvg = {
    'Circle': 'assets/Circle_basic.svg',
    'Pentagon': 'assets/Pentagon_basic.svg',
    'Hexagon': 'assets/Hexagon_basic.svg',
    'Rectangle': 'assets/Rectangle_basic.svg',
    'Triangle': 'assets/Triangle_basic.svg',
  };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: notifier,
      builder: (context, counts, _) {
        final items = _shapeOrder
            .where((s) => (counts[s] ?? 0) > 0)
            .toList();

        if (items.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              for (final shape in items) ...[
                _ShapeCountItem(
                  svgPath: _shapeSvg[shape]!,
                  count: counts[shape]!,
                ),
                const SizedBox(width: 16),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ShapeCountItem extends StatelessWidget {
  final String svgPath;
  final int count;

  const _ShapeCountItem({required this.svgPath, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(svgPath, width: 38, height: 38),
        const SizedBox(width: 5),
        Text(
          'X$count',
          style: const TextStyle(
            fontFamily: 'Gaegu',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF555555),
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}
