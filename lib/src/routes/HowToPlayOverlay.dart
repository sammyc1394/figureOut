import 'package:figureout/src/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;

class HowToPlayOverlay extends StatefulWidget {
  /// Called when the user dismisses the overlay. [dontShowAgain] is true when
  /// the "Don't show again" checkbox was ticked.
  final ValueChanged<bool> onContinue;

  const HowToPlayOverlay({super.key, required this.onContinue});

  @override
  State<HowToPlayOverlay> createState() => _HowToPlayOverlayState();
}

class _HowToPlayOverlayState extends State<HowToPlayOverlay> {
  bool _dontShowAgain = false;

  static const _items = [
    ('assets/Circle_basic.svg', 'Tap'),
    ('assets/Triangle_basic.svg', 'Trap'),
    ('assets/Rectangle_basic.svg', 'Slice'),
    ('assets/Pentagon_basic.svg', 'Hold'),
    ('assets/Hexagon_basic.svg', 'Stretch'),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final iconSize = screenWidth * 0.12;
    final fontSize = screenWidth * 0.048;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onContinue(_dontShowAgain),
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.65),
        child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 1),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final item in _items) ...[
                        _HowToPlayRow(
                          svgPath: item.$1,
                          label: item.$2,
                          iconSize: iconSize,
                          fontSize: fontSize,
                        ),
                        SizedBox(height: screenWidth * 0.075),
                      ],
                    ],
                  ),
                ),
                const Spacer(flex: 1),

                _DontShowAgainCheckbox(
                  checked: _dontShowAgain,
                  fontSize: fontSize,
                  spacing: screenWidth * 0.025,
                  onToggle: () =>
                      setState(() => _dontShowAgain = !_dontShowAgain),
                ),

                SizedBox(height: screenWidth * 0.04),

                Text(
                  'Tap to play!',
                  style: TextStyle(
                    fontFamily: appFontFamily,
                    fontSize: fontSize * 2,
                    fontWeight: FontWeight.w200,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
                SizedBox(height: screenWidth * 0.12),
              ],
            ),
          ),
        ),
    );
  }
}

class _DontShowAgainCheckbox extends StatelessWidget {
  final bool checked;
  final double fontSize;
  final double spacing;
  final VoidCallback onToggle;

  const _DontShowAgainCheckbox({
    required this.checked,
    required this.fontSize,
    required this.spacing,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            checked ? Icons.check_box : Icons.check_box_outline_blank,
            color: Colors.white,
            size: fontSize * 1.2,
          ),
          SizedBox(width: spacing),
          Text(
            "Don't show again",
            style: TextStyle(
              fontFamily: appFontFamily,
              fontSize: fontSize * 0.85,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _HowToPlayRow extends StatelessWidget {
  final String svgPath;
  final String label;
  final double iconSize;
  final double fontSize;

  const _HowToPlayRow({
    required this.svgPath,
    required this.label,
    required this.iconSize,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: iconSize * 1.8,
          height: iconSize * 1.55,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SvgPicture.asset(svgPath, fit: BoxFit.contain),

              _buildGesture(label, iconSize),
            ],
          ),
        ),
        SizedBox(width: iconSize * 0.5),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: appFontFamily,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ],
    );
  }
}

Widget _buildGesture(String label, double iconSize) {
  if (label.startsWith('Tap')) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _GesturePaint(iconSize: iconSize, type: GestureType.tap),
        Transform.translate(
          offset: Offset(iconSize * 0.52, iconSize * 0.35),
          child: _hand(iconSize),
        ),
      ],
    );
  }

  if (label.startsWith('Trap')) {
    return _GesturePaint(iconSize: iconSize, type: GestureType.trap);
  }

  if (label.startsWith('Slice')) {
    return _GesturePaint(iconSize: iconSize, type: GestureType.slice);
  }

  if (label.startsWith('Hold')) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _GesturePaint(iconSize: iconSize, type: GestureType.hold),
        Transform.translate(
          offset: Offset(iconSize * 0.52, iconSize * 0.35),
          child: _hand(iconSize),
        ),
      ],
    );
  }

  if (label.startsWith('Stretch')) {
    return _GesturePaint(iconSize: iconSize, type: GestureType.stretch);
  }

  return const SizedBox.shrink();
}

Widget _hand(double iconSize) {
  return Image.asset(
    'assets/tutorial_hand.png',
    width: iconSize * 2,
  );
}


class _GesturePaint extends StatelessWidget {
  final double iconSize;
  final GestureType type;

  const _GesturePaint({
    required this.iconSize,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: iconSize * 1.9,
      height: iconSize * 1.9,
      child: CustomPaint(
        painter: _GesturePainter(type),
        size: Size.infinite,
      ),
    );
  }
}

class _GesturePainter extends CustomPainter {
  final GestureType type;

  _GesturePainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (type) {
      case GestureType.tap:
        _drawTap(canvas, size, paint);
        break;
      case GestureType.trap:
        _drawTrap(canvas, size, paint);
        break;
      case GestureType.slice:
        _drawSlice(canvas, size, paint);
        break;
      case GestureType.hold:
        _drawHold(canvas, size, paint);
        break;
      case GestureType.stretch:
        _drawStretch(canvas, size, paint);
        break;
    }
  }

  void _drawSketchPath(Canvas canvas, Path path, Paint paint) {
    canvas.drawPath(path, paint);

    final paint2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path.shift(const Offset(1.2, -0.8)), paint2);
  }

  void _drawTrap(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;
    final random = math.Random(3); // 원하는 seed로 변경 가능

    Offset jitter(Offset p, double amount) {
      return p + Offset(
        (random.nextDouble() - 0.5) * amount,
        (random.nextDouble() - 0.5) * amount,
      );
    }

    final j = w * 0.035; // 지터 강도 (너무 크면 삼각형처럼 안 보임)

    final points = [
      jitter(Offset(w * 0.50, h * -0.08), j), // 꼭대기 (더 이상 음수 아님)
      jitter(Offset(w * 0.78, h * 0.28), j), // 오른쪽 어깨
      jitter(Offset(w * 0.94, h * 0.62), j), // 오른쪽 옆면
      jitter(Offset(w * 1.04, h * 1.02), j), // 오른쪽 아래 모서리
      jitter(Offset(w * 0.50, h * 1.08), j), // 아래 중앙
      jitter(Offset(w * -0.02, h * 1.02), j), // 왼쪽 아래 모서리
      jitter(Offset(w * 0.06, h * 0.62), j), // 왼쪽 옆면
      jitter(Offset(w * 0.22, h * 0.26), j), // 왼쪽 어깨
    ];

    final path = _smoothClosedPath(points);
    _drawSketchPath(canvas, path, paint);
  }

  Path _smoothClosedPath(List<Offset> points) {
    final path = Path();
    final n = points.length;
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < n; i++) {
      final p0 = points[(i - 1 + n) % n];
      final p1 = points[i];
      final p2 = points[(i + 1) % n];
      final p3 = points[(i + 2) % n];

      // Catmull-Rom → Bezier 제어점 변환
      final cp1 = p1 + (p2 - p0) / 6.0;
      final cp2 = p2 - (p3 - p1) / 6.0;

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    path.close();
    return path;
  }

  void _drawTap(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width * 0.59, size.height * 0.51);
    final random = math.Random(5);

    for (int i = 0; i < 5; i++) {
      final angle = (i / 5) * 2 * math.pi + (random.nextDouble() - 0.6) * 0.3;
      final innerR = size.width * 0.10;
      final outerR = size.width * 0.20 + (random.nextDouble() - 0.5) * size.width * 0.03;

      final from = center + Offset(math.cos(angle), math.sin(angle)) * innerR;
      final to = center + Offset(math.cos(angle), math.sin(angle)) * outerR;

      canvas.drawLine(from, to, paint);
    }
  }

  void _drawSlice(Canvas canvas, Size size, Paint paint) {
    final start = Offset(size.width * 0.05, size.height * 0.75);
    final end = Offset(size.width * 0.95, size.height * 0.22);

    final delta = end - start;
    final length = delta.distance;
    final angle = delta.direction; // 라디안 각도

    canvas.save();
    canvas.translate(start.dx, start.dy);
    canvas.rotate(angle);

    // 이제 로컬 좌표계에서는 (0,0) -> (length,0) 이 원래의 대각선 방향
    _drawWigglyLine(canvas, length, paint);

    canvas.restore();
  }

  void _drawWigglyLine(Canvas canvas, double length, Paint paint) {
    final random = math.Random(7); // 원하는 seed 값
    final path = Path();

    const step = 14.0;
    const wiggle = 1.0; // WigglyUnderlinePainter와 동일한 값

    path.moveTo(0, 0);

    for (double x = step; x <= length; x += step) {
      final y = (random.nextDouble() - 0.5) * wiggle;
      path.lineTo(x, y);
    }
    // 끝점까지 정확히 닿도록 마무리
    path.lineTo(length, (random.nextDouble() - 0.5) * wiggle);

    canvas.drawPath(path, paint);
  }

  void _drawHold(Canvas canvas, Size size, Paint paint) {
    // width 커질수록 오른쪽 작아질수록 왼쪽 height 커질수록 아래 작아질수록 위
    final center = Offset(size.width * 0.58, size.height * 0.50);
    final random = math.Random(9);

    for (int ring = 0; ring < 3; ring++) {
      final radius = size.width * (0.1 + ring * 0.09);
      final ringPaint = Paint()
        ..color = Colors.white.withValues(alpha: 1.0 - ring * 0.25)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();
      const segments = 24;
      for (int i = 0; i <= segments; i++) {
        final angle = (i / segments) * 2 * math.pi;
        final jitter = (random.nextDouble() - 0.5) * size.width * 0.01;
        final r = radius + jitter;
        final p = center + Offset(math.cos(angle), math.sin(angle)) * r;
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();

      canvas.drawPath(path, ringPaint);
    }
  }

  void _drawStretch(Canvas canvas, Size size, Paint paint) {
    // 왼쪽 위
    _drawArrow(canvas, size, paint,
        from: Offset(size.width * 0.27, size.height * 0.27),
        to: Offset(size.width * 0.02, size.height * 0.02));

    // 오른쪽 위
    _drawArrow(canvas, size, paint,
        from: Offset(size.width * 0.72, size.height * 0.30),
        to: Offset(size.width * 0.97, size.height * 0.03));

    // 왼쪽 아래
    _drawArrow(canvas, size, paint,
        from: Offset(size.width * 0.28, size.height * 0.71),
        to: Offset(size.width * 0.00, size.height * 0.96));

    // 오른쪽 아래
    _drawArrow(canvas, size, paint,
        from: Offset(size.width * 0.72, size.height * 0.71),
        to: Offset(size.width * 1.00, size.height * 0.96));
  }

  void _drawArrow(
      Canvas canvas,
      Size size,
      Paint paint, {
        required Offset from,
        required Offset to,
      }) {
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(
        (from.dx + to.dx) / 2 + size.width * 0.03,
        (from.dy + to.dy) / 2,
        to.dx,
        to.dy,
      );

    canvas.drawPath(path, paint);

    final angle = (to - from).direction;
    const headLength = 8.0;

    final left = Offset(
      to.dx - headLength * math.cos(angle - 0.7),
      to.dy - headLength * math.sin(angle - 0.7),
    );

    final right = Offset(
      to.dx - headLength * math.cos(angle + 0.7),
      to.dy - headLength * math.sin(angle + 0.7),
    );

    canvas.drawLine(to, left, paint);
    canvas.drawLine(to, right, paint);
  }

  @override
  bool shouldRepaint(covariant _GesturePainter oldDelegate) {
    return oldDelegate.type != type;
  }
}