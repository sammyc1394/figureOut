import 'package:figureout/src/routes/MainGameScreen.dart';
import 'package:figureout/src/routes/MainMenu.dart';
import 'package:figureout/src/routes/MissionSelect.dart';
import 'package:figureout/src/routes/StageSelect.dart';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'src/routes/OneSecondGame.dart';
import 'package:flame/flame.dart';

//for testing
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  debugPrintGestureArenaDiagnostics = true;

  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: "assets/.env");
  Flame.device.fullScreen();

  WidgetsFlutterBinding.ensureInitialized();
  runApp(figureoutMain());
}

class figureoutMain extends StatelessWidget {
  const figureoutMain({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "figure out",
      theme: new ThemeData(
        scaffoldBackgroundColor:Color(0xFFEDEBE0),
        appBarTheme: new AppBarTheme(
          backgroundColor: Color(0xFFEDEBE0),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => MainMenuScreen(),
        '/stages': (context) => StageSelectScreen(),
        '/missions': (context) => MissionSelectScreen(),
        '/game': (context) => MainGameScreen(),
      },
    );
  }
}
