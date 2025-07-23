import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SheetService {
  final String sheetId;
  final String apiKey;

  SheetService()
    : sheetId = dotenv.env['GOOGLESHEETID'] ?? '',
      apiKey = dotenv.env['GOOGLESHEETAPIKEY'] ?? '' {
    if (sheetId.isEmpty || apiKey.isEmpty) {
      throw Exception('Missing Google Sheet credentials in .env');
    }
  }
  String get sheetName => 'Stages & Missions';
  String get encodedSheetName => Uri.encodeComponent(sheetName);
  String get range => 'B3:I'; // Start from row 5, columns C~I

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
    Map<int, List<EnemyData>>? currentMissionMap;

    for (var row in values) {
      final String? cell = row.isNotEmpty ? row[0]?.toString().trim() : null;
      if (cell != null && cell.startsWith('s')) {
        final String reward = row.length > 6
            ? row[6]?.toString().trim() ?? ''
            : '';
        final String timeLimit = row.length > 7
            ? row[7]?.toString().trim() ?? ''
            : '';

        currentMissionMap = {};
        currentStage = StageData(
          name: cell,
          reward: reward,
          timeLimit: timeLimit,
          missions: currentMissionMap,
        );
        stages.add(currentStage);
        continue;
      }
      if (cell != null && cell.startsWith('m')) {
        // 미션 번호 갱신만
        final missionMatch = RegExp(r'm(\d+)').firstMatch(cell);
        // print(missionMatch);
        if (missionMatch != null) {
          currentMission = int.parse(missionMatch.group(1)!);
        }
        continue;
      }

      if (currentStage == null || currentMission == null) continue;

      final String command = row.length > 2
          ? row[2]?.toString().trim() ?? ''
          : '';

      if (command.isEmpty) continue;

      final String shape = row.length > 3
          ? row[3]?.toString().trim() ?? ''
          : '';
      final String movement = row.length > 4
          ? row[4]?.toString().trim() ?? ''
          : '';
      final String position = row.length > 5
          ? row[5]?.toString().trim() ?? ''
          : '';
      final missionMatch = RegExp(
        r'm(\d+)',
      ).firstMatch(row[0]?.toString() ?? '');
      // final mission = missionMatch != null
      //     ? int.parse(missionMatch.group(1)!)
      //     : 1;
      final int mission = currentMission ?? 1;

      // currentStage.enemies.add(
      final enemy = EnemyData(
        command: command,
        shape: shape,
        movement: movement,
        position: position,
        mission: currentMission ??= 1,
      );

      currentMissionMap!.putIfAbsent(currentMission!, () => []).add(enemy);
      // );
    }

    return stages;
  }
}

class StageData {
  final String name;
  final String reward;
  final String timeLimit;
  final Map<int, List<EnemyData>> missions;

  StageData({
    required this.name,
    required this.reward,
    required this.timeLimit,
    required this.missions,
  });

  @override
  String toString() {
    return '[$name, reward: $reward, timeLimit: $timeLimit, missions: $missions]';
  }
}

class EnemyData {
  final String command;
  final String shape;
  final String movement;
  final String position;
  final int mission;

  EnemyData({
    required this.command,
    required this.shape,
    required this.movement,
    required this.position,
    required this.mission,
  });

  @override
  String toString() {
    return '[$command, $shape, $movement, $position, $mission]';
  }
}
