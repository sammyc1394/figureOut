import 'dart:ffi';

import 'package:figureout/src/routes/OneSecondGame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        missionIndex: widget.missionIndex
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

    return ColoredBox(
      color: const Color(0xFFEDEBE0), // 배경 색
      child: GameWidget(
        game: oneSec,
        // Flame의 캔버스에 덮이는 배경 지정
        backgroundBuilder: (context) =>
            Container(color: const Color(0xFFEDEBE0)),
      ),
    );
  }
}
