import 'dart:async';
import 'dart:ui';

import 'package:figureout/src/config/config.dart';
import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = screenWidth * 0.84;
    final timerText = i18n
        .t('hearts_full_recharge_timer')
        .replaceFirst('AA:BB', _formatCountdown(_secondsUntilFull));

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: SizedBox.expand(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.25),
          child: Center(
            child: Container(
              width: panelWidth,
              padding: EdgeInsets.symmetric(
                vertical: panelWidth * 0.09,
                horizontal: panelWidth * 0.09,
              ),
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/StageScreen_box.png'),
                  fit: BoxFit.fill,
                ),
              ),
              // 텍스트 길이(언어별)에 따라 카드 높이가 자연스럽게 늘어나도록
              // 절대 좌표 대신 Column으로 배치해 버튼과 절대 겹치지 않게 한다.
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/empty_heart.png', height: panelWidth * 0.20),
                      SizedBox(height: panelWidth * 0.06),
                      Text(
                        i18n.t('hearts_depleted_title'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: appFontFamily,
                          fontSize: panelWidth * 0.084,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF222222),
                          decoration: TextDecoration.none,
                        ),
                      ),
                      SizedBox(height: panelWidth * 0.04),
                      Text(
                        i18n.t('hearts_recharge_question'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: appFontFamily,
                          fontSize: panelWidth * 0.062,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF222222),
                          decoration: TextDecoration.none,
                        ),
                      ),
                      SizedBox(height: panelWidth * 0.01),
                      Text(
                        '($timerText)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: appFontFamily,
                          fontSize: panelWidth * 0.056,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF222222),
                          decoration: TextDecoration.none,
                        ),
                      ),
                      SizedBox(height: panelWidth * 0.08),
                      GestureDetector(
                        onTap: widget.onWatchAd,
                        child: Container(
                          width: panelWidth * 0.64,
                          height: panelWidth * 0.17,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/watch_ad_btn.png'),
                              fit: BoxFit.fill,
                            ),
                          ),
                          child: Text(
                            i18n.t('ad_button_confirm'),
                            style: TextStyle(
                              fontFamily: appFontFamily,
                              fontSize: panelWidth * 0.09,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFE4E0D3),
                              decoration: TextDecoration.none,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: -panelWidth * 0.03,
                    right: -panelWidth * 0.03,
                    child: GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        width: panelWidth * 0.1,
                        height: panelWidth * 0.1,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFBBBBBB), width: 1.5),
                        ),
                        child: Icon(
                          Icons.close,
                          size: panelWidth * 0.06,
                          color: const Color(0xFF888888),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
