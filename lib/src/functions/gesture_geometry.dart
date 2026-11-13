import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import 'package:flame/components.dart';

int _orientation(Vector2 a, Vector2 b, Vector2 c) {
  final v = (b.y - a.y) * (c.x - b.x) - (b.x - a.x) * (c.y - b.y);
  const eps = 1e-9;
  if (v.abs() < eps) return 0; // collinear
  return (v > 0) ? 1 : 2; // 1: clockwise, 2: counterclockwise
}

bool _onSegment(Vector2 a, Vector2 b, Vector2 c) {
  // b is on segment ac (collinear assumed)
  return b.x >= math.min(a.x, c.x) - 1e-9 &&
      b.x <= math.max(a.x, c.x) + 1e-9 &&
      b.y >= math.min(a.y, c.y) - 1e-9 &&
      b.y <= math.max(a.y, c.y) + 1e-9;
}

bool _doLinesIntersect(Vector2 p1, Vector2 p2, Vector2 q1, Vector2 q2) {
  final o1 = _orientation(p1, p2, q1);
  final o2 = _orientation(p1, p2, q2);
  final o3 = _orientation(q1, q2, p1);
  final o4 = _orientation(q1, q2, p2);

  // general case
  if (o1 != o2 && o3 != o4) return true;

  // special collinear cases
  if (o1 == 0 && _onSegment(p1, q1, p2)) return true;
  if (o2 == 0 && _onSegment(p1, q2, p2)) return true;
  if (o3 == 0 && _onSegment(q1, p1, q2)) return true;
  if (o4 == 0 && _onSegment(q1, p2, q2)) return true;

  return false;
}

double calculatePolygonArea(List<Vector2> path) {
  double area = 0;
  for (int i = 0; i < path.length; i++) {
    final p1 = path[i];
    final p2 = path[(i + 1) % path.length];
    area += (p1.x * p2.y) - (p2.x * p1.y);
  }
  return area.abs() / 2.0;
}

bool isPointInPolygon(Vector2 p, List<Vector2> poly) {
  int count = 0;
  for (int i = 0; i < poly.length; i++) {
    final a = poly[i];
    final b = poly[(i + 1) % poly.length];
    if (((a.y > p.y) != (b.y > p.y)) &&
        (p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y + 0.0001) + a.x)) {
      count++;
    }
  }
  return count.isOdd;
}

double calculatePathLength(List<Vector2> path) {
  double len = 0;
  for (int i = 0; i < path.length - 1; i++) {
    len += path[i].distanceTo(path[i + 1]);
  }
  return len;
}

bool isStraightLine(List<Vector2> path) {
  if (path.length < 2) return false;

  final start = path.first;
  final end = path.last;

  final lineDir = (end - start);
  final len = lineDir.length;
  if (len == 0) return false;

  final norm = lineDir / len;

  double maxDeviation = 0;

  for (final p in path) {
    final v = p - start;
    final projLength = v.dot(norm).clamp(0, len).toDouble();
    final projPoint = start + norm * projLength;
    final deviation = p.distanceTo(projPoint);
    maxDeviation = math.max(maxDeviation, deviation);
  }

  return maxDeviation < 28; // 허용 오차
}

bool doesPathTouchRect(Rect rect, List<Vector2> path) {
  for (int i = 0; i < path.length - 1; i++) {
    final p1 = path[i];
    final p2 = path[i + 1];
    if (rect.contains(Offset(p1.x, p1.y)) || rect.contains(Offset(p2.x, p2.y))) {
      return true;
    }
    if (lineIntersectsRect(p1, p2, rect)) return true;
  }
  return false;
}

// 경로-폴리곤 충돌 판정 (ray-casting + 선분 교차)
bool doesPathTouchPolygon(List<Vector2> vertices, List<Vector2> path) {
  if (vertices.length < 3) return false;
  for (int i = 0; i < path.length - 1; i++) {
    final p1 = path[i];
    final p2 = path[i + 1];
    // 점이 폴리곤 내부에 있는지
    if (isPointInPolygon(p1, vertices) || isPointInPolygon(p2, vertices)) {
      return true;
    }
    // 선분이 폴리곤 변과 교차하는지
    for (int j = 0; j < vertices.length; j++) {
      final va = vertices[j];
      final vb = vertices[(j + 1) % vertices.length];
      if (_doLinesIntersect(p1, p2, va, vb)) return true;
    }
  }
  return false;
}
// 경로-원 충돌 판정
bool doesPathTouchCircle(Vector2 center, double radius, List<Vector2> path) {
  for (int i = 0; i < path.length - 1; i++) {
    final p1 = path[i];
    final p2 = path[i + 1];
    if ((p1 - center).length <= radius || (p2 - center).length <= radius) {
      return true;
    }
    if (_lineIntersectsCircle(p1, p2, center, radius)) return true;
  }
  return false;
}

// 선분-원 교차 판정
bool _lineIntersectsCircle(
  Vector2 p1,
  Vector2 p2,
  Vector2 center,
  double radius,
) {
  final d = p2 - p1;
  final f = p1 - center;
  final a = d.dot(d);
  if (a < 0.00001) return false;
  final b = 2 * f.dot(d);
  final c = f.dot(f) - radius * radius;
  double discriminant = b * b - 4 * a * c;
  if (discriminant < 0) return false;
  discriminant = math.sqrt(discriminant);
  final t1 = (-b - discriminant) / (2 * a);
  final t2 = (-b + discriminant) / (2 * a);
  return (t1 >= 0 && t1 <= 1) || (t2 >= 0 && t2 <= 1);
}

bool isRealSlice(List<Vector2> vertices, List<Vector2> path) {
  int hits = 0;

  for (int i = 0; i < path.length - 1; i++) {
    final p1 = path[i];
    final p2 = path[i + 1];

    final p1Inside = isPointInPolygon(p1, vertices);
    final p2Inside = isPointInPolygon(p2, vertices);

    if (p1Inside != p2Inside) {
      hits++;
      continue;
    }

    if (!p1Inside && !p2Inside) {
      int edgeHits = 0;
      for (int j = 0; j < vertices.length; j++) {
        if (_doLinesIntersect(
          p1,
          p2,
          vertices[j],
          vertices[(j + 1) % vertices.length],
        )) {
          edgeHits++;
        }
      }
      hits += edgeHits;
    }
  }

  return hits >= 2 || (hits >= 1 && isPointInPolygon(path.first, vertices));
}

bool lineIntersectsRect(Vector2 p1, Vector2 p2, Rect rect) {
  final edges = [
    [rect.topLeft, rect.topRight],
    [rect.topRight, rect.bottomRight],
    [rect.bottomRight, rect.bottomLeft],
    [rect.bottomLeft, rect.topLeft],
  ];

  for (final edge in edges) {
    if (_doLinesIntersect(
      p1,
      p2,
      Vector2(edge[0].dx, edge[0].dy),
      Vector2(edge[1].dx, edge[1].dy),
    )) {
      return true;
    }
  }
  return false;
}
