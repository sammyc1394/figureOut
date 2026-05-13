import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../config.dart';
import '../functions/logger.dart';

class SheetService {
  final String sheetId;
  final String apiKey;
  final math.Random _random = math.Random();

  SheetService()
      : sheetId = dotenv.env['GOOGLESHEETID'] ?? '',
        apiKey = dotenv.env['GOOGLESHEETAPIKEY'] ?? '' {
    if (sheetId.isEmpty || apiKey.isEmpty) {
      throw Exception('Missing Google Sheet credentials in .env');
    }
  }
  String get sheetName => 'Stages & Missions';
  String get encodedSheetName => Uri.encodeComponent(sheetName);
  String get range => 'B2:J'; // Start from row 5, columns C~J

  Future<List<StageData>> fetchData() async {
    final sheetNames = await fetchSheetNames();

    final futures = sheetNames
        .where((name) => name.startsWith('Stage') || name.startsWith('Stages'))
        .map((name) => _fetchSingleSheet(name))
        .toList();

    final results = await Future.wait(futures);

    return results.expand((e) => e).toList();
  }

  Future<List<StageData>> _fetchSingleSheet(String name) async {
    final encoded = Uri.encodeComponent(name);

    final uri = Uri.parse(
      'https://sheets.googleapis.com/v4/spreadsheets/$sheetId/values/$encoded!$range?key=$apiKey',
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Sheet fetch failed: ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    final values = (data['values'] as List).cast<List<dynamic>>();

    final List<StageData> stages = [];

    StageData? currentStage;
    int? currentMission;

    Map<int, List<EnemyData>>? currentMissionMap;
    Map<int, double> timeLimitMap = {};
    Map<int, String>? missionTitleMap;

    // URD Context (mission별로 분리)
    Map<int, URDContext> missionContexts = {};

    for (var row in values) {
      final cells = row.map((e) => (e ?? '').toString().trim()).toList();
      final String? cell = row.isNotEmpty ? row[0]?.toString().trim() : null;

      // ===== Stage 시작 =====
      if (cell != null && (cell.startsWith('s') || cell.startsWith('S'))) {
        final stgTitle = _safeGet(cells, 2);
        final rewardFromS = _safeGet(cells, 7);
        final timeFromS = _safeGet(cells, 8);

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
      if (cell != null &&
          (cell.startsWith('m') ||
              cell.startsWith('M') ||
              cell.startsWith('b') ||
              cell.startsWith('B'))) {

        final lower = cell.toLowerCase();

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
          missionContexts.putIfAbsent(currentMission, () => URDContext());

          final msnTitle = _safeGet(cells, 1);
          if (msnTitle.isNotEmpty) {
            currentStage.missionTitle[currentMission] = msnTitle;
          }

          final timeFromJ = _safeGet(cells, 8);
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

      final ctx = missionContexts[currentMission]!;

      final command = _safeGet(cells, 2);
      if (command.isEmpty) continue;
      if (_safeGet(cells, 1) == "1") continue;

      final rawShape = _safeGet(cells, 3);
      final shape = resolveShape(normalizeShape(rawShape), ctx);

      final order = parseOrder(shape, ctx);
      final energy = _parseEnergy(shape, shape.contains('Pentagon') ? 10 : 1, ctx);

      final darkYN = (energy == -1);

      final attackRaw = _safeGet(cells, 4);
      final movement = _safeGet(cells, 5);
      final resolvedMovement = resolveMovement(movement, ctx);

      final position = _safeGet(cells, 6);

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
      );

      currentMissionMap!
          .putIfAbsent(currentMission, () => [])
          .add(enemy);
    }

    return stages;
  }

  Future<List<String>> fetchSheetNames() async {
    final uri = Uri.parse(
      'https://sheets.googleapis.com/v4/spreadsheets/$sheetId?key=$apiKey',
    );

    final res = await http.get(uri);

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

  String normalizeShape(String raw) {
    return raw.replaceAll(RegExp(r'\s+'), '');
  }

  int? parseOrder(String shape, URDContext ctx) {
    print("[ORDER] before parse order = $shape");
    if (!shape.contains('_')) return null;

    final rest = shape.substring(shape.indexOf('_') + 1);

    final rdRegex = RegExp(r'\b(?:URD|RD)\(\s*-?\d+\s*,\s*-?\d+\s*\)');

    final match = rdRegex.firstMatch(rest);

    if (match != null) {
      final orderRaw = match.group(0)!;
      final resolved = resolveRandom(orderRaw, URDField.order, ctx);
      final ret = int.tryParse(resolved);
      print("[ORDER] order parse done = $ret - $orderRaw");
      return ret;
    }

    // RD/URD 없으면 일반 숫자 처리
    final numberMatch = RegExp(r'-?\d+').firstMatch(rest);
    if (numberMatch != null) {
      final ret = int.tryParse(numberMatch.group(0)!);
      print("[ORDER] order parse done = $ret");
      return ret;
    }


    return null;
  }

  String resolveRandom(String str, URDField field, URDContext ctx) {
    if (!str.contains('RD')) return str;

    return str.replaceAllMapped(
      RegExp(r'(URD|RD)\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)'),
          (match) {
        final type = match.group(1);
        final min = double.parse(match.group(2)!);
        final max = double.parse(match.group(3)!);

        if (type == 'RD') {
          final value = _random.nextDouble() * ((max + 1) - min) + min;
          return value.truncate().toString();
        }

        if (type == 'URD') {
          return _getURD(field, min.toInt(), (max.toInt() + 1), ctx).toString();
        }

        return match.group(0)!;
      },
    );
  }

  int _getURD(URDField field, int min, int max, URDContext ctx) {
    final rangeKey = '$min,$max';

    ctx.pools.putIfAbsent(field, () => {});
    ctx.pools[field]!.putIfAbsent(rangeKey, () {
      final list = List.generate(max - min + 1, (i) => min + i);
      list.shuffle(_random);
      return list;
    });

    final pool = ctx.pools[field]![rangeKey]!;

    if (pool.isEmpty) {
      throw Exception('URD exhausted: $field ($rangeKey)');
    }

    return pool.removeLast();
  }

  String resolvePosition(String str, URDContext ctx) {
    return str.replaceAllMapped(
      RegExp(r'\(\s*([^,]+)\s*,\s*([^)]+)\s*\)'),
          (match) {
        final xRaw = match.group(1)!.trim();
        final yRaw = match.group(2)!.trim();

        final x = resolveRandom(xRaw, URDField.positionX, ctx);
        final y = resolveRandom(yRaw, URDField.positionY, ctx);

        return '($x,$y)';
      },
    );
  }

  String resolveAttack(String str, URDContext ctx) {
    return str.replaceAllMapped(
      RegExp(r'\(\s*([^,]+)\s*,\s*([^)]+)\s*\)'),
          (match) {
        final secRaw = match.group(1)!.trim();
        final damageRaw = match.group(2)!.trim();

        final sec = resolveRandom(secRaw, URDField.attackSecond, ctx);
        final damage = resolveRandom(damageRaw, URDField.attackDamage, ctx);

        return '($sec,$damage)';
      },
    );
  }

  String resolveShape(String rawShape, URDContext ctx) {
    rawShape = rawShape.replaceAll(RegExp(r'\s+'), '');

    final underscoreIndex = rawShape.indexOf('_');

    // order/energy 없는 케이스
    if (underscoreIndex == -1) {
      return resolveRandom(rawShape, URDField.shape, ctx);
    }

    final basePart = rawShape.substring(0, underscoreIndex);
    final restPart = rawShape.substring(underscoreIndex + 1);

    // shape + size만 처리
    final resolvedBase = resolveRandom(basePart, URDField.size, ctx);

    // 나머지는 건드리지 않고 그대로 유지
    final ret = '${resolvedBase}_$restPart';

    // print("[DATA] shape resolve = $ret");
    return ret;
    return ret;
  }

  String resolveMovement(String movement, URDContext ctx) {
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

  String resolveMovementByType(String cmd, MovementValueType type, URDContext ctx) {
    switch (type) {
      case MovementValueType.positionSpeed:
        return cmd.replaceAllMapped(
          RegExp(r'\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\s*\)'),
              (match) {
            final x = resolveRandom(match.group(1)!, URDField.positionX, ctx);
            final y = resolveRandom(match.group(2)!, URDField.positionY, ctx);
            final s = resolveRandom(match.group(3)!, URDField.movementSpeed, ctx);
            return '(${x},${y},${s})';
          },
        );

      case MovementValueType.speedRadius:
        return cmd.replaceAllMapped(
          RegExp(r'\(\s*([^,]+)\s*,\s*([^)]+)\s*\)'),
              (match) {
            final r = resolveRandom(match.group(1)!, URDField.movementRadius, ctx);
            final s = resolveRandom(match.group(2)!, URDField.movementSpeed, ctx);
            return '(${r},${s})';
          },
        );

      case MovementValueType.secPair:
        return cmd.replaceAllMapped(
          RegExp(r'\(\s*([^,]+)\s*,\s*([^)]+)\s*\)'),
              (match) {
            final a = resolveRandom(match.group(1)!, URDField.movementAsec, ctx);
            final b = resolveRandom(match.group(2)!, URDField.movementBsec, ctx);
            return '(${a},${b})';
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
  int _parseEnergy(String s, int def, URDContext ctx) {
    // print("[ENERGY] energy parse start = $s");
    // 1. 마지막 ')' 위치 찾기
    final end = s.lastIndexOf(')');
    if (end == -1) return def;

    // 2. 해당 ')'에 대응하는 '(' 찾기 (뒤에서부터)
    int depth = 0;
    int start = -1;

    for (int i = end; i >= 0; i--) {
      if (s[i] == ')') depth++;
      else if (s[i] == '(') {
        depth--;
        if (depth == 0) {
          start = i;
          break;
        }
      }
    }

    if (start == -1) return def;

    // 3. 괄호 안 내용 추출
    final inner = s.substring(start + 1, end).trim();

    // 4. RD / URD 처리
    if (inner.contains('RD')) {
      final resolved = resolveRandom(inner, URDField.energy, ctx);
      final ret = int.tryParse(resolved) ?? def;
      // print("[ENERGY] energy parse = $ret - RD");
      return ret;
    }

    // 5. 일반 숫자 처리 (공백/소수 대응)
    final numberMatch = RegExp(r'-?\d+').firstMatch(inner);
    if (numberMatch != null) {
      final ret = int.tryParse(numberMatch.group(0)!) ?? def;
      // print("[ENERGY] energy parse = $ret");
      return ret;
    }

    return def;
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

  EnemyData({
    required this.command,
    required this.shape,
    required this.movement,
    required this.position,
    required this.mission,
    required this.energy,
    required this.darkYN,
    this.attackSeconds,
    this.attackDamage,
    this.order,
  });

  @override
  String toString() {
    return '[$command, $shape, $energy, $darkYN, $movement, $position, attack=($attackSeconds, $attackDamage), order=($order)]';
  }
}

class URDContext {
  final Map<URDField, Map<String, List<int>>> pools = {};
}
