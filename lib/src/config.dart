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

const int maxHearts = 5;
// 테스트: 30초, 실서비스: 1800 (30분)
const int heartRefillIntervalSec = 5;
