import 'package:flame/components.dart';

mixin DepthAware on PositionComponent {
  void updateVisualsByPriority();
  void updateVisualsByRank(double rank);
}
