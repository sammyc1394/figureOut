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

  runApp(
    GameWidget(
      game: OneSecondGame(),
      backgroundBuilder: (context) => Container(color: const Color(0xFFEDEBE0)),
    ),
  );
}
