import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_svg/flame_svg.dart';
import 'package:flutter/material.dart';
import 'package:figureout/src/functions/UserRemovable.dart';
import 'dart:math' as math;

enum HexagonState {
  normal,
  autoGrowing,     // 손 뗀 뒤 자동 확장
  disappearing,
}

class HexagonShape extends PositionComponent
    with DragCallbacks, TapCallbacks, UserRemovable {

  double dragScale = 1.0;     // 드래그로 커지는 스케일
  double autoScale = 1.0;     // 자동 확장 스케일

  late final SvgComponent svg;
  int energy = 0;

  final bool isDark;
  final VoidCallback? onForbiddenTouch;

  HexagonState _state = HexagonState.normal;

  double _autoGrowT = 0.0;
  double _disappearT = 0.0;

  static const double triggerScale = 1.25;
  static const double maxAutoScale = 3.5;

  double _finalScale = 1.0;
  double _opacity = 1.0;

  // effect overlay reference (so we can avoid drawing inside this component)
  HexagonDisappearOverlay? _overlay; // ADDED

  // orientation fix - use a single canonical angle offset everywhere
  // This matches the "flat-top" hexagon look. If your svg is point-top, flip to 0.
  static const double _hexAngleOffset = -math.pi / 6;

  static const double extraDisappearScale = 1.25;

  HexagonShape(
    Vector2 position,
    this.energy, {
    this.isDark = false,
    this.onForbiddenTouch,
  }) : super(
          position: position,
          size: Vector2.all(100),
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final asset = isDark ? 'DarkHexagon.svg' : 'hexagon.svg';
    final svgData = await Svg.load(asset);

    svg = SvgComponent(
      svg: svgData,
      size: size,
      anchor: Anchor.center,
      position: size / 2,
    );

    add(svg);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (isDark) {
      onForbiddenTouch?.call();
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (isDark) {
      onForbiddenTouch?.call();
      return;
    }

    if (_state != HexagonState.normal) return;

    dragScale += 0.01;
    scale = Vector2.all(dragScale);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (_state != HexagonState.normal) return;

    if (dragScale >= triggerScale) {
      _startAutoGrow();
    }
  }

  void _startAutoGrow() {
    _state = HexagonState.autoGrowing;
    wasRemovedByUser = true;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_state == HexagonState.autoGrowing) {
      _autoGrowT += dt / 0.4;

      final t = Curves.easeOut.transform(_autoGrowT.clamp(0.0, 1.0));
      autoScale = 1.0 + t * maxAutoScale;

      scale = Vector2.all(dragScale * autoScale);

      if (_autoGrowT >= 1.0) {
        _finalScale = dragScale * autoScale;
        scale = Vector2.all(_finalScale);
        _state = HexagonState.disappearing;
      }
    }

    if (_state == HexagonState.disappearing) {
      _disappearT += dt / 0.35;

      // 0.0 ~ 1.0
      final t = _disappearT.clamp(0.0, 1.0);

      // 앞부분에서만 추가 확장 (0~0.25 구간)
      final extraT = (t / 0.25).clamp(0.0, 1.0);
      final extraScale =
          Curves.easeOut.transform(extraT) * (extraDisappearScale - 1.0);

      scale = Vector2.all(_finalScale * (1.0 + extraScale));

      _opacity = 1.0 - Curves.easeIn.transform(t);
      svg.opacity = _opacity;

      if (_disappearT >= 1.0) {
        removeFromParent();
      }
    }
  }

  void _startDisappear() {
    if (_state == HexagonState.disappearing) return; // ADDED
    _state = HexagonState.disappearing;

    _overlay = HexagonDisappearOverlay(
      sizePx: size.clone(),
      color: isDark ? Colors.grey : Colors.lightGreenAccent,
      angleOffset: _hexAngleOffset,
    );

    _overlay!.position = Vector2.zero();
    _overlay!.anchor = Anchor.center;
    _overlay!.priority = 9999; 
    add(_overlay!);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
  }

  @override
  Rect toRect() {
    return Rect.fromCenter(
      center: Offset(position.x, position.y),
      width: size.x * scale.x,
      height: size.y * scale.y,
    );
  }
}

// ===================================================================
// overlay component that draws ONLY the outline and only fades out (no stroke animation)
class HexagonDisappearOverlay extends PositionComponent {
  final Color color;
  final double angleOffset;

  double _progress = 0.0;

  HexagonDisappearOverlay({
    required Vector2 sizePx,
    required this.color,
    required this.angleOffset,
  }) : super(
          size: sizePx,
          anchor: Anchor.center,
        );

  void setProgress(double p) {
    _progress = p.clamp(0.0, 1.0);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final alpha = ((1.0 - Curves.easeIn.transform(_progress)) * 255)
        .clamp(0.0, 255.0)
        .toInt();

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..isAntiAlias = true
      ..color = color.withAlpha(alpha);

    final center = Offset(size.x / 2, size.y / 2);
    final radius = size.x / 2;

    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i + angleOffset; // fixed orientation
      final p = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();

    canvas.drawPath(path, paint);
  }
}
