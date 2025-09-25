import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_svg/svg.dart';
import 'package:flame_svg/svg_component.dart';

class SvgButton extends PositionComponent with TapCallbacks {
  late SvgComponent svgComponent;
  final VoidCallback onTap;
  final String assetPath;

  SvgButton({
    required this.assetPath,
    Vector2? position,
    Vector2? size,
    required this.onTap,
  }) : super(position: position ?? Vector2.zero(), size: size ?? Vector2.all(100));

  @override
  Future<void> onLoad() async {
    final svg = await Svg.load(assetPath);
    svgComponent = SvgComponent(
      svg: svg,
      position: Vector2.zero(),
      size: size,
    );
    add(svgComponent);
  }

  @override
  void onTapUp(TapUpEvent event) {
    onTap();
    super.onTapUp(event);
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    return point.x >= 0 && point.x <= size.x && point.y >= 0 && point.y <= size.y;
  }
}

