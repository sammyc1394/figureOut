import 'package:flame/components.dart';
import '../behaviors/shapeBehavior.dart';

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