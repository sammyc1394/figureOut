import 'package:figureout/src/config/config.dart';
import 'package:flame/components.dart';

/// Maps editor coordinates whose Y axis has already been flipped to screen Y.
Vector2 editorToPlayArea(
  Vector2 yourCoordinates, {
  required Vector2 playCenter,
  required Vector2 playSize,
  required double safeRangeX,
  required double playAreaScaleY,
  required double actShapePadding,
  required bool clampInside,
}) {
  // 1) playArea 전역 영역 계산
  final double playMinX = playCenter.x - playSize.x / 2;
  final double playMaxX = playCenter.x + playSize.x / 2;

  // 2) 가로 배치는 기존 반폭 보정을 사용한다.
  final double minCenterX = playMinX + actShapePadding;
  final double maxCenterX = playMaxX - actShapePadding;

  // 3) 에디터 좌표 → 정규화. clampInside=false면 0~1 밖도 허용해서
  //    시트 좌표(-190 등)를 그대로 두고 도형이 playArea 밖으로 삐쳐도 된다.
  double normalizedX = (yourCoordinates.x - minX) / safeRangeX;
  double editorY = yourCoordinates.y;
  if (clampInside) {
    normalizedX = normalizedX.clamp(0.0, 1.0);
    editorY = editorY.clamp(minY, maxY);
  }

  // 4) playArea 상대 좌표 → 절대 좌표 변환 (범위 밖이면 경계 밖으로 외삽)
  double playX = minCenterX + (normalizedX * (maxCenterX - minCenterX));
  // 세로 좌표는 도형 크기와 무관한 공통 눈금을 사용한다.
  final double playY = playCenter.y + editorY * playAreaScaleY;

  // 5) 가로 범위를 제한할 때 도형이 플레이 영역보다 넓으면 가운데에 둔다.
  if (clampInside) {
    if (minCenterX > maxCenterX) {
      // 도형이 화면보다 가로로 더 큰 경우: 화면 중앙 X
      playX = playCenter.x;
    } else {
      playX = playX.clamp(minCenterX, maxCenterX);
    }
  }
  return Vector2(playX, playY);
}

Vector2 worldToPlayLocal(
  Vector2 worldPos, {
  required Vector2 playCenter,
  required Vector2 playSize,
}) {
  final double playMinX = playCenter.x - playSize.x / 2;
  final double playMinY = playCenter.y - playSize.y / 2;

  // playArea 왼쪽 위를 (0,0)으로 보는 로컬 좌표
  return Vector2(worldPos.x - playMinX, worldPos.y - playMinY);
}

Vector2 playLocalToVirtual(Vector2 local, Vector2 playSize) {
  final vx = local.x / playSize.x * targetPlayWidth;
  final vy = local.y / playSize.y * targetPlayHeight;
  return Vector2(vx, vy);
}
