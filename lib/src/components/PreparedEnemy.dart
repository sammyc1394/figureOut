import 'package:flame/components.dart';
import '../behaviors/shapeBehavior.dart';
import '../config.dart';

class PreparedEnemy {
  final String shapeType;
  final int energy;
  final bool isDark;
  final Vector2 actPosition;
  final Vector2 customSize;

  final int? order;
  final double? attackTime;
  final double? attackDamage;
  final ShapeBehavior? behavior;
  final bool isBlinking;
  final double angle;
  final ShapeZOrder zOrder;

  // 사이즈 변경 (Circle S(4, 7, 9) (1)): customSize로 생성된 뒤
  // sizeChangeSeconds초에 걸쳐 sizeChangeTarget 크기가 된다. 둘 다 null이면 고정 크기.
  final Vector2? sizeChangeTarget;
  final double? sizeChangeSeconds;

  const PreparedEnemy({
    required this.shapeType,
    required this.energy,
    required this.isDark,
    required this.actPosition,
    this.attackTime,
    this.attackDamage,
    required this.order,
    required this.behavior,
    required this.customSize,
    this.isBlinking = false,
    this.angle = 0.0,
    this.zOrder = ShapeZOrder.normal,
    this.sizeChangeTarget,
    this.sizeChangeSeconds,
  });

  @override
  String toString() {
    return 'PreparedEnemy('
        'shapeType: $shapeType, '
        'energy: $energy, '
        'isDark: $isDark, '
        'actPosition: $actPosition, '
        'order: $order, '
        'behavior: ${behavior?.runtimeType}'
        ')';
  }
}
