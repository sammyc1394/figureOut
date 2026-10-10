import 'dart:math' as math;
import 'dart:ui';

import 'package:figureout/src/config/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AftermathOverlayWidget extends StatelessWidget {
  final StageResult result;
  final int starCount;
  final int stgIndex;
  final int msnIndex;
  final VoidCallback onContinue;
  final VoidCallback onRetry;
  final VoidCallback onPlay;
  final VoidCallback onMenu;

  const AftermathOverlayWidget({
    super.key,
    required this.result,
    required this.starCount,
    required this.stgIndex,
    required this.msnIndex,
    required this.onContinue,
    required this.onRetry,
    required this.onPlay,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Container(
        color: Colors.black.withValues(alpha: 0.25),
        child: Center(
          child: LayoutBuilder(
              builder:(context, constraints) {
                final base = constraints.biggest.shortestSide;

                if (result == StageResult.success) {
                  return SizedBox(
                    width: base * _SuccessPanel.widthRatio,
                    child: FittedBox(
                      fit: BoxFit.fitWidth,
                      child: _SuccessPanel(
                        stageLabel: '${stgIndex + 1}-$msnIndex',
                        starCount: starCount,
                        onMenu: onMenu,
                        onPlay: onPlay,
                        onRetry: onRetry,
                      ),
                    ),
                  );
                }

                final panelWidth = base * 0.97;
                final panelHeight = panelWidth * (550 / 600);

                return SizedBox(
                  width: panelWidth,
                  height: panelHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          'assets/Results_box.png',
                          fit: BoxFit.fill,
                        ),
                      ),
                      _stageLabel(panelWidth, panelHeight),
                      _heart(panelWidth, panelHeight),
                      _failTexts(panelWidth, panelHeight),
                      _buttons(panelWidth, panelHeight),
                    ],
                  ),
                );
              }
          ),
        ),
      ),
    );
  }

  Widget _stageLabel(double w, double h) {
    return Positioned(
      top: h * 0.04,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          '${stgIndex + 1}-$msnIndex',
          style: TextStyle(
            fontFamily: appFontFamily,
            fontSize: h * 0.10,
            fontWeight: FontWeight.w800,
            color: Color(0xFFE4E0D3),
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _heart(double w, double h) {
    return Positioned(
      top: h * 0.3,
      left: 0,
      right: 0,
      child: Center(
        child: Image.asset('assets/Lose_brokenheart.png', height: w * 0.17),
      ),
    );
  }

  Widget _failTexts(double w, double h) {
    return Positioned(
      top: h * 0.5,
      left: w * 0.08,
      right: w * 0.08,
      child: Column(
        children: [
          Text(
            i18n.t('almost_there'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: appFontFamily,
              fontSize: h * 0.09,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF222222),
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            i18n.t('resume_description'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: appFontFamily,
              fontSize: h * 0.055,
              color: const Color(0xFF222222),
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buttons(double w, double h) {
    // Matches Flame version proportions:
    final btnSize = w * 0.10;
    final pillW = w * 0.47;
    final pillH = h * 0.15;

    return Positioned(
      top: h * 0.775,
      left: w * 0.10,
      right: w * 0.10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onMenu,
            child: Image.asset('assets/Home_button_blue.png', width: btnSize, height: btnSize),
          ),
          GestureDetector(
            onTap: result == StageResult.success ? onPlay : onContinue,
            child: result == StageResult.success
                ? SizedBox(
                    width: pillW,
                    height: pillH,
                    child: Image.asset('assets/next_button.png', width: pillH, height: pillH),
                  )
                : _continueButton(pillW, pillH),
          ),
          GestureDetector(
            onTap: onRetry,
            child: Image.asset('assets/Replay_button_blue.png', width: btnSize, height: btnSize),
          ),
        ],
      ),
    );
  }

  Widget _continueButton(double pillW, double pillH) {
    return Container(
      width: pillW,
      height: pillH,
      padding: EdgeInsets.symmetric(horizontal: pillW * 0.06),
      decoration: BoxDecoration(
        color: const Color(0xFF7BA6C5),
        borderRadius: BorderRadius.circular(pillH / 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: pillH * 0.16, vertical: pillH * 0.08),
            decoration: BoxDecoration(
              color: const Color(0xFF232323),
              borderRadius: BorderRadius.circular(pillH * 0.15),
            ),
            child: Text(
              'AD',
              style: TextStyle(
                fontFamily: appFontFamily,
                fontSize: pillH * 0.3,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          SizedBox(width: pillW * 0.05),
          Flexible(
            child: Text(
              i18n.t('continue'),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: appFontFamily,
                fontSize: pillH * 0.42,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE4E0D3),
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mission-complete popup laid out in Figma frame coordinates (351 x 341.4).
class _SuccessPanel extends StatelessWidget {
  final String stageLabel;
  final int starCount;
  final VoidCallback onMenu;
  final VoidCallback onPlay;
  final VoidCallback onRetry;

  const _SuccessPanel({
    required this.stageLabel,
    required this.starCount,
    required this.onMenu,
    required this.onPlay,
    required this.onRetry,
  });

  static const widthRatio = 351 / 375;
  static const _w = 351.0;
  static const _h = 341.4;
  static const _dir = 'assets/menu/common/';
  static const _ribbon = Color(0xFFE4E0D3);
  static const _emptyStar = Color(0xFFB5B1A8);

  Widget _svg(String name, {Color? tint}) => SvgPicture.asset(
        '$_dir$name.svg',
        colorFilter:
            tint == null ? null : ColorFilter.mode(tint, BlendMode.srcIn),
      );

  /// Box of [innerW]x[innerH] centered at ([cx], [cy]); [child] sits at ([ox], [oy]).
  Widget _placed({
    required double cx,
    required double cy,
    required double innerW,
    required double innerH,
    required Widget child,
    double ox = 0,
    double oy = 0,
    double deg = 0,
    bool flipX = false,
  }) {
    Widget content = Stack(
      clipBehavior: Clip.none,
      children: [Positioned(left: ox, top: oy, child: child)],
    );
    if (flipX) content = Transform.flip(flipX: true, child: content);
    if (deg != 0) content = Transform.rotate(angle: deg * math.pi / 180, child: content);
    return Positioned(
      left: cx - innerW / 2,
      top: cy - innerH / 2,
      width: innerW,
      height: innerH,
      child: content,
    );
  }

  Widget _tapIcon(String name, double l, double t, double w, double h,
      double ox, double oy, VoidCallback onTap) {
    const pad = 8.0;
    return Positioned(
      left: l - pad,
      top: t - pad,
      width: w + pad * 2,
      height: h + pad * 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(left: pad + ox, top: pad + oy, child: _svg(name)),
          ],
        ),
      ),
    );
  }

  Widget _star(int index, Widget Function(Color? tint) build) =>
      build(index < starCount ? null : _emptyStar);

  @override
  Widget build(BuildContext context) {
    // Figma 좌표 원점: 리본 왼쪽 위 (12, 235.32)
    return SizedBox(
      width: _w,
      height: _h,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 카드
          Positioned(left: 17.64, top: 50.69, child: _svg('Result_card')),

          // Completed!
          Positioned(
            left: 23.5,
            top: 189.18,
            width: 305,
            height: 48,
            child: Center(
              child: Text(
                i18n.t('level_completed'),
                style: TextStyle(
                  fontFamily: appFontFamily,
                  fontSize: 35,
                  color: const Color(0xFF232323),
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),

          // Next
          Positioned(
            left: 99.68,
            top: 260.91,
            width: 151.1,
            height: 47.1,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onPlay,
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
                            child: _svg('Result_next_pill'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    'Next',
                    style: TextStyle(
                      fontFamily: appFontFamily,
                      fontSize: 30,
                      color: _ribbon,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 나가기 / 다시하기
          _tapIcon('Result_exit', 44.16, 266.5, 31.947, 33.794, -1.95, -3.48, onMenu),
          _tapIcon('Result_replay', 272.56, 266.5, 31.895, 33.794, -2.87, -3.0, onRetry),

          // 별 (왼쪽 → 가운데 → 오른쪽)
          _placed(
            cx: 102.51, cy: 147.25, innerW: 54.188, innerH: 54.928,
            ox: -2.27, oy: -1.593, deg: -8.8,
            child: _star(0, (t) => _svg('Result_star_left', tint: t)),
          ),
          Positioned(
            left: 131.19,
            top: 92.06,
            child: _star(1, (t) => _svg('Result_star_center', tint: t)),
          ),
          _placed(
            cx: 250.35, cy: 144.77, innerW: 53.564, innerH: 59.89,
            ox: -2.314, oy: -1.144, deg: 29.93,
            child: _star(2, (t) => _svg('Result_star_right', tint: t)),
          ),

          // 리본: 꼬리(살짝 기울어짐) → 접힘 → 중앙
          _placed(
            cx: 306.0, cy: 47.97, innerW: 85.388, innerH: 54.994,
            oy: -1.65, deg: 5.18, flipX: true,
            child: _svg('Result_ribbon_tail_right'),
          ),
          _placed(
            cx: 45.0, cy: 47.97, innerW: 85.388, innerH: 54.994,
            oy: -1.65, deg: -5.18,
            child: _svg('Result_ribbon_tail_left'),
          ),
          _placed(
            cx: 273.18, cy: 55.0, innerW: 27.145, innerH: 16.497,
            ox: -1.012, oy: -1.5, flipX: true,
            child: _svg('Result_ribbon_fold_right'),
          ),
          Positioned(
            left: 63.23,
            top: 53.5,
            child: _svg('Result_ribbon_fold_left'),
          ),
          Positioned(
            left: 63.86,
            top: 0,
            width: 225.27,
            height: 55,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 기존 리본 PNG의 중앙 띠(거친 가장자리)를 그대로 사용
                Positioned.fill(
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minWidth: 0,
                      minHeight: 0,
                      maxWidth: double.infinity,
                      maxHeight: double.infinity,
                      child: Transform.translate(
                        offset: Offset(-186 * (225.27 / 992), 0),
                        child: SizedBox(
                          width: 1357 * (225.27 / 992),
                          height: 1315 * (55 / 242),
                          child: Image.asset(
                            'assets/Results_box.png',
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    stageLabel,
                    style: TextStyle(
                      fontFamily: appFontFamily,
                      fontSize: 35,
                      color: _ribbon,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
