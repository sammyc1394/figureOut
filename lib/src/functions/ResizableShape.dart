import 'package:flame/components.dart';

// 스폰 이후 크기가 바뀔 수 있는 게임 도형 (Circle S(4, 7, 9) (1) — README "Size change").
// 각 도형은 size에서 파생된 값(외곽선 Path, 공격 링, HP 텍스트/뱃지 위치)을 캐시해
// 두므로 size만 바꾸면 어긋난다. 이 메서드가 size와 그 캐시를 함께 갱신한다.
abstract class ResizableShape {
  void setShapeSize(Vector2 newSize);
}
