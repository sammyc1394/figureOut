
import 'package:figureout/src/functions/analytics_service.dart';
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
import 'package:shared_preferences/shared_preferences.dart';


// our library
import 'package:firebase_core/firebase_core.dart';
import 'package:figureout/src/functions/sheet_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:figureout/src/routes/MainGameScreen.dart';
import 'package:figureout/src/routes/MainMenu.dart';
import 'package:figureout/src/routes/MissionSelect.dart';
import 'package:figureout/src/routes/StageSelect.dart';
import 'package:figureout/src/routes/EndlessGameScreen.dart';
import 'package:figureout/src/routes/OpenSourceInfoScreen.dart';
import 'package:figureout/src/routes/SettingsScreen.dart';
import 'package:figureout/src/routes/SunnyGamesScreen.dart';
import 'package:figureout/src/routes/UserDataScreen.dart';
import 'package:figureout/src/routes/route_args.dart';
import 'package:figureout/src/services/audio_manager.dart';
import 'package:figureout/src/services/ad_manager.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

List<StageData> cachedStages = [];
List<String> cachedStageSheetNames = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: "assets/.env", isOptional: true);

  await AnalyticsService.instance.init(
    // apiKey: dotenv.env['AMPLITUDE_API_KEY'],
  );

  AnalyticsService.instance.logEvent(
    'app_open',
  );

  final deviceLocale = PlatformDispatcher.instance.locale;
  final deviceLang = deviceLocale.languageCode;

  const hantRegions = ['TW', 'HK', 'MO'];

  String resolveLocale() {
    if (deviceLang == 'zh') {
      final script = deviceLocale.scriptCode;
      if (script == 'Hant') return 'zh-Hant';
      if (script == 'Hans') return 'zh-Hans';
      return hantRegions.contains(deviceLocale.countryCode) ? 'zh-Hant' : 'zh-Hans';
    }
    return supportedLanguages.contains(deviceLang) ? deviceLang : 'en'; // fallback
  }

  final prefs = await SharedPreferences.getInstance();
  final savedLocale = prefs.getString(localeOverridePrefsKey);
  final locale = (savedLocale != null && supportedLanguages.contains(savedLocale))
      ? savedLocale
      : resolveLocale();

  // Settings > User Data 화면에 표시할 사용 기록 갱신
  if (prefs.getString(userDataStartDatePrefsKey) == null) {
    await prefs.setString(
      userDataStartDatePrefsKey,
      DateTime.now().toIso8601String(),
    );
  }
  await prefs.setInt(
    userDataUseCountPrefsKey,
    (prefs.getInt(userDataUseCountPrefsKey) ?? 0) + 1,
  );

    // 로컬 데이터를 기본값으로 두고, 시트에 등록된 키만 덮어쓴다.
    // (시트에 아직 키가 없는 항목도 로컬 폴백으로 항상 표시되도록)
    final Map<String, Map<String, String>> translations = Map.of(translationData);

  try {
    // Google Sheet에서 번역 로드
    final sheetTranslations = await TranslationSheetService()
        .fetchTranslations()
        .timeout(const Duration(seconds: 5));
    if (sheetTranslations.isEmpty) {
      throw Exception('Empty translation sheet');
    }
    // 언어별로 병합: 시트 값이 있으면 덮어쓰고, 없으면 로컬 폴백 값을 유지한다.
    for (final entry in sheetTranslations.entries) {
      translations[entry.key] = {
        ...?translations[entry.key],
        ...entry.value,
      };
    }
    debugPrint('[i18n] Loaded translations from Google Sheet');
  } catch (e) {
    // 실패 시 local Dart fallback만 사용
    debugPrint('[i18n] Failed to load sheet, using local translations only');
    debugPrint(e.toString());
  }

  cachedTranslations = translations;
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

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('[Firebase Init Error] $e');
  }

  Flame.device.fullScreen();

  await AudioManager.instance.init();
  await AudioManager.instance.setBgmTrack(5);

  await AdManager.instance.init();

  runApp(figureoutMain());
}

class figureoutMain extends StatefulWidget {
  const figureoutMain({super.key});

  /// 언어 변경처럼 앱 전체를 새로 그려야 할 때 호출한다.
  /// 내비게이션 스택을 초기 위치('/')로 리셋하며 다시 빌드한다.
  static void restart(BuildContext context) {
    context.findAncestorStateOfType<_figureoutMainState>()?._restart();
  }

  @override
  State<figureoutMain> createState() => _figureoutMainState();
}

class _figureoutMainState extends State<figureoutMain> {
  Key _rebuildKey = UniqueKey();

  void _restart() {
    setState(() => _rebuildKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _rebuildKey,
      child: const _FigureoutApp(),
    );
  }
}

class _FigureoutApp extends StatelessWidget {
  const _FigureoutApp();

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
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
          routes: [
            GoRoute(
              path: 'user-data',
              builder: (context, state) => const UserDataScreen(),
            ),
            GoRoute(
              path: 'open-source-info',
              builder: (context, state) => const OpenSourceInfoScreen(),
            ),
            GoRoute(
              path: 'sunny-games',
              builder: (context, state) => const SunnyGamesScreen(),
            ),
          ],
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
        GoRoute(
          path: '/endless',
          builder: (context, state) => const EndlessGameScreen(),
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

