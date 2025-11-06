import 'dart:ffi';

import 'package:figureout/src/routes/OneSecondGame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';


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

    if(currentHearts <= 0 ) {
      currentHearts = 100;
    } else {
      currentHearts -= 1;
    }

    await prefs.setInt('hearts', currentHearts);

    setState(() {
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if(!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(),),
      );
    }

    return Scaffold(
        body: Stack(
          children: [
            GameWidget(
              backgroundBuilder: (context) => Container(color: const Color(0xFFEDEBE0)),
              game: oneSec,
              overlayBuilderMap: {
                'refresh': (context, game) {
                  return Positioned(
                    top: 50,
                    right: 30,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        print("Flutter refresh button pressed");
                        oneSec.onRefresh();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 6),
                          ],
                        ),
                        child: Icon(Icons.refresh, size: 25, color: Colors.green),
                      ),
                    ),
                  );
                },
                'pause': (context, game) {
                  return Positioned(
                    top: 50,
                    left: 20,
                    child: GestureDetector(
                      onTap: () => oneSec.pauseGame(),
                      child: SvgPicture.asset(
                        'assets/pause.svg',
                        width: 25,
                        height: 25,
                      ),
                    ),
                  );
                },
              },
            ),
          ],
        )
    );
  }
}