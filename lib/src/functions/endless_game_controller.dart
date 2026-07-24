import 'dart:math' as math;
import 'sheet_service.dart';

/// 무한모드 난이도 곡선 및 도형 동적 생성 엔진
class EndlessGameController {
  final math.Random _random = math.Random();

  // 원 빈도 증가, 삼각형 1/3로 축소된 가중치 풀
  static const List<String> _shapeTypesPool = [
    'Circle',
    'Circle',
    'Circle',
    'Rectangle',
    'Pentagon',
    'Triangle', // 1/3 비율
    'Hexagon',
  ];

  static const List<String> _movementPool = [
    'Z(0,0,1.5)',
    'Z(50,50,1.8)',
    'C(50,1.5)',
    'D(1.0,1.0)',
    'B(60,-60,1.5)',
    'Z(-50,100,2.0)',
  ];

  /// 경과 시간에 따른 스폰 간격 (1.2배 빠른 1.5초 -> 0.45초)
  double getSpawnInterval(double elapsedSeconds) {
    final baseInterval = 1.8 - (elapsedSeconds / 180.0) * 1.2;
    final interval = baseInterval / 1.2;
    return interval.clamp(0.45, 1.5);
  }

  /// 한 번에 스폰할 도형 개수 (1개 ~ 3개 버스트 스폰)
  int getBurstCount(double elapsedSeconds) {
    if (elapsedSeconds >= 45.0) {
      return _random.nextInt(3) + 1; // 1 ~ 3개
    } else if (elapsedSeconds >= 15.0) {
      return _random.nextDouble() < 0.45 ? 2 : 1; // 1 ~ 2개
    }
    return 1;
  }

  /// 무작위 EnemyData 생성 (경과 시간 elapsedSeconds 기반 난이도 스케일링)
  EnemyData generateRandomEnemy(double elapsedSeconds, int missionIndex) {
    // 15초 이후부터 검은 도형 출현 (약 18%)
    final isDark = (elapsedSeconds >= 15.0) && (_random.nextDouble() < 0.18);
    final shapeName = _shapeTypesPool[_random.nextInt(_shapeTypesPool.length)];

    // 에너지는 일반 1~3, 삼각형은 HP 1~2로 제한, 다크는 -1
    int energy = isDark ? -1 : (_random.nextInt(3) + 1);
    if (shapeName == 'Triangle' && !isDark) {
      energy = _random.nextInt(2) + 1; // 1 or 2
    }

    final scale = (0.8 + _random.nextDouble() * 0.4).toStringAsFixed(1);
    final fullShapeStr = '${shapeName}_scale($scale)_e($energy)';

    // 위치 (-120 ~ 120, -220 ~ 220)
    final posX = _random.nextInt(241) - 120;
    final posY = _random.nextInt(441) - 220;
    final positionStr = '($posX,$posY)';

    // 시간대별 기믹 적용:
    // 0 ~ 15초: 기본 정적 도형
    // 15 ~ 30초: 검은 도형 + 움직이는 도형 (Z, C, B, D)
    // 30 ~ 45초: 사라지는(Blinking) 도형 추가
    // 45 ~ 60초: 움직이면서 사라지는 도형 동시 출현
    // 60초 이상: 순서(Order 1, 2, 3...) 도형 추가
    String movementStr = '';
    bool isBlinking = false;
    int? order;

    if (elapsedSeconds >= 15.0) {
      final shouldMove = (elapsedSeconds >= 45.0) || (_random.nextDouble() < 0.7);
      if (shouldMove) {
        movementStr = _movementPool[_random.nextInt(_movementPool.length)];
      }
    }

    if (elapsedSeconds >= 30.0) {
      isBlinking = (elapsedSeconds >= 45.0) || (_random.nextDouble() < 0.55);
    }

    if (elapsedSeconds >= 60.0) {
      if (_random.nextDouble() < 0.4) {
        order = _random.nextInt(3) + 1; // 1, 2, 3 순서
      }
    }

    // 공격 시간: 검은 도형은 무조건 0.5초 ~ 3.0초 사이 자폭! 일반 도형은 3.0초 ~ 4.5초
    final double attackVal = isDark
        ? (0.5 + _random.nextDouble() * 2.5)
        : (3.0 + _random.nextDouble() * 1.5);
    final attackSec = attackVal.toStringAsFixed(1);

    return EnemyData(
      command: 'e',
      shape: fullShapeStr,
      movement: movementStr,
      position: positionStr,
      mission: missionIndex,
      energy: energy,
      darkYN: isDark,
      isBlinking: isBlinking,
      attackSeconds: double.tryParse(attackSec),
      attackDamage: 1.0,
      order: order,
    );
  }

  /// 45초 이후 블링킹/사라짐 기믹 적용 여부
  bool shouldBlink(double elapsedSeconds) {
    if (elapsedSeconds < 45.0) return false;
    return _random.nextDouble() < 0.5;
  }
}
