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

    for (var row in values) {
      final cells = row.map((e) => (e ?? '').toString().trim()).toList();
      final String? cell = row.isNotEmpty ? row[0]?.toString().trim() : null;
      if (cell != null && cell.startsWith('s')) {
        firstMissionHeaderSeen = false;
        // final String reward = row.length > 6
        //     ? row[6]?.toString().trim() ?? ''
        //     : '';
        // final String timeLimit = row.length > 7
        //     ? row[7]?.toString().trim() ?? ''
        //     : '';
        final rewardFromS = _safeGet(cells, 7); // I
        final timeFromS = _safeGet(cells, 8); // J

        print("rewardFromS = $rewardFromS, timeFromS = $timeFromS");

        currentMissionMap = {};
        timeLimitMap = {};
        currentStage = StageData(
          name: cell,
          // reward: reward,
          reward: rewardFromS,
          timeLimit: timeFromS,
          missions: currentMissionMap!,
          missionTimeLimits: timeLimitMap!,
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
            final timeFromJ = _safeGet(cells, 8); // J
            final parsed = double.tryParse(timeFromJ);
            print("timeFromJ = $timeFromJ");
            if (parsed != null) {
              currentStage!.missionTimeLimits[currentMission] = parsed;
            }
          }

          if (currentStage != null && !firstMissionHeaderSeen) {
            firstMissionHeaderSeen = true;

            final rewardFromM = _safeGet(cells, 7); // H
            final timeFromM = _safeGet(cells, 8); // I

            print("rewardFromM = $rewardFromM, timeFromM = $timeFromM");

            if ((currentStage!.reward.isEmpty) && rewardFromM.isNotEmpty) {
              currentStage!.reward = rewardFromM;
            }
            if ((currentStage!.timeLimit.isEmpty) && timeFromM.isNotEmpty) {
              currentStage!.timeLimit = timeFromM;
            }

            print(
              '[STAGE "${currentStage!.name}"] '
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
      final String attackRaw= row.length > 4
          ? row[4]?.toString().trim() ?? ''
          : '';
      final int? order = parseOrder(shape);
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
      
      double? attackSeconds;
      double? attackDamage;

      final attackMatch =
        RegExp(r'\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)')
            .firstMatch(attackRaw);

      if (attackMatch != null) {
        attackSeconds = double.tryParse(attackMatch.group(1)!);
        attackDamage  = double.tryParse(attackMatch.group(2)!);
      }

      final enemy = EnemyData(
        command: command,
        shape: shape,
        movement: movement,
        position: position,
        mission: currentMission ??= 1,
        attackSeconds: attackSeconds,
        attackDamage: attackDamage,
        order: order,
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
    if(OEParse.length != 2) {
      throw FormatException('Invalid order value in-OEParse: $OEParse');
    }

    final order = int.tryParse(OEParse[0]);
    if (order == null) {
      throw FormatException('Invalid order value in-order: $shape');
    }

    return order;
  }
}

class StageData {
  final String name;
  String reward;
  String timeLimit; //Default time limit
  final Map<int, List<EnemyData>> missions;
  final Map<int, double> missionTimeLimits;

  StageData({
    required this.name,
    required this.reward,
    required this.timeLimit,
    required this.missions,
    required this.missionTimeLimits,
  });

  @override
  String toString() {
    return '[$name, reward: $reward, missions: ${missions.keys}, missionTimeLimits: $missionTimeLimits]';
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

  EnemyData({
    required this.command,
    required this.shape,
    required this.movement,
    required this.position,
    required this.mission,
    this.attackSeconds,
    this.attackDamage,
    this.order,
  });

  @override
  String toString() {
    return '[$command, $shape, $movement, $position, $mission, attack=($attackSeconds, $attackDamage), order=($order)]';
  }
}
