import '../functions/sheet_service.dart';

class StageRouteArgs {
  final List<StageData> stages;
  final int initialStageIndex;

  const StageRouteArgs({
    required this.stages,
    this.initialStageIndex = 0,
  });
}

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
