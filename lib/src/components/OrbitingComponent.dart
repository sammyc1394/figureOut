import 'dart:math' as math;
import 'package:flame/components.dart';

class OrbitingComponent extends Component with HasGameReference {
  final PositionComponent target;
  final Vector2 center;
  final double radius;
  final double angularSpeed; // radian/sec
  double angle = 0;

  OrbitingComponent({
    required this.target,
    required this.center,
    required this.radius,
    required this.angularSpeed,
  });

  @override
  Future<void> onLoad() async {
    angle = 0; // 초기화
  }

  @override
  void update(double dt) {
    super.update(dt);
    angle += angularSpeed * dt;
    target.position =
        center + Vector2(radius * math.cos(angle), radius * math.sin(angle));
    print('[ORBIT] Updated position: ${target.position}');
  }
}
