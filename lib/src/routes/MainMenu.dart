import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:figureout/src/functions/sheet_service.dart';
import 'package:figureout/main.dart';
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

  final SheetService sheetService = SheetService();

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
    ];
    return alignments[index % alignments.length];
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final allSheetNames = await sheetService.fetchSheetNames().timeout(const Duration(seconds: 8));
      final stageNames = allSheetNames
          .where((n) => n.startsWith('Stage') || n.startsWith('Stages'))
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(bgColor),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque, // 빈 영역 터치도 인식
        onTap: _isLoading ? null : () {
          context.push('/stages', extra: cachedStages);
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.55,
                child: 
                // ColorFiltered(
                //   colorFilter: const ColorFilter.matrix([
                //     -1, 0, 0, 0, 255,
                //      0,-1, 0, 0, 255,
                //      0, 0,-1, 0, 255,
                //      0, 0, 0, 1,   0,
                //   ]),
                //   child: 
                  Image.asset('assets/noise_texture.png', fit: BoxFit.cover),
                ),
              ),
            // ),
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
                  offset: const Offset(0, -2),
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
                    ? const CircularProgressIndicator()
                    : IconButton(
                  icon: const Icon(Icons.refresh),
                  iconSize: 40,
                  color: Colors.black87,
                  onPressed: _refreshData,
                ),

                const SizedBox(height: 20),

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
