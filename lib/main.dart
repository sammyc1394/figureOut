
import 'package:flame/flame.dart';

// common libraries
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';


// our library
import 'package:figureout/src/functions/sheet_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:figureout/src/routes/MainGameScreen.dart';
import 'package:figureout/src/routes/MainMenu.dart';
import 'package:figureout/src/routes/MissionSelect.dart';
import 'package:figureout/src/routes/StageSelect.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  debugPrintGestureArenaDiagnostics = true;

  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, // Lock to portrait orientation
  ]);

  await dotenv.load(fileName: "assets/.env");
  Flame.device.fullScreen();

  WidgetsFlutterBinding.ensureInitialized();
  runApp(figureoutMain());
}

class figureoutMain extends StatelessWidget {
  const figureoutMain({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const MainMenuScreen(),
        ),
        GoRoute(
          path: '/stages',
          builder: (context, state) {
            final data = state.extra as List<StageData>;
            return StageSelectScreen(stages: data);
          },
        ),
        GoRoute(
          path: '/missions',
          builder: (context, state) {
            final data = state.extra as Map;
            return MissionSelectScreen(
              stages: data["stages"],
              stageIndex: data["index"],
            );
          },
        ),
        GoRoute(
          path: '/game',
          builder: (context, state) {
            final data = state.extra as Map;
            return MainGameScreen(
              stages: data["stages"],
              stageIndex: data["stageIndex"],
              missionIndex: data["missionIndex"],
            );
          },
        ),
      ],
    );

    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      title: "figure out",
      theme: new ThemeData(
        scaffoldBackgroundColor:Color(0xFFEDEBE0),
        appBarTheme: new AppBarTheme(
          backgroundColor: Color(0xFFEDEBE0),
        ),
      ),
    );
  }
}
