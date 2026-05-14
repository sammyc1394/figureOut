import 'package:flame/components.dart';

mixin OverlapHighlightable on PositionComponent {
  bool _isOverlapping = false;
  bool get isOverlapping => _isOverlapping;

  void setOverlapping(bool value) {
    _isOverlapping = value;
  }
}
