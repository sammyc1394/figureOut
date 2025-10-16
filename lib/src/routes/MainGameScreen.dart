import 'dart:ffi';

import 'package:figureout/src/routes/OneSecondGame.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainGameScreen extends StatefulWidget {
  const MainGameScreen({super.key});

  @override
  State<MainGameScreen> createState() => _MainGameScreenState();
}

class _MainGameScreenState extends State<MainGameScreen> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    _decreaseHeartOnStart();
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
        body: GameWidget(
          backgroundBuilder: (context) => Container(color: const Color(0xFFEDEBE0)),
          game: OneSecondGame(nevigatorContext: context),
      ),
    );
  }
}


// class _MainGameScreenState extends State<MainGameScreen> {
//
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: GameWidget(
//           backgroundBuilder: (context) => Container(color: const Color(0xFFEDEBE0)),
//           game: OneSecondGame()
//       ),
//     );
//   }
// }
