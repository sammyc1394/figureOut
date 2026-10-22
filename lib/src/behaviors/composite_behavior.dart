import 'dart:async';

import 'package:flame/components.dart';
import 'package:figureout/src/behaviors/shapeBehavior.dart';
import 'package:figureout/src/behaviors/ZCommand.dart';

class CompositeBehavior implements ShapeBehavior {
  final List<ShapeBehavior> behaviors;

  CompositeBehavior(this.behaviors);

  @override
  Future<void> apply(PositionComponent shape) async {
    // 각 Behavior의 실행을 시작하되, 다른 Behavior의 완료를 기다리지 않음
    await Future.wait(
      behaviors.map((behavior) => behavior.apply(shape)),
    );
  }

  // TimingCommand가 유한 Z 경로의 완료를 기다릴 수 있도록 제공
  Future<void> get sequenceDone async {
    await Future.wait(
      behaviors.whereType<ZCommand>().map((z) => z.sequenceDone),
    );
  }

  @override
  String get command => 'Composite';
}