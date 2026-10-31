import 'package:flame/components.dart';

/// Initial movement waits delay attacks without pausing input or movement timers.
mixin AttackTimerGate on PositionComponent {
  bool waitingForInitialMovement = false;
}
