import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// 하트 개수/재충전 타이머를 다루는 공용 헬퍼.
class HeartService {
  /// 광고 시청 보상 등으로 하트를 즉시 지급한다. (기본 1개)
  static Future<void> addHeart({int amount = 1}) async {
    final prefs = await SharedPreferences.getInstance();
    int hearts = (prefs.getInt('hearts') ?? maxHearts).clamp(0, maxHearts);
    hearts = (hearts + amount).clamp(0, maxHearts);
    await prefs.setInt('hearts', hearts);

    if (hearts >= maxHearts) {
      // 가득 찼으면 재충전 타이머를 멈춘다.
      await prefs.remove('next_heart_time');
    } else if (prefs.getInt('next_heart_time') == null) {
      // 타이머가 없는 상태였다면(예: 하트가 0개라 타이머 시작 전) 새로 시작한다.
      await prefs.setInt(
        'next_heart_time',
        DateTime.now().millisecondsSinceEpoch + heartRefillIntervalSec * 1000,
      );
    }
  }
}
