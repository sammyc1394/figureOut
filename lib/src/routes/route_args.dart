import '../functions/sheet_service.dart';

class MissionRouteArgs {
  final List<StageData> stages;
  final int stageIndex;

  const MissionRouteArgs({
    required this.stages,
    required this.stageIndex,
  });
}

class GameRouteArgs {
  final List<StageData> stages;
  final int stageIndex;
  final int missionIndex;

  const GameRouteArgs({
    required this.stages,
    required this.stageIndex,
    required this.missionIndex,
  });
}
