import 'package:figureout/src/routes/OneSecondGame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class MainGameScreen extends StatelessWidget {
  const MainGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
          backgroundBuilder: (context) => Container(color: const Color(0xFFEDEBE0)),
          game: OneSecondGame()
      ),
    );
  }
}
