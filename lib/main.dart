
import 'package:flame/flame.dart';
import 'dart:ui';

//localization
import 'package:figureout/src/config.dart';
import 'package:figureout/src/config/translation_data.dart';
import 'package:figureout/src/functions/localization_service.dart';
import 'package:figureout/src/functions/translation_sheet_service.dart';

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

  await dotenv.load(fileName: "assets/.env");
  
  final deviceLocale = PlatformDispatcher.instance.locale;
  final deviceLang = deviceLocale.languageCode;

  const supportedLanguages = ['en', 'ko', 'ja'];

  final locale = supportedLanguages.contains(deviceLang)
      ? deviceLang
      : 'en'; // fallback

    Map<String, Map<String, String>> translations;

  try {
    // Google Sheet에서 번역 로드
    translations = await TranslationSheetService().fetchTranslations();
    if (translations.isEmpty) {
      throw Exception('Empty translation sheet');
    }
    print('[i18n] Loaded translations from Google Sheet');
  } catch (e) {
    // 실패 시 local Dart fallback
    translations = translationData;
    print('[i18n] Failed to load sheet, using local translations');
    debugPrint(e.toString());
  }


  i18n = LocalizationService(
    locale,
    translations,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, // Lock to portrait orientation
  ]);

  
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
