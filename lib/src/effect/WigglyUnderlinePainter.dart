import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

class WigglyUnderlinePainter extends CustomPainter {
  final int seed;

  WigglyUnderlinePainter({this.seed = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final random = Random(seed);
    final path = Path();

    const step = 14.0;
    const wiggle = 1.0; // 핵심: 6 말고 1
    final baseY = size.height / 2;

    path.moveTo(0, baseY);

    for (double x = step; x <= size.width; x += step) {
      final y = baseY + (random.nextDouble() - 0.5) * wiggle;
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WigglyUnderlinePainter oldDelegate) {
    return oldDelegate.seed != seed;
  }
}