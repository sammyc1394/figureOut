import 'dart:ui';

import 'package:flame/components.dart';

class SliceMath {

  /// s1 = slice start point Vector2
  /// s2 = slice end point Vector2
  /// size = world size of the rectangle
  /// position = world position
  static List<List<Vector2>> getSlicePath (Vector2 s1, Vector2 s2, Vector2 size, Vector2 position) {
    /**
     * direction of the slice line
     */
    Vector2 dir = s2 - s1;

    /**
     * equation for the line is s1 + dir + t(interval value), where t >=0 && t<=1
     * if t is more than one or less than zero, that means the slice is outside of the ractangle
     *
     * s1 + dir * t = p(random point)
     * t = (p - s1) / dir
     */
    Offset positionOffset = Offset(position.x, position.y);
    Rect box = Rect.fromCenter(center: positionOffset, width: size.x, height: size.y);

    /**
     * path1, path 2 = outline offsets of the rectangle world
     */
    List<Vector2> path1 = [];
    List<Vector2> path2 = [];

    List<Vector2> currentPath = path1;
    bool horizontal = false;

    // if((s1.x > box.left ) )
    // Vector2 sliceStartPoint = ();


    /**
     * start from
     * lower left -> upper left -> upper right -> lower right
     *
     * if horizontal is false, we are moving x direction
     *                is true, we are moving y direction
     */
    for(Vector2 corner in [
      Vector2(box.left, box.bottom),
      Vector2(box.left, box.top),
      Vector2(box.right, box.top),
      Vector2(box.right, box.bottom),
    ]) {
      currentPath.add(corner);
      /**
       * t -> to see if the cut point is actually in the rectangle box
       */
      double t = horizontal ? (corner.y - s1.y) / dir.y : (corner.x - s1.x) / dir.x;
      print("t : $t");
      // if (t >= 0 && t <= 1.0) {
        /**
         * cut point
         * If we are getting non-nullable, add ? in the end to make it nullable
         */
        Vector2? cp;
        if (horizontal) {
          double xVal = s1.x + dir.x * t;
          if (xVal >= box.left && xVal <= box.right) {
            cp = Vector2(xVal, corner.y);
          }
        } else {
          double yVal = s1.y + dir.y * t;
          if (yVal >= box.top && yVal <= box.bottom) {
            cp = Vector2(corner.x, yVal);
          }
        }
        if (cp != null) {
          currentPath.add(cp);
          currentPath = (currentPath == path1) ? path2 : path1;
          currentPath.add(cp);
        }
      // }
      horizontal = !horizontal;
    }

    // normalize
    path1 = path1.map((e) => Vector2((e.x - box.left) / box.width, 1.0 - (e.y - box.bottom) / box.height)).toList();
    path2 = path2.map((e) => Vector2((e.x - box.left) / box.width, 1.0 - (e.y - box.bottom) / box.height)).toList();

    int p1 = path1.length;
    int p2 = path2.length;
    print("path1 length : $p1, path2 length : $p2");
    /**
     *  both paths has start point and box corner Offset. then we have incomplete path.
     *  To complete this, we have to go back to the start point.
     *  That is the reason why we are adding start point again to the list.
     */
    path1.add(path1[0]);
    path2.add(path2[0]);

    return path1.length > 2 && path2.length > 2 ? [path1, path2] : [];
  }
}