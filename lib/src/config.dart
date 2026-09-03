import 'package:figureout/src/functions/localization_service.dart';

const gameWidth = 1179.0; //117.90;
const gameHeight = 2556.0; //255.60;
const elementCount = 10;

// editor min/max coordinate
const double minX = -170.0;
const double maxX = 170.0;
const double minY = -365.0;
const double maxY = 365.0;

const double rangeX = 340.0; // Total width of your coordinate system (170 - (-170))
const double rangeY = 730.0; // Total height of your coordinate system (365 - (-365))

final double maxShapeRadius = 50.0;
final double shapePadding = maxShapeRadius * 2;

// Available space (leaving room for UI)
final targetPlayWidth = rangeX + shapePadding;
final targetPlayHeight = rangeY + shapePadding;
final aspectRatio = targetPlayWidth / targetPlayHeight;

const UItopPadding = 120.0;
const UIsidePadding = 10.0;

// Game Font
String appFontFamily = 'Gaegu';
const fallbackFontFamily = ['Gaegu'];

const bgColor = 0xFFF2EFE6;
const darkBgColor = 0xFF1E1C18;

const grainTexture = 'assets/noise_texture.png';

// Enums
enum shapes { Circle, Rectangle, Pentagon, Triangle, Hexagon }
enum StageResult { success, fail, cancelled }

// 도형 겹침(z-order) 힌트. 시트 G열 위치값 접두사(Top_/Bottom_)로 지정한다.
// top: 항상 맨 위, bottom: 항상 맨 아래, normal: 생성(시트) 순서대로.
enum ShapeZOrder { top, normal, bottom }

enum URDField {
  shape, size, order, energy,
  positionX, positionY,
  movementSpeed, movementRadius, movementAsec, movementBsec,
  attackSecond, attackDamage,
}
enum MovementValueType {
  positionSpeed, // (x, y, speed)
  speedRadius,   // (speed, radius)
  secPair,       // (aSec, bSec)
}

late LocalizationService i18n;

// 언어 선택 화면에서 사용하는 지원 언어 목록과 표시 이름
const List<String> supportedLanguages = ['en', 'ko', 'ja', 'fr', 'es', 'zh-Hans', 'zh-Hant'];
const Map<String, String> languageDisplayNames = {
  'en': 'English',
  'ko': '한국어',
  'ja': '日本語',
  'fr': 'Français',
  'es': 'Español',
  'zh-Hans': '简体中文',
  'zh-Hant': '繁體中文',
};
const String localeOverridePrefsKey = 'locale_override';

// 설정 화면(Settings > Theme)에서 다크/라이트 모드를 전환할 때 쓰는 저장 키.
// 실제 상태는 theme_mode_scope.dart의 isDarkModeNotifier가 들고 있다.
const String themeModePrefsKey = 'theme_mode';

// User Data 화면(Settings > User Data)에서 보여줄 사용 기록 저장 키
const String userDataStartDatePrefsKey = 'user_data_start_date';
const String userDataUseCountPrefsKey = 'user_data_use_count';
const String userDataPlayTimeSecondsPrefsKey = 'user_data_play_time_seconds';

// main()에서 병합된 번역 데이터를 담아 두어, 앱 재시작 없이 언어를 바꿀 때 재사용한다.
Map<String, Map<String, String>> cachedTranslations = {};

const int maxHearts = 5;
// 테스트: 30초, 실서비스: 1800 (30분)
const int heartRefillIntervalSec = 5;

enum GestureType { tap, trap, slice, hold,  stretch }
