import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StageLockService {
  static const String _keyHighestClearedStage =
      'highest_cleared_stage';
  static const String _keyStageLockEnabled =
      'stage_lock_enabled';

  static const int _defaultHighestClearedStage = 0;
  static const bool _defaultStageLockEnabled = false;

  /// 현재 가장 마지막으로 클리어한 스테이지
  static Future<int> getHighestClearedStage() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getInt(_keyHighestClearedStage) ??
        _defaultHighestClearedStage;
  }

  /// 스테이지 클리어 기록
  ///
  /// 기존 기록보다 높은 스테이지를 클리어했을 때만 갱신한다.
  static Future<void> completeStage(int stage) async {
    final prefs = await SharedPreferences.getInstance();

    final currentHighest =
        prefs.getInt(_keyHighestClearedStage) ??
            _defaultHighestClearedStage;

    debugPrint(
      '[StageLock] completeStage: stage=$stage, current=$currentHighest',
    );

    if (stage > currentHighest) {
      await prefs.setInt(_keyHighestClearedStage, stage);
    }

    debugPrint(
      '[StageLock] highestClearedStage updated: $stage',
    );
  }

  /// 해당 스테이지에 접근 가능한지 확인
  static Future<bool> isStageUnlocked(int stage) async {
    final lockEnabled = await isLockEnabled();

    // 개발용으로 락 기능을 꺼둔 경우 모든 스테이지 접근 가능
    if (!lockEnabled) {
      return true;
    }

    final highestClearedStage = await getHighestClearedStage();
    final unlocked = stage <= highestClearedStage + 1;

    debugPrint(
      '[StageLock] stage=$stage, highest=$highestClearedStage, unlocked=$unlocked',
    );

    return unlocked;
  }

  /// 현재 스테이지 락 기능 활성화 여부
  static Future<bool> isLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();

    final enabled = prefs.getBool(_keyStageLockEnabled) ??
        _defaultStageLockEnabled;

    debugPrint('[StageLock] isLockEnabled: $enabled');

    return enabled;
  }

  /// 개발용 스테이지 락 ON/OFF
  static Future<void> setLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_keyStageLockEnabled, enabled);

    debugPrint('[StageLock] setLockEnabled: $enabled');
  }

  /// 개발용 스테이지 진행도 초기화
  /// 락 ON/OFF 설정은 유지하고 클리어 기록만 초기화한다.
  static Future<void> resetProgress() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(
      _keyHighestClearedStage,
      _defaultHighestClearedStage,
    );

    debugPrint(
      '[StageLock] progress reset: $_defaultHighestClearedStage',
    );
  }
}