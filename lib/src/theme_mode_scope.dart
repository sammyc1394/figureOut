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

// 언어를 바꾸면 값을 증가시킨다. isDarkModeNotifier와 합쳐서 ThemeModeScope의
// notifier로 꽂아두면(appUiRevisionListenable), ThemeModeScope.of(context)를
// 부르는 모든 화면이 다크모드뿐 아니라 언어가 바뀔 때도 그 자리에서 다시 그려진다.
final ValueNotifier<int> localeRevisionNotifier = ValueNotifier<int>(0);

// InheritedNotifier는 이 Listenable을 직접 구독해서, 화면들의 build()가 언제 다시
// 불리는지와 무관하게(네비게이션/라우터 캐싱 여부와 무관하게) 곧바로 알림을 보낸다.
// 그래서 ThemeModeScope.of(context)를 호출한 화면은 다크모드든 언어든 값이 바뀌는
// 즉시 다시 그려진다.
final Listenable appUiRevisionListenable =
    Listenable.merge([isDarkModeNotifier, localeRevisionNotifier]);

class ThemeModeScope extends InheritedNotifier<Listenable> {
  const ThemeModeScope({
    super.key,
    required Listenable notifier,
    required super.child,
  }) : super(notifier: notifier);

  static bool of(BuildContext context) {
    context.dependOnInheritedWidgetOfExactType<ThemeModeScope>();
    return isDarkModeNotifier.value;
  }
}
