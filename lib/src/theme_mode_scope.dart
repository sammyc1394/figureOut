import 'dart:ui' show Brightness, PlatformDispatcher;

import 'package:flutter/widgets.dart';

enum AppThemeMode {
  light,
  dark,
  system;

  String get storageValue => name;

  static AppThemeMode fromStorage(String? value) {
    switch (value) {
      case 'dark':
        return AppThemeMode.dark;
      case 'system':
        return AppThemeMode.system;
      default:
        return AppThemeMode.light;
    }
  }
}

bool resolveIsDarkMode(AppThemeMode mode) {
  if (mode == AppThemeMode.system) {
    return PlatformDispatcher.instance.platformBrightness == Brightness.dark;
  }
  return mode == AppThemeMode.dark;
}

// 사용자가 Settings > Theme 에서 고른 원래 선택(light/dark/system).
final ValueNotifier<AppThemeMode> themeModeNotifier =
    ValueNotifier<AppThemeMode>(AppThemeMode.light);

// 앱 전역 다크모드 상태(실제로 화면에 반영되는 값). system 선택 시 OS 밝기를 반영한
// 최종 값이 여기 들어간다. Settings > Theme 에서 값이 바뀌면 ThemeModeScope를 구독
// 중인 모든 화면이 (네비게이션 스택을 건드리지 않고) 자동으로 다시 그려진다.
final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(false);

class ThemeModeScope extends InheritedNotifier<ValueNotifier<bool>> {
  const ThemeModeScope({
    super.key,
    required ValueNotifier<bool> notifier,
    required super.child,
  }) : super(notifier: notifier);

  static bool of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeModeScope>();
    return scope?.notifier?.value ?? false;
  }
}
