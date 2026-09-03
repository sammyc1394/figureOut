import 'package:flutter/widgets.dart';

// 앱 전역 다크모드 상태. main()에서 저장된 값으로 초기화되고,
// Settings > Theme 에서 값이 바뀌면 ThemeModeScope를 구독 중인 모든 화면이
// (네비게이션 스택을 건드리지 않고) 자동으로 다시 그려진다.
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
