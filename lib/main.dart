
import 'package:figureout/src/functions/logger_service.dart';
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
import 'package:figureout/src/routes/route_args.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

List<StageData> cachedStages = [];
List<String> cachedStageSheetNames = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: "assets/.env", isOptional: true);
  
  final deviceLocale = PlatformDispatcher.instance.locale;
  final deviceLang = deviceLocale.languageCode;

  const supportedLanguages = ['en', 'ko', 'ja'];

  final locale = supportedLanguages.contains(deviceLang)
      ? deviceLang
      : 'en'; // fallback

    Map<String, Map<String, String>> translations;

  try {
    // Google Sheet에서 번역 로드
    translations = await TranslationSheetService()
        .fetchTranslations()
        .timeout(const Duration(seconds: 5));
    if (translations.isEmpty) {
      throw Exception('Empty translation sheet');
    }
    debugPrint('[i18n] Loaded translations from Google Sheet');
  } catch (e) {
    // 실패 시 local Dart fallback
    translations = translationData;
    debugPrint('[i18n] Failed to load sheet, using local translations');
    debugPrint(e.toString());
  }

  i18n = LocalizationService(
    locale,
    translations,
  );

  try {
    final service = SheetService();
    final allSheetNames = await service.fetchSheetNames().timeout(const Duration(seconds: 8));
    final stageNames = allSheetNames
        .where((n) => n.startsWith('Stage') || n.startsWith('Stages'))
        .toList();
    cachedStageSheetNames = stageNames.isNotEmpty ? stageNames : allSheetNames;
    cachedStages = await service
        .fetchData(preloadedSheetNames: allSheetNames)
        .timeout(const Duration(seconds: 8));
    debugPrint('[Sheet] Loaded ${cachedStages.length} stages at startup');
  } catch (e) {
    debugPrint('[Sheet] Initial fetch failed: $e');
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp, // Lock to portrait orientation
  ]);

  // 로그 초기화
  final apiKey = dotenv.env['GOOGLESHEETAPIKEY'];
  final sheetId = dotenv.env['GOOGLESHEETID'];

  if (apiKey != null && sheetId != null) {
    await LoggerService.instance.init(
      apiKey: apiKey,
      sheetId: sheetId,
    );
  } else {
    debugPrint('[Logger] Missing Google Sheet credentials. Logger disabled.');
  }

  Flame.device.fullScreen();

  runApp(figureoutMain());
}

class figureoutMain extends StatelessWidget {
  const figureoutMain({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/',
      observers: [routeObserver],
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const MainMenuScreen(),
        ),
        GoRoute(
          path: '/stages',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is StageRouteArgs) {
              return StageSelectScreen(
                stages: extra.stages,
                initialStageIndex: extra.initialStageIndex,
              );
            }
            return StageSelectScreen(stages: extra as List<StageData>);
          },
        ),
        GoRoute(
          path: '/missions',
          builder: (context, state) {
            final data = state.extra as MissionRouteArgs;
            return MissionSelectScreen(
              stages: data.stages,
              stageIndex: data.stageIndex,
            );
          },
        ),
        GoRoute(
          path: '/game',
          builder: (context, state) {
            final data = state.extra as GameRouteArgs;
            return MainGameScreen(
              stages: data.stages,
              stageIndex: data.stageIndex,
              missionIndex: data.missionIndex,
            );
          },
        ),
      ],
    );

    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      title: "figure out",
      theme: ThemeData(
        scaffoldBackgroundColor:Color(bgColor),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(bgColor),
        ),
      ),
    );
  }
}

