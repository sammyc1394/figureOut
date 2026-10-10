import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:figureout/src/config/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NoHeartsOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onWatchAd;

  const NoHeartsOverlay({
    super.key,
    required this.onClose,
    required this.onWatchAd,
  });

  @override
  State<NoHeartsOverlay> createState() => _NoHeartsOverlayState();
}

class _NoHeartsOverlayState extends State<NoHeartsOverlay> {
  int _secondsUntilFull = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    final hearts = (prefs.getInt('hearts') ?? maxHearts).clamp(0, maxHearts);
    final nextHeartTime = prefs.getInt('next_heart_time');

    int secondsUntilFull = 0;
    if (hearts < maxHearts && nextHeartTime != null) {
      final secondsUntilNext =
          ((nextHeartTime - now) / 1000).ceil().clamp(0, heartRefillIntervalSec);
      // 다음 하트 이후에도 채워야 할 하트 수만큼 추가 대기 시간을 더한다.
      final remainingHeartsAfterNext = maxHearts - hearts - 1;
      secondsUntilFull = secondsUntilNext + remainingHeartsAfterNext * heartRefillIntervalSec;
    }

    if (!mounted) return;
    setState(() => _secondsUntilFull = secondsUntilFull);
  }

  // 최대 대기 시간이 1시간을 넘길 수 있어(하트 5개 * 재충전 주기) mm:ss만 쓰면
  // "149:28"처럼 분 단위가 두 자리를 넘어가 읽기 어려워진다. 다른 게임들의
  // 타이머 표기를 참고해 1시간 이상이면 h:mm:ss, 미만이면 mm:ss로 표시한다.
  String _formatCountdown(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static const _dir = 'assets/menu/common/';
  static const _w = 311.0;
  static const _h = 301.065;
  static const _beige = Color(0xFFE4E0D3);
  static const _ink = Color(0xFF232323);

  @override
  Widget build(BuildContext context) {
    final timerText = i18n
        .t('hearts_full_recharge_timer')
        .replaceFirst('AA:BB', _formatCountdown(_secondsUntilFull));

    // Figma 프레임(375 x 812) 좌표 기준. 박스 원점 = (32, 245.47)
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onClose, // 팝업 바깥을 누르면 닫힘
        child: SizedBox.expand(
          child: ColoredBox(
            color: _ink.withValues(alpha: 0.8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = constraints.maxWidth / 375;
                return Stack(
                  children: [
                    Center(
                      child: SizedBox(
                        width: _w * scale,
                        child: FittedBox(
                          fit: BoxFit.fitWidth,
                          // 팝업 안쪽 터치는 닫히지 않게 막는다.
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {},
                            child: SizedBox(
                              width: _w,
                              height: _h,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    left: -2.36,
                                    top: -2.32,
                                    child: SvgPicture.asset(
                                        '${_dir}NoHearts_card.svg'),
                                  ),
                                  Positioned(
                                    left: 118.18,
                                    top: 32.29,
                                    child: SvgPicture.asset(
                                        '${_dir}NoHearts_heart.svg'),
                                  ),
                                  Positioned(
                                    left: 23.5,
                                    top: 108.11,
                                    width: 265,
                                    height: 48,
                                    // 문구가 길어도 한 줄에 맞도록 글자 크기를 줄인다.
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        i18n.t('hearts_depleted_title'),
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: appFontFamily,
                                          fontSize: 35,
                                          color: _ink,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 3.5,
                                    top: 152.4,
                                    width: 305,
                                    height: 48,
                                    child: Center(
                                      child: Text(
                                        '${i18n.t('hearts_recharge_question')}\n($timerText)',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: appFontFamily,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: _ink,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 72.96,
                                    top: 220.53,
                                    width: 164.5,
                                    height: 47.1,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: widget.onWatchAd,
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
                                                    left: -0.89,
                                                    top: -1.18,
                                                    child: SvgPicture.asset(
                                                        '${_dir}NoHearts_watch_pill.svg'),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Text(
                                            i18n.t('ad_button_confirm'),
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
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Tap to close
                    Positioned(
                      left: 0,
                      right: 0,
                      top: (728.03 - 17.5) * scale,
                      height: 35 * scale,
                      child: IgnorePointer(
                        child: Center(
                          child: Text(
                            'Tap to close',
                            style: TextStyle(
                              fontFamily: appFontFamily,
                              fontSize: 30 * scale,
                              letterSpacing: -0.32 * scale,
                              color: _beige,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
