
import 'package:figureout/src/routes/OneSecondGame.dart';
import 'package:figureout/src/routes/AftermathScreen.dart';
import 'package:figureout/src/routes/PausedScreen.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../functions/sheet_service.dart';

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

class _MainGameScreenState extends State<MainGameScreen> {
  bool _initialized = false;
  late OneSecondGame oneSec;

  @override
  void initState() {
    super.initState();
    _decreaseHeartOnStart();

    oneSec = OneSecondGame(
      navigatorContext: context,
      stages: widget.stages,
      stageIndex: widget.stageIndex,
      missionIndex: widget.missionIndex,
    );
  }

  Future<void> _decreaseHeartOnStart() async {
    final prefs = await SharedPreferences.getInstance();
    int currentHearts = prefs.getInt('hearts') ?? 100;

    if (currentHearts <= 0) {
      currentHearts = 100;
    } else {
      currentHearts -= 1;
    }

    await prefs.setInt('hearts', currentHearts);
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
        child: GameWidget(
          game: oneSec,
          overlayBuilderMap: {
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
                onContinue: g.handleAftermathContinue,
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
      ),
    );
  }
}
