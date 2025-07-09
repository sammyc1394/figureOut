import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';


class PentagonShape extends PositionComponent with HasPaint, TapCallbacks {
  final List<Vector2> vertices;
  int energy = 0;
  bool _isLongPressing = false;

  PentagonShape(Vector2 position, int energy)
      : vertices = [
          Vector2(38, 0),
          Vector2(0, 28),
          Vector2(15, 72),
          Vector2(61, 72),  // -32
          Vector2(76, 28),
        ],
        super(
          position: position,
          anchor: Anchor.center,
        ) {
    // Set up the paint
    paint = Paint()..color = const Color(0xFFF5C6C6);
    this.energy = energy;
    // Calculate the size based on vertices bounds
    _calculateSize();
  }

  void _calculateSize() {
    double minX = vertices.map((v) => v.x).reduce((a, b) => a < b ? a : b);
    double maxX = vertices.map((v) => v.x).reduce((a, b) => a > b ? a : b);
    double minY = vertices.map((v) => v.y).reduce((a, b) => a < b ? a : b);
    double maxY = vertices.map((v) => v.y).reduce((a, b) => a > b ? a : b);

    size = Vector2(maxX - minX, maxY - minY);
  }

  @override
  void render(Canvas canvas) {
    // Create the pentagon path
    Path pentagonPath = Path();

    // Move to the first vertex
    pentagonPath.moveTo(vertices[0].x, vertices[0].y);

    // Draw lines to all other vertices
    for (int i = 1; i < vertices.length; i++) {
      pentagonPath.lineTo(vertices[i].x, vertices[i].y);
    }

    // Close the path
    pentagonPath.close();

    // Fill the pentagon
    canvas.drawPath(pentagonPath, paint);

    // Draw the border
    Paint borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(pentagonPath, borderPaint);

    // Draw the label
    if (energy != 0) {
      _drawText(canvas, energy.toString());
    }
  }

  void _drawText(Canvas canvas, String text) {
    final textStyle = TextStyle(color: Colors.black, fontSize: 20);
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((size.x - textPainter.width) / 2, (size.y - textPainter.height) / 2));
  }


  @override
  void onLongTapDown(TapDownEvent event) {
    super.onLongTapDown(event);

    print("presseddddd");
    _isLongPressing = true;

    _startLongPress(); // Consume the event
  }



  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);

    print("stoppppped");
    _stopLongPress();
  }

  void _startLongPress() {
    _isLongPressing = true;
    _startRepeatingDecrement();
  }

  void _stopLongPress() {
    _isLongPressing = false;
  }

  void _startRepeatingDecrement() {
    // Use Flame's built-in timer approach
    add(TimerComponent(
      period: 0.03, // 0.3 seconds
      repeat: _isLongPressing,
      onTick: () {
        if (energy > 0) {
          if(_isLongPressing) {
            energy-=1;
            // print('Number decreased to: $energy, press status : $_isLongPressing');
          } else {
            _stopLongPress();
          }
        } else {
          removeFromParent();
        }
      },
    ));
  }
}