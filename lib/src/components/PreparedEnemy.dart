import 'package:flame/components.dart';
import '../behaviors/shapeBehavior.dart';

class PreparedEnemy {
  final String shapeType;
  final int count;
  final bool isDark;
  final Vector2 actPosition;

  final int? order;
  final double? attackTime;
  final ShapeBehavior? behavior;

  const PreparedEnemy({
    required this.shapeType,
    required this.count,
    required this.isDark,
    required this.actPosition,
    this.attackTime,
    required this.order,
    required this.behavior,
    Vector2? customSize,
  });

  @override
  String toString() {
    return 'PreparedEnemy('
        'shapeType: $shapeType, '
        'count: $count, '
        'isDark: $isDark, '
        'actPosition: $actPosition, '
        'order: $order, '
        'behavior: ${behavior?.runtimeType}'
        ')';
  }
}