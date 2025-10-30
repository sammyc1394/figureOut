import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:figureout/src/functions/sheet_service.dart';

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
    "assets/Circle (tap).svg",
    "assets/triangle.svg",
    "assets/hexagon.svg",
    "assets/Rectangle 3.svg",
    "assets/pentagon.svg",
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
      debugPrint("✅ 초기 데이터 불러오기 완료: ${_stages.length}개 스테이지");
    } catch (e) {
      debugPrint("❌ 초기 데이터 불러오기 실패: $e");
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
      const Alignment(-0.8, -0.5),
      const Alignment(0.7, -0.3),
      const Alignment(-0.6, 0.7),
      const Alignment(0.8, 0.5),
      const Alignment(0.0, -0.7),
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
    Navigator.pushNamed(context, '/stages', arguments: _stages);
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
      backgroundColor: const Color(0xFFFDFBF5),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque, // 빈 영역 터치도 인식
        onTap: () {
          Navigator.pushNamed(context, '/stages');
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 💠 주변 도형들
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
                      child: SvgPicture.asset(
                        shapes[index],
                        width: 90,
                        height: 90,
                      ),
                    ),
                  );
                },
              );
            }),

            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Figure',
                  style: TextStyle(
                    fontFamily: 'Moulpali',
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                    color: Colors.black,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height : 100),

                GestureDetector(
                  onTap: () {
                    _goToStages();
                  },
                  child: SvgPicture.asset(
                    "assets/menu/common/Play_default.svg",
                    width: 60,
                    height: 60,
                  ),
                ),
                const SizedBox(height: 20),

                _isLoading
                    ? const CircularProgressIndicator() // 로딩 중이면 인디케이터 표시
                    : IconButton(
                  icon: const Icon(Icons.refresh),
                  iconSize: 40,
                  color: Colors.black87,
                  onPressed: _refreshData,
                ),

              ],
            )

          ],
        ),
      ),
    );
  }
}
