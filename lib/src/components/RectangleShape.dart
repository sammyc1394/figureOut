
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import 'SliceMath.dart';
import 'SlicedRectangle.dart';

class RectangleShape extends RectangleComponent with GestureHitboxes {
  // int energy = 0;

  RectangleShape(Vector2 position)
      : super(
    size: Vector2(30, 60),
    paint: Paint()..color = const Color(0xFF673AB7),
  ) {
    this.position = position;
    // this.energy = energy;
  }

  List<PositionComponent> touchAtPoint(Vector2 StartPoint, Vector2 EndPoint) {

    var splitsShapes = <PositionComponent>[];

    List<List<Vector2>> slicePaths = SliceMath.getSlicePath(StartPoint, EndPoint, size, position);

    splitsShapes.add(
        SlicedRectangle(position, slicePaths[0])
    );

    splitsShapes.add(
        SlicedRectangle(position, slicePaths[1])
    );

    findGame()?.addAll(splitsShapes);

    // remove the original rectangle shape
    removeFromParent();

    // returning sliced shapes
    return splitsShapes;
  } // ~ touchAtPoint

}