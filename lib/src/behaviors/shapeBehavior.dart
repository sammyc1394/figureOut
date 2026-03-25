import 'package:flame/components.dart';

abstract class ShapeBehavior {
  Future<void> apply(PositionComponent shape);

  String get command; // ex : C, D, DR,...
}