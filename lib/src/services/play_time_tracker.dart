import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// 게임 화면(스테이지/엔드리스)에 머문 시간을 앱 라이프사이클에 맞춰 누적 기록한다.
/// Settings > User Data 화면의 Play Time에 표시된다.
class PlayTimeTracker {
  final Stopwatch _stopwatch = Stopwatch();

  void start() => _stopwatch.start();

  void pause() {
    if (_stopwatch.isRunning) _stopwatch.stop();
  }

  void resume() {
    if (!_stopwatch.isRunning) _stopwatch.start();
  }

  Future<void> stopAndPersist() async {
    _stopwatch.stop();
    final elapsedSeconds = _stopwatch.elapsed.inSeconds;
    if (elapsedSeconds <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    final total =
        (prefs.getInt(userDataPlayTimeSecondsPrefsKey) ?? 0) + elapsedSeconds;
    await prefs.setInt(userDataPlayTimeSecondsPrefsKey, total);
  }
}
