import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:figureout/src/functions/sheet_service.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../effect/WigglyUnderlinePainter.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  bool _isLoading = false;
  bool _hasLoadedOnce = false;

  final SheetService sheetService = SheetService();

  List<StageData> _stages = [];

  final List<String> shapes = [
    "assets/Circle_basic.svg",
    "assets/Triangle_basic.svg",
    "assets/Hexagon_basic.svg",
    "assets/Rectangle_basic.svg",
    "assets/Pentagon_basic.svg",
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _loadDataOnStart();
  }

  Future<void> _loadDataOnStart() async {
    setState(() => _isLoading = true);
    try {
      final data = await SheetService().fetchData();
      setState(() {
        _stages = data;
        _hasLoadedOnce = true;
      });
      debugPrint("초기 데이터 불러오기 완료: ${_stages.length}개 스테이지");
    } catch (e) {
      debugPrint("초기 데이터 불러오기 실패: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 도형의 기본 위치값
  Alignment _baseAlignment(int index) {
    final alignments = [
      const Alignment(-0.75, -0.78), // circle
      const Alignment(0.78, -0.60),  // triangle
      const Alignment(0.25, 0.25),   // hexagon
      const Alignment(0.92, 0.72),   // rectangle
      const Alignment(-0.92, 0.50),  // pentagon
      // 잘린버전
      // const Alignment(-0.82, -0.72), // circle
      // const Alignment(0.92, -0.48),  // triangle
      // const Alignment(0.32, 0.38),   // hexagon
      // const Alignment(1.18, 0.78),   // rectangle (잘리게)
      // const Alignment(-1.15, 0.68),  // pentagon (잘리게)
    ];
    return alignments[index % alignments.length];
  }

  void _goToStages() {
    if (_stages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 데이터를 갱신해주세요')),
      );
      return;
    }
    context.push('/stages', extra: _stages);
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await sheetService.fetchData();
      setState(() {
        _stages = data;
      });

      debugPrint("${data.length}개의 StageData 불러옴!");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("데이터가 새로고침되었습니다.")),
      );
    } catch (e) {
      debugPrint("데이터 불러오기 실패: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("데이터 불러오기에 실패했습니다.")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(bgColor),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque, // 빈 영역 터치도 인식
        onTap: () {
          context.push('/stages', extra: _stages);
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 주변 도형들
            ...List.generate(shapes.length, (index) {
              final base = _baseAlignment(index);
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final dx = sin(_controller.value * 2 * pi + index) * 0.03;
                  final dy = cos(_controller.value * 2 * pi + index) * 0.03;
                  return Align(
                    alignment: Alignment(base.x + dx, base.y + dy),
                    child: Opacity(
                      opacity: 0.9,
                      child: Transform.rotate(
                        angle: switch (index) {
                          1 => 0.18, // triangle
                          2 => 0.12,  // hexagon
                          3 => 0.42, // rectangle
                          4 => -0.35,  // pentagon
                          _ => 0.0,   // circle
                        },
                        child: SvgPicture.asset(
                          shapes[index],
                          width: 90,
                          height: 90,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),

            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 100),
                Text(
                  'Figure',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: appFontFamily,
                    fontSize: 80,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                    height: 1.0,
                  ),
                ),

                Transform.translate(
                  offset: const Offset(0, -2), // 👉 핵심
                  child: Text(
                    'Out',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: appFontFamily,
                      fontSize: 80,
                      fontWeight: FontWeight.w400,
                      color: Colors.black,
                      height: 1.0,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // 밑줄
                Transform.translate(
                  offset: const Offset(15, 0),
                  child: Column(
                    children: [

                      Transform.rotate(
                        angle: -0.06,
                        child: CustomPaint(
                          size: const Size(220, 10),
                          painter: WigglyUnderlinePainter(seed: 1),
                        ),
                      ),

                      const SizedBox(height: 2),

                      Transform.translate(
                        offset: const Offset(5, 0),
                        child: Transform.rotate(
                          angle: -0.06,
                          child: CustomPaint(
                            size: const Size(220, 10),
                            painter: WigglyUnderlinePainter(seed: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 150),

                _isLoading
                    ? const CircularProgressIndicator() // 로딩 중이면 인디케이터 표시
                    : IconButton(
                  icon: const Icon(Icons.refresh),
                  iconSize: 40,
                  color: Colors.black87,
                  onPressed: _refreshData,
                ),

                const SizedBox(height: 20),

                // Refresh 버튼 유지

                Text(
                  'Tap to enter',
                  style: TextStyle(
                    fontFamily: appFontFamily,
                    fontWeight: FontWeight.w400,
                    fontSize: 32,
                    color: Colors.black,
                  ),
                ),

              ],
            )

          ],
        ),
      ),
    );
  }
}
