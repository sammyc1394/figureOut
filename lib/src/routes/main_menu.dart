import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:figureout/src/services/sheet_service.dart';
import 'package:figureout/main.dart';
import 'package:go_router/go_router.dart';

import 'package:figureout/src/config/config.dart';
import 'package:figureout/src/config/theme_mode_scope.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  bool _isLoading = false;

  final SheetService sheetService = SheetService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final allSheetNames = await sheetService.fetchSheetNames().timeout(const Duration(seconds: 8));
      final stageNames = allSheetNames
          .where((n) => n.toLowerCase().contains('stage'))
          .toList();
      cachedStageSheetNames = stageNames.isNotEmpty ? stageNames : allSheetNames;
      cachedStages = await sheetService
          .fetchData(preloadedSheetNames: allSheetNames)
          .timeout(const Duration(seconds: 8));

      debugPrint("${cachedStages.length}개의 StageData 불러옴!");
      messenger.showSnackBar(
        const SnackBar(content: Text("데이터가 새로고침되었습니다.")),
      );
    } catch (e) {
      debugPrint("데이터 불러오기 실패: $e");
      messenger.showSnackBar(
        const SnackBar(content: Text("데이터 불러오기에 실패했습니다.")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static const _assetDir = 'assets/menu/common/';
  static const _frameW = 375.0;
  static const _frameH = 812.0;

  // Figma 프레임(375x812) 좌표 기준으로 도형을 배치한다.
  // (cx, cy, innerW, innerH)로 회전 박스를 만들고, child 는 박스 안 (ox, oy)에 놓인다.
  Widget _figShape({
    required int index,
    required double left,
    required double top,
    required double w,
    required double h,
    required double innerW,
    required double innerH,
    required double deg,
    required Widget child,
  }) {
    return Positioned(
      left: left + (w - innerW) / 2,
      top: top + (h - innerH) / 2,
      width: innerW,
      height: innerH,
      child: _wobble(index, Transform.rotate(angle: deg * pi / 180, child: child)),
    );
  }

  Widget _wobble(int index, Widget child) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final dx = sin(_controller.value * 2 * pi + index) * 6;
        final dy = cos(_controller.value * 2 * pi + index) * 6;
        return Transform.translate(offset: Offset(dx, dy), child: child);
      },
      child: child,
    );
  }

  Widget _svgAt(String name, double ox, double oy) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: ox,
          top: oy,
          child: SvgPicture.asset('$_assetDir$name.svg'),
        ),
      ],
    );
  }

  Widget _rect(Color color) {
    return SvgPicture.asset(
      'assets/Rectangle_basic.svg',
      fit: BoxFit.fill,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ThemeModeScope.of(context);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF232323);

    return Scaffold(
      backgroundColor: Color(isDarkMode ? darkBgColor : bgColor),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque, // 빈 영역 터치도 인식
        onTap: _isLoading ? null : () {
          context.push('/stages', extra: cachedStages);
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.50,
                child: Image.asset(grainTexture, fit: BoxFit.cover),
              ),
            ),
            Positioned.fill(
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _frameW,
                    height: _frameH,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 타이틀
                        Positioned(
                          left: 188.5 - 150,
                          top: 360.71 - 81.17,
                          width: 300,
                          height: 162.34,
                          child: Center(
                            child: Text(
                              'Figure\nOut',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: appFontFamily,
                                fontSize: 90.19,
                                fontWeight: FontWeight.w400,
                                letterSpacing: -0.9019,
                                height: 0.9,
                                color: textColor,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),

                        // 진한 파랑 사각형 (왼쪽 아래)
                        _figShape(
                          index: 3, left: -24.92, top: 590.56, w: 126.588, h: 130.077,
                          innerW: 55.2, innerH: 126.399, deg: -43.01,
                          child: _rect(const Color(0xFF345983)),
                        ),
                        // 노랑 삼각형
                        _figShape(
                          index: 1, left: 257, top: 128.64, w: 158.364, h: 158.364,
                          innerW: 134.4, innerH: 134.4, deg: 11.43,
                          child: _svgAt('Start_triangle', 10.73, 3.06),
                        ),
                        // 초록 육각형
                        _figShape(
                          index: 2, left: 187.24, top: 458.7, w: 141.352, h: 146.869,
                          innerW: 103.274, innerH: 114.386, deg: -24.45,
                          child: _svgAt('Start_hexagon', -2.43, -0.55),
                        ),

                        // Tap to enter
                        Positioned(
                          left: 188.22 - 100,
                          top: 728.03 - 17.5,
                          width: 200,
                          height: 35,
                          child: Center(
                            child: Text(
                              i18n.t('main_menu_tap_to_enter'),
                              style: TextStyle(
                                fontFamily: appFontFamily,
                                fontWeight: FontWeight.w400,
                                fontSize: 30,
                                letterSpacing: -0.32,
                                color: textColor,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),

                        // 연한 파랑 사각형 (왼쪽 위)
                        _figShape(
                          index: 4, left: -82.94, top: 210.85, w: 116.322, h: 116.321,
                          innerW: 97.127, innerH: 97.127, deg: -12.87,
                          child: _rect(const Color(0xFF7BA6C5)),
                        ),
                        // 빨강 원
                        _figShape(
                          index: 0, left: 68.28, top: 25.56, w: 105.444, h: 105.444,
                          innerW: 105.444, innerH: 105.444, deg: 0,
                          child: _svgAt('Start_circle', -2.32, -2.15),
                        ),
                        // 육각형 옆 선
                        _figShape(
                          index: 5, left: 57.2, top: 416.14, w: 185.889, h: 135.322,
                          innerW: 173.234, innerH: 115.234, deg: -6.94,
                          child: _svgAt('Start_lines', -1.25, 0),
                        ),
                        // 삼각형 옆 소용돌이
                        _figShape(
                          index: 6, left: 239.14, top: 201.23, w: 85.94, h: 70.804,
                          innerW: 85.94, innerH: 70.804, deg: 0,
                          child: _svgAt('Start_swirl', -1.35, -1.25),
                        ),
                        // 분홍 오각형 (오른쪽 아래)
                        _figShape(
                          index: 7, left: 304.84, top: 687.7, w: 135.467, h: 139.405,
                          innerW: 113.899, innerH: 108.14, deg: -73.91,
                          child: _svgAt('Start_pentagon', -0.57, 0),
                        ),

                        // 새로고침 (출시 전까지 유지)
                        Positioned(
                          left: 188 - 24,
                          top: 650,
                          width: 48,
                          height: 48,
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : IconButton(
                                  icon: const Icon(Icons.refresh),
                                  iconSize: 40,
                                  color: isDarkMode ? Colors.white70 : Colors.black87,
                                  onPressed: _refreshData,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
