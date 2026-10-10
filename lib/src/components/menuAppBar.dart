import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:figureout/src/config/config.dart';
import 'package:figureout/src/services/analytics_service.dart';
import '../services/audio_manager.dart';
import 'package:figureout/src/config/theme_mode_scope.dart';

class Menuappbar extends StatefulWidget implements PreferredSizeWidget {
  final Color? backgroundColor;

  /// Use the beige settings gear (for blue / dark backgrounds) instead of the
  /// blue one used on the beige background.
  final bool lightSettingsIcon;

  const Menuappbar({
    super.key,
    this.backgroundColor,
    this.lightSettingsIcon = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(75);

  @override
  State<Menuappbar> createState() => _MenuappbarState();
}

class _MenuappbarState extends State<Menuappbar> {
  int _hearts = maxHearts;
  int _secondsUntilNext = heartRefillIntervalSec;
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

    int hearts = (prefs.getInt('hearts') ?? maxHearts).clamp(0, maxHearts);
    int secondsUntilNext = 0;

    if (hearts < maxHearts) {
      int? nextTimeMs = prefs.getInt('next_heart_time');

      if (nextTimeMs == null) {
        // 타이머 시작
        nextTimeMs = now + heartRefillIntervalSec * 1000;
        await prefs.setInt('next_heart_time', nextTimeMs);
      } else if (now >= nextTimeMs) {
        // 쌓인 하트 한꺼번에 지급
        final elapsed = now - nextTimeMs;
        final toAdd = (elapsed ~/ (heartRefillIntervalSec * 1000)) + 1;
        final actualAdded = toAdd.clamp(0, maxHearts - hearts);
        hearts = hearts + actualAdded;
        await prefs.setInt('hearts', hearts);

        if (hearts < maxHearts) {
          nextTimeMs = nextTimeMs + actualAdded * heartRefillIntervalSec * 1000;
          await prefs.setInt('next_heart_time', nextTimeMs);
        } else {
          await prefs.remove('next_heart_time');
          nextTimeMs = null;
        }
      }

      if (hearts < maxHearts && nextTimeMs != null) {
        final remaining = ((nextTimeMs - now) / 1000).ceil();
        secondsUntilNext = remaining.clamp(0, heartRefillIntervalSec);
      }
    }

    if (!mounted) return;
    setState(() {
      _hearts = hearts;
      _secondsUntilNext = secondsUntilNext;
    });
  }

  String _formatCountdown(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? Colors.transparent;
    final isFull = _hearts >= maxHearts;

    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leadingWidth: 0,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 하트 아이콘 5개
            ...List.generate(maxHearts, (i) => Padding(
              padding: const EdgeInsets.only(right: 2.8),
              child: SvgPicture.asset(
                i < _hearts
                    ? 'assets/menu/common/Heart_full.svg'
                    : 'assets/menu/common/Heart_empty.svg',
                width: 28.8,
                height: 28.8,
                fit: BoxFit.contain,
              ),
            )),
            const SizedBox(width: 6),
            // FULL 또는 카운트다운 배지
            Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  isFull
                      ? 'assets/HeartBox_outline.png'
                      : 'assets/HeartBox_filled.png',
                  height: 20,
                  fit: BoxFit.fitHeight,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    isFull ? 'FULL' : _formatCountdown(_secondsUntilNext),
                    style: TextStyle(
                      fontFamily: appFontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isFull ? const Color(0xFFED613D) : Colors.white,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      centerTitle: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () async {
              await AudioManager.instance.toggleBGM();
              setState(() {});
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: ThemeModeScope.of(context)
                    ? const Color(0xFF3A362D)
                    : const Color(0xFFE4E0D3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                AudioManager.instance.isBgmEnabled
                    ? Icons.music_note_rounded
                    : Icons.music_off_rounded,
                color: AudioManager.instance.isBgmEnabled
                    ? const Color(0xFFED613D)
                    : Colors.grey,
                size: 22,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GestureDetector(
            onTap: () async {
              await AnalyticsService.instance.logEvent('Settings_Clicked');
              if (!context.mounted) return;
              context.push('/settings');
            },
            child: SvgPicture.asset(
              widget.lightSettingsIcon || ThemeModeScope.of(context)
                  ? 'assets/menu/common/Setting_gear_beige.svg'
                  : 'assets/menu/common/Setting_gear_blue.svg',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}
