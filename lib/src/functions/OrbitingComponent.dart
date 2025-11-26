import 'dart:math' as math;
import 'package:flame/components.dart';

class OrbitingComponent extends Component with HasGameReference {
  final PositionComponent target;
  final Vector2 center;
  final double radiusX;      // 가로 반지름
  final double radiusY;      // 세로 반지름
  final double angularSpeed; // radian/sec
  double angle = 0;

  OrbitingComponent({
    required this.target,
    required this.center,
    required this.radiusX,
    double? radiusYParam,     // null 이면 원 궤도로 사용
    required this.angularSpeed,
  }): radiusY = radiusYParam ?? radiusX;

  @override
  Future<void> onLoad() async {
    angle = 0; // 초기화
  }

  @override
  void update(double dt) {
    super.update(dt);
    angle += angularSpeed * dt;
    final x = center.x + radiusX * math.cos(angle);
    final y = center.y + radiusY * math.sin(angle);

    target.position.setValues(x, y);
  }
}
