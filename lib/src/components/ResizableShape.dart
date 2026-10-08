import 'package:flame/components.dart';

// Game shapes whose size can change after spawn (e.g. Circle S(4, 7, 9) (1) —
// README "Size change"). Each shape caches size-derived values (outline path,
// attack ring, HP text/badge layout), so changing `size` alone drifts those
// caches. This method updates `size` and the caches together.
abstract class ResizableShape {
  void setShapeSize(Vector2 newSize);
}
