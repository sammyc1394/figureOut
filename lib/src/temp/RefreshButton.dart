import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class RefreshButton extends PositionComponent with TapCallbacks, GestureHitboxes {
  final VoidCallback onPressed;
  final double radius;

  RefreshButton({
    required Vector2 position,
    required this.onPressed,
    this.radius = 25.0,
  }) : super(
    position: position,
    size: Vector2.all(radius * 2),
    anchor: Anchor.center,
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 반드시 충돌 판정 허용(Hitbox)
    add(RectangleHitbox()
      ..collisionType = CollisionType.passive);
  }

  @override
  bool onTapDown(TapDownEvent event) {
    print("Refresh button pressed - to the function");
    onPressed();
    return true;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw white background circle
    final backgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      radius,
      backgroundPaint,
    );

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      radius,
      borderPaint,
    );

    // Draw green refresh arrow
    final arrowPaint = Paint()
      ..color = Colors.green.shade600
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.x / 2, size.y / 2);
    final arrowRadius = radius * 0.6;

    // Draw the circular arrow arc (about 270 degrees)
    final rect = Rect.fromCircle(center: center, radius: arrowRadius);
    canvas.drawArc(
      rect,
      -math.pi / 2, // Start angle (top)
      3 * math.pi / 2, // Sweep angle (270 degrees)
      false,
      arrowPaint,
    );

    // Draw arrowhead
    final arrowheadSize = 6.0;
    final arrowheadAngle = math.pi / 6; // 30 degrees

    // Calculate arrowhead position (end of the arc)
    final endAngle = -math.pi / 2 + 3 * math.pi / 2; // 5π/2 - π/2 = π
    final arrowEndX = center.dx + arrowRadius * math.cos(endAngle);
    final arrowEndY = center.dy + arrowRadius * math.sin(endAngle);

    // Calculate arrowhead points
    final arrowhead1X = arrowEndX + arrowheadSize * math.cos(endAngle + arrowheadAngle + math.pi);
    final arrowhead1Y = arrowEndY + arrowheadSize * math.sin(endAngle + arrowheadAngle + math.pi);

    final arrowhead2X = arrowEndX + arrowheadSize * math.cos(endAngle - arrowheadAngle + math.pi);
    final arrowhead2Y = arrowEndY + arrowheadSize * math.sin(endAngle - arrowheadAngle + math.pi);

    // Draw arrowhead lines
    canvas.drawLine(
      Offset(arrowEndX, arrowEndY),
      Offset(arrowhead1X, arrowhead1Y),
      arrowPaint,
    );

    canvas.drawLine(
      Offset(arrowEndX, arrowEndY),
      Offset(arrowhead2X, arrowhead2Y),
      arrowPaint,
    );
  }
}