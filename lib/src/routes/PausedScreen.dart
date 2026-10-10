
import 'dart:math' as math;
import 'dart:ui';
import 'package:figureout/src/config/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PauseOverlayWidget extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  const PauseOverlayWidget({
    super.key,
    required this.onResume,
    required this.onRetry,
    required this.onMenu,
  });

  static const _dir = 'assets/menu/common/';
  static const _beige = Color(0xFFE4E0D3);
  static const _w = 311.0;
  static const _h = 113.947;

  Widget _icon(String name, double left, double top, double w, double h,
      double ox, double oy, VoidCallback onTap) {
    const pad = 8.0;
    return Positioned(
      left: left - pad,
      top: top - pad,
      width: w + pad * 2,
      height: h + pad * 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: pad + ox,
              top: pad + oy,
              child: SvgPicture.asset('$_dir$name.svg'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Figma 프레임 좌표 기준 (박스 원점 = 박스 왼쪽 위)
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
      child: Container(
        color: const Color(0xFFB6B3A8).withValues(alpha: 0.7),
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: constraints.maxWidth * (_w / 375),
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  child: SizedBox(
                    width: _w,
                    height: _h,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 베이지 박스 (거친 가장자리 유지)
                        Positioned.fill(
                          child: ColorFiltered(
                            colorFilter: const ColorFilter.mode(
                              _beige,
                              BlendMode.srcIn,
                            ),
                            child: Image.asset(
                              'assets/Pasued_box.png',
                              fit: BoxFit.fill,
                            ),
                          ),
                        ),

                        // Resume
                        Positioned(
                          left: 79.9,
                          top: 33.42,
                          width: 151.1,
                          height: 47.1,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onResume,
                            child: Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: Transform.rotate(
                                    angle: math.pi,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned(
                                          left: -1.01,
                                          top: -1.19,
                                          child: SvgPicture.asset(
                                              '${_dir}Result_next_pill.svg'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Text(
                                  i18n.t('resume'),
                                  style: TextStyle(
                                    fontFamily: appFontFamily,
                                    fontSize: 30,
                                    color: _beige,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // 나가기 / 다시하기
                        _icon('Result_exit', 24.38, 40.07, 31.947, 33.794,
                            -1.95, -3.48, onMenu),
                        _icon('Result_replay', 252.78, 40.07, 31.895, 33.794,
                            -2.87, -3.0, onRetry),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
