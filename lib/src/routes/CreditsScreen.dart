import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../theme_mode_scope.dart';

class _CreditGroup {
  final String label;
  final List<String> names;
  final bool pluralizeLabel;

  const _CreditGroup(this.label, this.names, {this.pluralizeLabel = true});

  String get displayLabel {
    if (!pluralizeLabel || names.length < 2 || label.endsWith('s')) {
      return label;
    }
    return '${label}s';
  }
}

// Credits 항목은 설정 언어와 무관하게 항상 영어로 표기한다 (기획서 지시사항).
const List<_CreditGroup> _creditGroups = [
  _CreditGroup('Producer', ['R.S.']),
  _CreditGroup('Programmer', ['Minsik Kim (Paul)', 'Sam Chang', 'Hyewon Ham']),
  _CreditGroup('UIUX Designer', ['Shin Park', 'Sharon']),
  _CreditGroup('QA Tester', ['YC', 'SJ']),
  _CreditGroup('Localization Manager', ['Mary', 'Carol', 'Ann', 'Edward']),
  _CreditGroup('Special Thanks', ['Toronto Korean Developers'], pluralizeLabel: false),
];

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ThemeModeScope.of(context);
    final dividerColor = isDarkMode ? Colors.white24 : Colors.black12;
    return Scaffold(
      backgroundColor: Color(isDarkMode ? darkBgColor : bgColor),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Image.asset(
                      'assets/Back_button_beige.png',
                      width: 37,
                      height: 37,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.groups_rounded,
                    size: 30,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    i18n.t('settings_credits'),
                    style: TextStyle(
                      fontFamily: appFontFamily,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: _creditGroups.length,
                separatorBuilder: (_, __) => Divider(color: dividerColor, height: 1),
                itemBuilder: (context, index) {
                  final group = _creditGroups[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.displayLabel,
                          style: TextStyle(
                            fontFamily: appFontFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          group.names.join(', '),
                          style: TextStyle(
                            fontFamily: appFontFamily,
                            fontSize: 16,
                            color: isDarkMode ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
