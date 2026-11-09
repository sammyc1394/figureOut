import 'dart:ui';

import 'package:flame/components.dart';

class FallingClippedPiece extends PositionComponent {
  // clipPath is built in the source rectangle coordinate space.
  final Path clipPath;

  // clipPath의 bounds.left/top (원본 좌표계에서 조각이 시작되는 위치)
  // -> 이걸 (0,0)으로 당겨와서 "조각 로컬 좌표"로 clip 먹여야 함
  final Vector2 clipOffset;

  // Source render size. Usually RectangleShape.size.
  final Vector2 sourceSize;

  Vector2 velocity;

  final double angularVelocity;
  final Color fillColor; // 디버그/대체 렌더용

  double gravity;
  double _rot = 0.0;
  double? _maxRemoveY;

  // options
  final bool drawOutlineDebug;

  FallingClippedPiece({
    required Vector2 position,
    required Vector2 sizePx, // 조각의 "보이는" bbox 크기 (bounds.width/height)
    required this.clipPath,
    required this.clipOffset,
    required this.sourceSize,
    required this.velocity,
    required this.angularVelocity,
    required this.fillColor,
    this.gravity = 1800.0,
    this.drawOutlineDebug = false,
  }) : super(
          position: position,
          size: sizePx,
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final g = findGame();
    _maxRemoveY = (g?.size.y ?? 1000.0) + 350.0;
  }

  @override
  void update(double dt) {
    super.update(dt);

    velocity.y += gravity * dt;
    position += velocity * dt;

    _rot += angularVelocity * dt;
    angle = _rot;

    final maxY = _maxRemoveY;
    if (maxY != null && position.y > maxY) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();

    // 1) 조각 로컬 좌표로 clipPath 이동
    final localClip = clipPath.shift(Offset(-clipOffset.x, -clipOffset.y));

    // 2) clip 적용
    canvas.clipPath(localClip);

    // 3) 원본을 조각 로컬에 맞게 끌어오기
    // (원본 좌표계에서 clipOffset이 조각의 (0,0)이 되도록 이동)
    canvas.translate(-clipOffset.x, -clipOffset.y);

    // 4) Canvas render
    final rect = Rect.fromLTWH(0, 0, sourceSize.x, sourceSize.y);
    final shortestSide =
        sourceSize.x < sourceSize.y ? sourceSize.x : sourceSize.y;
    final radius = Radius.circular(
      (shortestSide * 0.08).clamp(4.0, 8.0),
    );
    final rrect = RRect.fromRectAndRadius(rect, radius);

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = fillColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    if (drawOutlineDebug) {
      canvas.save();
      // 다시 조각 로컬로 되돌려서 localClip outline 표시
      canvas.translate(clipOffset.x, clipOffset.y);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawPath(localClip, p);
      canvas.restore();
    }

    canvas.restore();
  }
}
