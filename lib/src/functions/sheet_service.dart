import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../config.dart';
import 'random_context.dart';

class SheetService {
  final String sheetId;
  final String apiKey;

  // 랜덤 파싱 정규식 상수화(공격, 이동명령, 위치 등 파싱할때 사용)
  static final RegExp _twoValueRegex = RegExp(
    r'\(\s*((?:[^(),]+|\([^()]*\))*)\s*,\s*((?:[^()]|\([^()]*\))*)\s*\)',
  );
  static final RegExp _threeValueRegex = RegExp(
    r'\(\s*((?:[^(),]+|\([^()]*\))*)\s*,\s*((?:[^(),]+|\([^()]*\))*)\s*,\s*((?:[^()]|\([^()]*\))*)\s*\)',
  );

  SheetService()
      : sheetId = dotenv.env['GOOGLESHEETID'] ?? '',
        apiKey = dotenv.env['GOOGLESHEETAPIKEY'] ?? '';
  String get sheetName => 'Stages & Missions';
  String get encodedSheetName => Uri.encodeComponent(sheetName);
  String get range => 'B1:I';

  Future<List<StageData>> fetchData({List<String>? preloadedSheetNames}) async {
    if (sheetId.isEmpty || apiKey.isEmpty) {
      throw Exception('Missing Google Sheet credentials in .env');
    }

    final sheetNames = preloadedSheetNames ?? await fetchSheetNames();

    final stageSheetNames = sheetNames
        .where((name) => name.toLowerCase().contains('stage'))
        .toList();

    final targetSheetNames =
        stageSheetNames.isNotEmpty ? stageSheetNames : sheetNames;

    final futures = targetSheetNames.map((name) => _fetchSingleSheet(name)).toList();

    final results = await Future.wait(futures);

    return results.expand((e) => e).toList();
  }

  Future<StageData?> fetchSingleStage(String sheetName) async {
    final results = await _fetchSingleSheet(sheetName);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<StageData>> _fetchSingleSheet(String name) async {
    final encoded = Uri.encodeComponent(name);

    final uri = Uri.parse(
      'https://sheets.googleapis.com/v4/spreadsheets/$sheetId/values/$encoded!$range?key=$apiKey',
    );

    final res = await http.get(uri, headers: {'Cache-Control': 'no-cache'});
    if (res.statusCode != 200) {
      throw Exception('Sheet fetch failed: ${res.statusCode}');
    }

    debugPrint('[SHEET RAW] $name: ${res.body.substring(0, res.body.length.clamp(0, 300))}');

    final data = jsonDecode(res.body);
    final values = (data['values'] as List).cast<List<dynamic>>();

    final List<StageData> stages = [];

    StageData? currentStage;
    int? currentMission;

    Map<int, List<EnemyData>>? currentMissionMap;
    Map<int, double> timeLimitMap = {};
    Map<int, String>? missionTitleMap;

    // URD Context (mission별로 분리)
    Map<int, RandomContext> missionContexts = {};

    for (var row in values) {
      final cells = row.map((e) => (e ?? '').toString().trim()).toList();
      final String? cell = row.isNotEmpty ? row[0]?.toString().trim() : null;

      // ===== Stage 시작 =====
      if (cell != null && (cell.startsWith('s') || cell.startsWith('S'))) {
        final stgTitle = (name.toLowerCase().contains('special') || cell.length > 4) ? name : cell;
        final rewardFromS = '';
        final timeFromS = '';

        currentMissionMap = {};
        timeLimitMap = {};
        missionTitleMap = {};

        currentStage = StageData(
          name: stgTitle,
          reward: rewardFromS,
          timeLimit: timeFromS,
          missions: currentMissionMap,
          missionTimeLimits: timeLimitMap,
          missionTitle: missionTitleMap,
          missionIsBoss: {},
        );

        stages.add(currentStage);
        continue;
      }

      // ===== Mission 시작 =====
      final missionCell = _safeGet(cells, 1);
      final missionMarker = (cell != null &&
              (cell.startsWith('m') ||
                  cell.startsWith('M') ||
                  cell.startsWith('b') ||
                  cell.startsWith('B')))
          ? cell
          : missionCell;

      if (missionMarker.startsWith('m') ||
          missionMarker.startsWith('M') ||
          missionMarker.startsWith('b') ||
          missionMarker.startsWith('B')) {

        final lower = missionMarker.toLowerCase();

        if (lower.startsWith('m')) {
          final match = RegExp(r'm(\d+)').firstMatch(lower);
          if (match != null) {
            currentMission = int.parse(match.group(1)!);
          }
        } else {
          if (currentStage != null && currentStage.missions.isNotEmpty) {
            currentMission =
                currentStage.missions.keys.reduce((a, b) => a > b ? a : b) + 1;
          } else {
            currentMission = 1;
          }
        }

        if (currentMission != null && currentStage != null) {
          missionContexts.putIfAbsent(
            currentMission,
            () => RandomContext(),
          );

          final msnTitle =
              missionMarker.contains(':') ? missionMarker : _safeGet(cells, 1);
          if (msnTitle.isNotEmpty) {
            currentStage.missionTitle[currentMission] = msnTitle;
          }

          final timeFromJ = _firstParsableNumber([
            _safeGet(cells, 6),
            _safeGet(cells, 7),
          ]);
          final parsed = double.tryParse(timeFromJ);
          if (parsed != null) {
            currentStage.missionTimeLimits[currentMission] = parsed;
          }

          currentStage.missionIsBoss[currentMission] =
              lower.startsWith('b');
        }

        continue;
      }

      if (currentStage == null || currentMission == null) continue;

      if (_safeGet(cells, 1) == '1') continue;

      final ctx = missionContexts[currentMission]!;

      final shapeColumn = _shapeColumnIndex(cells);
      if (shapeColumn < 0) continue;
      final rawShapeCell = _safeGet(cells, shapeColumn);

      final isWait = rawShapeCell.toLowerCase().startsWith('wait');
      final command = isWait ? 'wait' : 'e';
      final rawShape = rawShapeCell;
      final shape = resolveShape(normalizeShape(rawShape), ctx);

      final order = parseOrder(shape, ctx);
      final energy = _parseEnergy(shape, 1, ctx);

      final darkYN = (energy == -1);

      final attackRaw = _safeGet(cells, shapeColumn + 1);
      final movement = _safeGet(cells, shapeColumn + 2);
      final resolvedMovement = resolveMovement(movement, ctx);

      final rawPosition = _safeGet(cells, shapeColumn + 3);
      final zOrder = _parseZOrderPrefix(rawPosition);
      final position = _stripZOrderPrefix(rawPosition);

      final resolvedAttackRaw = resolveAttack(attackRaw, ctx);
      final resolvedPosition = resolvePosition(position, ctx);

      double? attackSeconds;
      double? attackDamage;

      final attackMatch =
      RegExp(r'\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)')
          .firstMatch(resolvedAttackRaw);

      if (attackMatch != null) {
        attackSeconds = double.tryParse(attackMatch.group(1)!);
        attackDamage = double.tryParse(attackMatch.group(2)!);
      }

      final enemy = EnemyData(
        command: command,
        shape: shape,
        movement: resolvedMovement,
        position: resolvedPosition,
        mission: currentMission,
        attackSeconds: attackSeconds,
        attackDamage: attackDamage,
        order: order,
        energy: energy,
        darkYN: darkYN,
        zOrder: zOrder,
      );

      currentMissionMap!
          .putIfAbsent(currentMission, () => [])
          .add(enemy);
    }

    if (stages.isEmpty && (name.toLowerCase().contains('special') || name.toLowerCase().contains('endless') || name.contains('무한'))) {
      final defaultStage = StageData(
        name: name,
        reward: '',
        timeLimit: '180',
        missions: {1: []},
        missionTimeLimits: {1: 180.0},
        missionTitle: {1: '무한모드'},
        missionIsBoss: {1: false},
      );
      stages.add(defaultStage);
    } else {
      for (final stg in stages) {
        if (stg.missions.isEmpty && (stg.name.toLowerCase().contains('special') || stg.name.toLowerCase().contains('endless') || stg.name.contains('무한'))) {
          stg.missions[1] = [];
          stg.missionTitle[1] = '무한모드';
        }
      }
    }

    return stages;
  }

  Future<List<String>> fetchSheetNames() async {
    final uri = Uri.parse(
      'https://sheets.googleapis.com/v4/spreadsheets/$sheetId?key=$apiKey',
    );

    final res = await http.get(uri, headers: {'Cache-Control': 'no-cache'});

    if (res.statusCode != 200) {
      throw Exception('Sheet meta fetch failed: ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    final sheets = data['sheets'] as List;

    return sheets
        .map((s) => s['properties']['title'] as String)
        .toList();
  }

  String _safeGet(List<String> cells, int index) {
    if (index < cells.length) return cells[index];
    return '';
  }

  // 위치값(G열) 앞에 붙은 Top_/Bottom_ 접두사로 z-order 힌트를 파싱한다.
  ShapeZOrder _parseZOrderPrefix(String rawPosition) {
    final lower = rawPosition.trimLeft().toLowerCase();
    if (lower.startsWith('top_')) return ShapeZOrder.top;
    if (lower.startsWith('bottom_')) return ShapeZOrder.bottom;
    return ShapeZOrder.normal;
  }

  // Top_/Bottom_ 접두사를 제거한 순수 위치 문자열을 돌려준다.
  String _stripZOrderPrefix(String rawPosition) {
    final trimmed = rawPosition.trimLeft();
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('top_')) return trimmed.substring(4);
    if (lower.startsWith('bottom_')) return trimmed.substring(7);
    return rawPosition;
  }

  String _firstParsableNumber(List<String> values) {
    for (final value in values) {
      if (double.tryParse(value) != null) return value;
    }
    return '';
  }

  int _shapeColumnIndex(List<String> cells) {
    if (_isShapeOrWaitCell(_safeGet(cells, 1))) return 1;
    if (_isShapeOrWaitCell(_safeGet(cells, 2))) return 2;
    if (_isShapeOrWaitCell(_safeGet(cells, 3))) return 3;
    return -1;
  }

  bool _isHeaderShape(String value) {
    final lower = value.trim().toLowerCase();
    return lower == 'shape' || lower == 'enemy' || lower == '도형';
  }

  bool _isShapeOrWaitCell(String value) {
    final lower = value.trim().toLowerCase();
    if (lower.isEmpty || _isHeaderShape(lower)) return false;
    return lower.startsWith('wait') ||
        lower.startsWith('circle') ||
        lower.startsWith('rectangle') ||
        lower.startsWith('triangle') ||
        lower.startsWith('pentagon') ||
        lower.startsWith('hexagon') ||
        RegExp(r'^[crtph]\d').hasMatch(lower);
  }

  String normalizeShape(String raw) {
    return raw.replaceAll(RegExp(r'\s+'), '');
  }

  int? parseOrder(String shape, RandomContext ctx) {
    if (!shape.contains('_')) return null;

    final rest = shape.substring(shape.indexOf('_') + 1);

    final firstOpen = rest.indexOf('(');

    String orderRaw;

    if (firstOpen == -1) {
      // 2
      orderRaw = rest;
    } else {
      final firstClose = rest.indexOf(')', firstOpen);

      if (firstClose == -1) return null;

      // 괄호 안에 ','가 있으면 order 자체의 랜덤식
      // RD(1,5), RND(1,5), URD(1,5)
      final inside = rest.substring(firstOpen + 1, firstClose);

      if (inside.contains(',')) {
        orderRaw = rest.substring(0, firstClose + 1);
      } else {
        // 2(3) -> (3)은 energy
        orderRaw = rest.substring(0, firstOpen);
      }
    }

    final resolved = resolveRandom(
      orderRaw,
      URDField.order,
      ctx,
    );

    return int.tryParse(resolved);
  }

  String resolveRandom(String str, URDField field, RandomContext ctx) {
    String ret = ctx.resolveRandom(str, field);
    return ret;
  }

  String resolvePosition(String str, RandomContext ctx) {
    if (!str.contains('RD') && !str.contains('RND') && !str.contains('URD')) {
      return str;
    }

    final match = _twoValueRegex.firstMatch(str)!;

    final xRaw = match.group(1)!.trim();
    final yRaw = match.group(2)!.trim();

    debugPrint("[resolvePosition] (xRaw, yRaw) = ($xRaw, $yRaw)");

    final x = resolveRandom(xRaw, URDField.positionX, ctx);
    final y = resolveRandom(yRaw, URDField.positionY, ctx);

    return '($x,$y)';
  }

  String resolveAttack(String str, RandomContext ctx) {

    return str.replaceAllMapped(
      _twoValueRegex,
          (match) {
        final secRaw = match.group(1)!.trim();
        final damageRaw = match.group(2)!.trim();

        final sec = resolveRandom(secRaw, URDField.attackSecond, ctx);
        final damage = resolveRandom(damageRaw, URDField.attackDamage, ctx);

        return '($sec,$damage)';
      },
    );
  }

  String resolveShape(String rawShape, RandomContext ctx) {
    rawShape = rawShape.replaceAll(RegExp(r'\s+'), '');

    final underscoreIndex = rawShape.indexOf('_');

    // order/energy 없는 케이스
    if (underscoreIndex == -1) {
      return resolveRandom(rawShape, URDField.size, ctx);
    }

    final basePart = rawShape.substring(0, underscoreIndex);
    final restPart = rawShape.substring(underscoreIndex + 1);

    // shape + size만 처리
    final resolvedBase = resolveRandom(basePart, URDField.size, ctx);

    // 나머지는 건드리지 않고 그대로 유지
    final ret = '${resolvedBase}_$restPart';

    // print("[DATA] shape resolve = $ret");
    return ret;
  }

  String resolveMovement(String movement, RandomContext ctx) {
    if(movement == '') {
      return '';
    }

    final commands = splitMovementCommands(movement);

    final resolved = commands.map((cmd) {
      final prefix = getMovementPrefix(cmd);
      final type = detectMovementTypeFromPrefix(prefix);

      final resolvedCmd = resolveMovementByType(cmd, type, ctx);

      return resolvedCmd;
    }).toList();

    return resolved.join(', ');
  }

  String resolveMovementByType(String cmd, MovementValueType type, RandomContext ctx) {
    switch (type) {
      case MovementValueType.positionSpeed:
        return cmd.replaceAllMapped(
          _threeValueRegex,
              (match) {
            final x = resolveRandom(match.group(1)!, URDField.positionX, ctx);
            final y = resolveRandom(match.group(2)!, URDField.positionY, ctx);
            final s = resolveRandom(match.group(3)!, URDField.movementSpeed, ctx);
            return '($x,$y,$s)';
          },
        );

      case MovementValueType.speedRadius:
        return cmd.replaceAllMapped(
          _twoValueRegex,
              (match) {
            final r = resolveRandom(match.group(1)!, URDField.movementRadius, ctx);
            final s = resolveRandom(match.group(2)!, URDField.movementSpeed, ctx);
            return '($r,$s)';
          },
        );

      case MovementValueType.secPair:
        return cmd.replaceAllMapped(
          _twoValueRegex,
              (match) {
            final a = resolveRandom(match.group(1)!, URDField.movementAsec, ctx);
            final b = resolveRandom(match.group(2)!, URDField.movementBsec, ctx);
            return '($a,$b)';
          },
        );
    }
  }

  MovementValueType? detectMovementType(String command, String movement) {
    if (movement.isEmpty) return null;

    final commaCount = ','.allMatches(movement).length;

    if (commaCount == 2) {
      return MovementValueType.positionSpeed;
    }

    final upper = command.toUpperCase();

    if (upper.contains('C')) {
      return MovementValueType.speedRadius;
    }

    if (upper.contains('D')) {
      return MovementValueType.secPair;
    }

    return null;
  }

  List<String> splitMovementCommands(String movement) {
    return movement.split(RegExp(r'\s*,\s*(?=[A-Z])'));
  }

  String getMovementPrefix(String cmd) {
    if (cmd.startsWith('DR')) return 'DR';
    return cmd.substring(0, 1);
  }

  MovementValueType detectMovementTypeFromPrefix(String prefix) {
    switch (prefix) {
      case 'Z':
      case 'B':
        return MovementValueType.positionSpeed;

      case 'C':
        return MovementValueType.speedRadius;

      case 'D':
      case 'DR':
        return MovementValueType.secPair;

      case 'L':
        return MovementValueType.positionSpeed; // 일단 임시 (아래 설명)

      default:
        throw Exception('Unknown movement prefix: $prefix');
    }
  }

  // 일반 에너지 파싱(양수). 다크면 굳이 쓰지 않음.
  int _parseEnergy(String s, int def, RandomContext ctx) {
    final end = s.lastIndexOf(')');
    if (end == -1) return def;

    int depth = 0;
    int start = -1;

    for (int i = end; i >= 0; i--) {
      if (s[i] == ')') {
        depth++;
      } else if (s[i] == '(') {
        depth--;

        if (depth == 0) {
          start = i;
          break;
        }
      }
    }

    if (start == -1) return def;

    final energyRaw = s.substring(start + 1, end).trim();

    final resolved = resolveRandom(
      energyRaw,
      URDField.energy,
      ctx,
    );

    return int.tryParse(resolved) ?? def;
  }
}

class StageData {
  final String name;
  String reward;
  String timeLimit; //Default time limit
  final Map<int, List<EnemyData>> missions;
  final Map<int, double> missionTimeLimits;
  final Map<int, String> missionTitle;

  Map<int, bool> missionIsBoss;

  StageData({
    required this.name,
    required this.reward,
    required this.timeLimit,
    required this.missions,
    required this.missionTimeLimits,
    required this.missionTitle,
    required this.missionIsBoss,
  });

  @override
  String toString() {
    return '[$name, reward: $reward, missions: ${missions.keys}, missionTitle: $missionTitle, missionTimeLimits: $missionTimeLimits, missionIsBoss: $missionIsBoss]';
  }
}

class EnemyData {
  final String command;
  final String shape;
  final String movement;
  final String position;
  final int mission;
  final double? attackSeconds;
  final double? attackDamage;
  final int? order;
  final int energy;
  final bool darkYN;
  final bool isBlinking;
  final ShapeZOrder zOrder;

  EnemyData({
    required this.command,
    required this.shape,
    required this.movement,
    required this.position,
    required this.mission,
    required this.energy,
    required this.darkYN,
    this.isBlinking = false,
    this.attackSeconds,
    this.attackDamage,
    this.order,
    this.zOrder = ShapeZOrder.normal,
  });

  @override
  String toString() {
    return '[$command, $shape, $energy, $darkYN, $movement, $position, attack=($attackSeconds, $attackDamage), order=($order)]';
  }
}

