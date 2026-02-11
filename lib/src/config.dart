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

// Enums
enum shapes { Circle, Rectangel, Pentagon, Triangle, Hexagon }
enum StageResult { success, fail, cancelled }

late LocalizationService i18n;