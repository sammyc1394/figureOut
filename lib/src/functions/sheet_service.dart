import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  String get range => 'B3:J'; // Start from row 5, columns C~J

  Future<List<StageData>> fetchData() async {
    final uri = Uri.parse(
      'https://sheets.googleapis.com/v4/spreadsheets/$sheetId/values/$encodedSheetName!$range?key=$apiKey',
    );
    print('Fetching data from: $uri');
    print('uri host: ${uri.host}');

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Sheet fetch failed: ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    final values = (data['values'] as List).cast<List<dynamic>>();

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
      if (cell != null && cell.startsWith('s')) {
        firstMissionHeaderSeen = false;
        final stgTitle = _safeGet(cells, 2);
        final rewardFromS = _safeGet(cells, 7); // I
        final timeFromS = _safeGet(cells, 8); // J

        print("rewardFromS = $rewardFromS, timeFromS = $timeFromS");

        currentMissionMap = {};
        timeLimitMap = {};
        missionTitleMap = {};
        currentStage = StageData(
          name: stgTitle,
          reward: rewardFromS,
          timeLimit: timeFromS,
          missions: currentMissionMap!,
          missionTimeLimits: timeLimitMap!,
          missionTitle: missionTitleMap!,
        );
        stages.add(currentStage);
        continue;
      }
      if (cell != null && cell.startsWith('m')) {
        // 미션 번호 갱신만
        final missionMatch = RegExp(r'm(\d+)').firstMatch(cell);
        if (missionMatch != null) {
          currentMission = int.parse(missionMatch.group(1)!);

          if (currentStage != null) {
            final msnTitle = _safeGet(cells, 1);
            if(msnTitle != null) {
              currentStage!.missionTitle[currentMission] = msnTitle;
            }
            final timeFromJ = _safeGet(cells, 8); // J
            final parsed = double.tryParse(timeFromJ);
            print("timeFromJ = $timeFromJ");
            if (parsed != null) {
              currentStage!.missionTimeLimits[currentMission] = parsed;
            }
          }

          if (currentStage != null && !firstMissionHeaderSeen) {
            firstMissionHeaderSeen = true;

            final msnTitle = _safeGet(cells, 1);
            final rewardFromM = _safeGet(cells, 7); // H
            final timeFromM = _safeGet(cells, 8); // I

            print("rewardFromM = $rewardFromM, timeFromM = $timeFromM");

            if ((currentStage!.reward.isEmpty) && rewardFromM.isNotEmpty) {
              currentStage!.reward = rewardFromM;
            }
            if ((currentStage!.timeLimit.isEmpty) && timeFromM.isNotEmpty) {
              currentStage!.timeLimit = timeFromM;
            }
            if((currentStage!.missionTitle.isEmpty) && msnTitle.isNotEmpty) {
              currentStage!.missionTitle[currentMission!] = msnTitle;
            }

            print(
              '[STAGE "${currentStage!.missionTitle}"] '
              'reward="${currentStage!.reward}", timeLimit="${currentStage!.timeLimit}"',
            );
          }
        }
        continue;
      }

      if (currentStage == null || currentMission == null) continue;

      final String command = row.length > 2
          ? row[2]?.toString().trim() ?? ''
          : '';

      if (command.isEmpty) continue;

      if(row[1]?.toString().trim() == "1") continue;

      final String shape = row.length > 3
          ? row[3]?.toString().trim() ?? ''
          : '';
      final energy = _parseEnergy(shape, shape.contains('Pentagon') ? 10 : 1,);
      final bool darkYN = (energy == -1);
      final String attackRaw= row.length > 4
          ? row[4]?.toString().trim() ?? ''
          : '';

      final String movement = row.length > 5
          ? row[5]?.toString().trim() ?? ''
          : '';
      final String position = row.length > 6
          ? row[6]?.toString().trim() ?? ''
          : '';
      final missionMatch = RegExp(
        r'm(\d+)',
      ).firstMatch(row[0]?.toString() ?? '');

      final int mission = currentMission ?? 1;

      // RD parsing
      final resolvedAttackRaw = resolveRD(attackRaw);
      final resolvedMovement = resolveRD(movement);
      final resolvedPosition = resolveRD(position);

      final int? order = parseOrder(shape);

      double? attackSeconds;
      double? attackDamage;

      final attackMatch =
        RegExp(r'\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)')
            .firstMatch(resolvedAttackRaw);

      if (attackMatch != null) {
        attackSeconds = double.tryParse(attackMatch.group(1)!);
        attackDamage  = double.tryParse(attackMatch.group(2)!);
      }

      final enemy = EnemyData(
        command: command,
        shape: shape,
        movement: resolvedMovement,
        position: resolvedPosition,
        mission: currentMission ??= 1,
        attackSeconds: attackSeconds,
        attackDamage: attackDamage,
        order: order,
        energy: energy,
        darkYN: darkYN,
      );

      currentMissionMap!.putIfAbsent(currentMission!, () => []).add(enemy);
      // );
    }

    return stages;
  }

  String _safeGet(List<String> cells, int index) {
    if (index < cells.length) return cells[index];
    return '';
  }

  int? parseOrder(String shape) {
    // print("shape = $shape");
    if (!shape.contains('_')) return null;

    final parts = shape.split('_');
    if (parts.length != 2) {
      // print('parts length = ${parts.length}');
      throw FormatException('Invalid order format-parts: $shape');
    }

    final OEParse = parts[1].split('(');

    final order = int.tryParse(OEParse[0]);
    if (order == null) {
      throw FormatException('Invalid order value in-order: $shape');
    }

    print("shape $shape order = $order");
    return order;
  }

  String resolveRD(String str) {
    return str.replaceAllMapped(
      RegExp(r'RD\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)'),
          (match) {
        final min = double.parse(match.group(1)!);
        final max = double.parse(match.group(2)!);
        final random = _random.nextDouble() * (max - min) + min;
        final truncated = random.truncate();
        return truncated.toStringAsFixed(0);
      },
    );
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
      final resolved = resolveRD(rawValue);
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

  StageData({
    required this.name,
    required this.reward,
    required this.timeLimit,
    required this.missions,
    required this.missionTimeLimits,
    required this.missionTitle,
  });

  @override
  String toString() {
    return '[$name, reward: $reward, missions: ${missions.keys}, missionTitle: $missionTitle, missionTimeLimits: $missionTimeLimits]';
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
