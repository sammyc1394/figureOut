import 'dart:math' as math;

import 'package:flutter/material.dart';

// 버튼 배경을 완벽한 둥근 사각형이 아니라 손으로 그린 듯 부드럽게 울렁이도록
// 그리기 위한 페인터. 둘레를 따라 몇 개의 "제어점"에 각각 독립적인 랜덤 변위를
// 주고, 그 사이를 코사인 보간으로 부드럽게 이어서 굴곡의 크기와 간격이 조금씩
// 다른 손그림 느낌의 웨이브를 만든다. (완벽한 사인파는 굴곡이 전부 똑같은
// 크기로 반복돼서 톱니바퀴처럼 기계적으로 보인다.)
//
// 위상은 반드시 실제 호 길이(arc length) 기준으로 계산해야 한다. 점 인덱스
// (i/n) 기준으로 계산하면 모서리(코너)는 짧은 거리에 점이 몰려 있어 같은
// 인덱스 간격이라도 실제 이동 거리가 짧아지고, 그만큼 같은 파장이 더 좁은
// 공간에 눌려 들어가면서 진폭이 반지름보다 커져 스스로 겹치는 뾰족한 스파이크가
// 생긴다.
class WigglyButtonPainter extends CustomPainter {
  final Color color;
  final int seed;
  final double amplitude;
  final double radius;

  WigglyButtonPainter({
    required this.color,
    this.seed = 1,
    this.amplitude = 3.0,
    required this.radius,
  });

  static const _pointsPerCorner = 24;
  static const _pointsPerStraightEdge = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildBlobPath(size);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  Path _buildBlobPath(Size size) {
    final w = size.width;
    final h = size.height;
    final r = radius.clamp(0.0, math.min(w, h) / 2);

    final base = <_PerimeterPoint>[];

    void addArc(Offset center, double startAngle, double sweep) {
      for (int i = 0; i < _pointsPerCorner; i++) {
        final t = i / _pointsPerCorner;
        final angle = startAngle + sweep * t;
        final normal = Offset(math.cos(angle), math.sin(angle));
        base.add(_PerimeterPoint(center + normal * r, normal));
      }
    }

    void addEdge(Offset from, Offset to, Offset normal) {
      for (int i = 0; i < _pointsPerStraightEdge; i++) {
        final t = i / _pointsPerStraightEdge;
        base.add(_PerimeterPoint(Offset.lerp(from, to, t)!, normal));
      }
    }

    addArc(Offset(r, r), math.pi, math.pi / 2); // top-left: 180 -> 270
    addEdge(Offset(r, 0), Offset(w - r, 0), const Offset(0, -1)); // top edge
    addArc(Offset(w - r, r), -math.pi / 2, math.pi / 2); // top-right: 270 -> 360
    addEdge(Offset(w, r), Offset(w, h - r), const Offset(1, 0)); // right edge
    addArc(Offset(w - r, h - r), 0, math.pi / 2); // bottom-right: 0 -> 90
    addEdge(Offset(w - r, h), Offset(r, h), const Offset(0, 1)); // bottom edge
    addArc(Offset(r, h - r), math.pi / 2, math.pi / 2); // bottom-left: 90 -> 180
    addEdge(Offset(0, h - r), Offset(0, r), const Offset(-1, 0)); // left edge

    final n = base.length;

    // 실제 호 길이 기준 누적 거리 -> [0,1) 구간의 위상으로 정규화한다.
    final cumulative = List<double>.filled(n, 0);
    double perimeter = 0;
    for (int i = 0; i < n; i++) {
      cumulative[i] = perimeter;
      perimeter += (base[(i + 1) % n].position - base[i].position).distance;
    }

    // 굴곡 하나(제어점 간격)가 버튼 높이의 약 0.3배가 되도록 제어점 개수를 정한다.
    // (더 잦은 굴곡을 원해서 이전(0.45배)보다 더 촘촘하게 잡았다.)
    final segmentLength = h * 0.13;
    final controlCount = (perimeter / segmentLength).round().clamp(8, 128);

    // 각 제어점마다 독립적인 랜덤 변위(-1~1)를 주고, 둘레를 도는 점들은 자신이
    // 속한 두 제어점 사이를 코사인 보간으로 부드럽게 잇는다. 닫힌 루프이므로
    // 제어점 배열도 원형으로 이어진다(마지막 제어점 다음은 다시 첫 제어점).
    final random = math.Random(seed);
    final control = List<double>.generate(
      controlCount,
      (_) => random.nextDouble() * 2 - 1,
    );

    double noiseAt(double s) {
      final scaled = s * controlCount;
      final i0 = scaled.floor() % controlCount;
      final i1 = (i0 + 1) % controlCount;
      final t = scaled - scaled.floor();
      final smoothT = (1 - math.cos(t * math.pi)) / 2;
      return control[i0] + (control[i1] - control[i0]) * smoothT;
    }

    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final s = cumulative[i] / perimeter;
      final wobble = amplitude * noiseAt(s);
      points.add(base[i].position + base[i].normal * wobble);
    }

    return _smoothClosedPath(points);
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

      final cp1 = p1 + (p2 - p0) / 6.0;
      final cp2 = p2 - (p3 - p1) / 6.0;

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant WigglyButtonPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.seed != seed ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.radius != radius;
  }
}

class _PerimeterPoint {
  final Offset position;
  final Offset normal;
  _PerimeterPoint(this.position, this.normal);
}
