import 'package:flame/components.dart';

mixin BlinkAlphaTarget on PositionComponent {
  double get blinkAlpha;

  void setBlinkAlpha(double alpha);
}
