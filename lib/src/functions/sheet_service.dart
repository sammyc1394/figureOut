import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../config.dart';
import '../functions/logger.dart';

class SheetService {
  final String sheetId;
  final String apiKey;
  final math.Random _random = math.Random();

  final Map<URDField, Map<String, List<int>>> _urdPools = {};

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
    final allStages = <StageData>[];

    final sheetNames = await fetchSheetNames();

    for (final name in sheetNames) {
      if (!(name.startsWith('Stage') || name.startsWith('Stages'))) continue;

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

      // ⭐ 시트마다 URD 초기화
      _urdPools.clear();

      // ⭐ 기존 파싱 로직 그대로 복붙 시작
      final List<StageData> stages = [];
      StageData? currentStage;
      int? currentMission;
      bool firstMissionHeaderSeen = false;

      Map<int, List<EnemyData>>? currentMissionMap;
      Map<int, double> timeLimitMap;
      Map<int, String>? missionTitleMap;

      for (var row in values) {
        final cells = row.map((e) => (e ?? '').toString().trim()).toList();
        final String? cell = row.isNotEmpty ? row[0]?.toString().trim() : null;

        if (cell != null && (cell.startsWith('s') || cell.startsWith('S'))) {
          firstMissionHeaderSeen = false;

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

        if (cell != null &&
            (cell.startsWith('m') ||
                cell.startsWith('M') ||
                cell.startsWith('b') ||
                cell.startsWith('B'))) {

          if (cell.toLowerCase().startsWith('m')) {
            final match = RegExp(r'm(\d+)').firstMatch(cell);
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
                cell.toLowerCase().startsWith('b');
          }

          continue;
        }

        if (currentStage == null || currentMission == null) continue;

        final command = _safeGet(cells, 2);
        if (command.isEmpty) continue;
        if (_safeGet(cells, 1) == "1") continue;

        final rawShape = _safeGet(cells, 3);
        final shape = resolveShape(normalizeShape(rawShape));

        final energy = _parseEnergy(shape, shape.contains('Pentagon') ? 10 : 1);
        final darkYN = (energy == -1);

        final attackRaw = _safeGet(cells, 4);
        final movement = _safeGet(cells, 5);
        final resolvedMovement = resolveMovement(movement);

        final position = _safeGet(cells, 6);

        final resolvedAttackRaw = resolveAttack(attackRaw);
        final resolvedPosition = resolvePosition(position);

        final order = parseOrder(shape);

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

      // ⭐ 합치기
      allStages.addAll(stages);
    }

    return allStages;
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

  int? parseOrder(String shape) {
    // print("[ORDER] shape = $shape");
    if (!shape.contains('_')) return null;

    final parts = shape.split('_');
    if (parts.length != 2) {
      // print('parts length = ${parts.length}');
      throw FormatException('Invalid order format-parts: $shape');
    }

    String orderRDcheck;
    if(parts[1].startsWith("RD") || parts[1].startsWith("URD")) {
      orderRDcheck = resolveRandom(parts[1], URDField.order);
    } else {
      orderRDcheck = parts[1];
    }

    final OEParse = orderRDcheck.split('(');

    final order = int.tryParse(OEParse[0]);
    if (order == null) {
      throw FormatException('Invalid order value in-order: $shape');
    }

    // print("shape $shape order = $order");
    return order;
  }

  String resolveRandom(String str, URDField field) {
    if (!str.contains('RD')) {
      return str;
    }

    return str.replaceAllMapped(
      RegExp(r'(URD|RD)\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)'),
          (match) {
        final type = match.group(1); // RD or URD
        final min = double.parse(match.group(2)!);
        final max = double.parse(match.group(3)!);

        if (type == 'RD') {
          final value = _random.nextDouble() * (max - min) + min;
          final truncated = value.truncate();
          // print("[DATA][RD] $truncated");
          return truncated.toString();
        }

        if (type == 'URD') {
          final value = _getURD(field, min.toInt(), max.toInt());
          // print("[DATA][URD] $value (field: $field)");
          return value.toString();
        }

        return match.group(0)!;
      },
    );
  }

  int _getURD(URDField field, int min, int max) {
    final rangeKey = '$min,$max';

    _urdPools.putIfAbsent(field, () => {});
    _urdPools[field]!.putIfAbsent(rangeKey, () {
      final list = List.generate(max - min + 1, (i) => min + i);
      list.shuffle(_random);
      return list;
    });

    final pool = _urdPools[field]![rangeKey]!;

    if (pool.isEmpty) {
      throw Exception('URD exhausted: $field ($rangeKey)');
    }

    return pool.removeLast();
  }

  String resolvePosition(String str) {
    return str.replaceAllMapped(
      RegExp(r'\(\s*([^,]+)\s*,\s*([^)]+)\s*\)'),
          (match) {
        final xRaw = match.group(1)!.trim();
        final yRaw = match.group(2)!.trim();

        final x = resolveRandom(xRaw, URDField.positionX);
        final y = resolveRandom(yRaw, URDField.positionY);

        return '($x,$y)';
      },
    );
  }

  String resolveAttack(String str) {
    return str.replaceAllMapped(
      RegExp(r'\(\s*([^,]+)\s*,\s*([^)]+)\s*\)'),
          (match) {
        final secRaw = match.group(1)!.trim();
        final damageRaw = match.group(2)!.trim();

        final sec = resolveRandom(secRaw, URDField.attackSecond);
        final damage = resolveRandom(damageRaw, URDField.attackDamage);

        return '($sec,$damage)';
      },
    );
  }

  String resolveShape(String rawShape) {
    // print("[DATA] resolveShape start");
    rawShape = rawShape.replaceAll(RegExp(r'\s+'), '');
    // 1. shape 이름 분리
    final underscoreIndex = rawShape.indexOf('_');
    if (underscoreIndex == -1) {
      // print("[DATA] underscoreIndex = ${underscoreIndex}");
      return resolveRandom(rawShape, URDField.shape);
    }

    final basePart = rawShape.substring(0, underscoreIndex); // CircleRD(1,5)
    final restPart = rawShape.substring(underscoreIndex + 1); // RD(1,5)(RD(1,5))

    // 2. size 처리 (basePart 안)
    final resolvedBase = resolveRandom(basePart, URDField.size);

    // 3. order + energy 분리
    final match = RegExp(r'([^(]+)(\(([^)]+)\))?').firstMatch(restPart);

    if (match == null) return resolvedBase;

    final orderRaw = match.group(1)!;       // RD(1,5)
    final energyRaw = match.group(3);       // RD(1,5)

    final order = resolveRandom(orderRaw, URDField.order);
    final energy = energyRaw != null
        ? resolveRandom(energyRaw, URDField.energy)
        : null;

    final ret = energy != null
        ? '${resolvedBase}_$order($energy)'
        : '${resolvedBase}_$order';

    // print("[DATA] shape parse = $ret");
    return ret;
  }

  String resolveMovement(String movement) {
    if(movement == '') {
      return '';
    }

    final commands = splitMovementCommands(movement);

    final resolved = commands.map((cmd) {
      final prefix = getMovementPrefix(cmd);
      final type = detectMovementTypeFromPrefix(prefix);

      final resolvedCmd = resolveMovementByType(cmd, type);

      return resolvedCmd;
    }).toList();

    return resolved.join(', ');
  }

  String resolveMovementByType(String cmd, MovementValueType type) {
    switch (type) {
      case MovementValueType.positionSpeed:
        return cmd.replaceAllMapped(
          RegExp(r'\(\s*([^,]+)\s*,\s*([^,]+)\s*,\s*([^)]+)\s*\)'),
              (match) {
            final x = resolveRandom(match.group(1)!, URDField.positionX);
            final y = resolveRandom(match.group(2)!, URDField.positionY);
            final s = resolveRandom(match.group(3)!, URDField.movementSpeed);
            return '(${x},${y},${s})';
          },
        );

      case MovementValueType.speedRadius:
        return cmd.replaceAllMapped(
          RegExp(r'\(\s*([^,]+)\s*,\s*([^)]+)\s*\)'),
              (match) {
            final r = resolveRandom(match.group(1)!, URDField.movementRadius);
            final s = resolveRandom(match.group(2)!, URDField.movementSpeed);
            return '(${r},${s})';
          },
        );

      case MovementValueType.secPair:
        return cmd.replaceAllMapped(
          RegExp(r'\(\s*([^,]+)\s*,\s*([^)]+)\s*\)'),
              (match) {
            final a = resolveRandom(match.group(1)!, URDField.movementAsec);
            final b = resolveRandom(match.group(2)!, URDField.movementBsec);
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
  int _parseEnergy(String s, int def) {
    final start = s.indexOf('(');
    final end = s.lastIndexOf(')');

    if (start == -1 || end == -1 || end <= start) {
      return def;
    }

    final rawValue = s.substring(start + 1, end).trim();

    if (rawValue.startsWith('RD')) {
      final resolved = resolveRandom(rawValue,URDField.energy);
      return int.tryParse(resolved) ?? def;
    }

    return int.tryParse(rawValue) ?? def;
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
