import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'dart:math' as math;

import 'components/CircleShape.dart';
import 'components/HexagonShape.dart';
import 'components/PentagonShape.dart';
import 'components/RectangleShape.dart';
import 'components/TriangleShape.dart';
import 'config.dart';

class OneSecondGame extends FlameGame with DragCallbacks, CollisionCallbacks, PanDetector {

  final math.Random _random = math.Random();

  Vector2? sliceStartPoint;
  Vector2? sliceEndPoint;

  Future<void> onLoad() async {
    super.onLoad();

    spawnShapes();

    debugMode = true;
  }

  @override
  void onDragStart(DragStartEvent event) {
    // TODO: implement onDragStart
    event.localPosition;
  }

  @override
  void onDragEnd(DragEndEvent event) {

  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);

    Vector2 startPoint = event.canvasStartPosition;
    Vector2 endPoint = event.canvasEndPosition;

    componentsAtPoint(event.canvasStartPosition).forEach((element) {
      if (element is RectangleShape) {
        double startX = startPoint.x;
        double startY = startPoint.y;
        double endX = endPoint.x;
        double endY = endPoint.y;

        print("startPoint : ($startX, $startY), endPoint : ($endX, $endY)");

        var splitsShapes = <PositionComponent>[];

        splitsShapes = element.touchAtPoint(startPoint, endPoint);
        Future.delayed(Duration(seconds: 1), () {
          removeAll(splitsShapes);
        });
      }

    });
  }

  @override
  void onPanStart(DragStartInfo info) {
    info.eventPosition;
  }

  void spawnShapes() {
    final size = this.size;
    final shapes = <PositionComponent>[];

    while (shapes.length < 10) {
      final type = _random.nextInt(3); // 0: circle, 1: rect, 2: pentagon
      final position = Vector2(
        _random.nextDouble() * (size.x - 100),
        _random.nextDouble() * (size.y - 100),
      );

      PositionComponent shape;
      switch (type) {
        case 0:
          shape = CircleShape(position, _random.nextInt(10) + 1);
          break;
        case 1:
          shape = RectangleShape(position);
          break;
        case 2:
          shape = PentagonShape(position, _random.nextInt(50));
          break;
        case 3:
          shape = TriangleShape(position);
          break;
        case 4:
          shape = HexagonShape(position);
          break;
        default:
          shape = CircleShape(position, _random.nextInt(10) + 1);
          ;
      }

      // 겹침 방지
      bool isOverlapping = shapes.any((s) =>
          s.toRect().overlaps(shape.toRect()));
      if (!isOverlapping && (position.x < gameWidth - 100 && position.y < gameHeight - 100)) {
        shapes.add(shape);
        add(shape);
      }
    }
  }
}

