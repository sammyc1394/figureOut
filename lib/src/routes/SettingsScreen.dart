import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:figureout/main.dart';
import '../config.dart';
import '../functions/localization_service.dart';
import '../theme_mode_scope.dart';
import 'HowToPlayOverlay.dart';

// Sunny Innovation Lab 공용 링크 (General Settings 기획서 slide 5)
const String _sunnyHomepageUrl = 'https://ssongyc.github.io/sunny-homepage/';
const String _termsUrl =
    'https://marmalade-neptune-dbe.notion.site/Terms-Conditions-c18656ce6c6045e590f652bf8291f28b?pvs=74';
const String _privacyUrl =
    'https://marmalade-neptune-dbe.notion.site/Privacy-Policy-ced8ead72ced4d8791ca4a71a289dd6b';
const String _instagramUrl = 'https://www.instagram.com/sunnyinnolab/';
const String _twitterUrl = 'https://x.com/Sunnyinnolab';

Future<void> _launchUrl(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ThemeModeScope.of(context);
    final textColor = isDarkMode ? Colors.white : Colors.black;
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
                  Text(
                    i18n.t('settings_title'),
                    style: TextStyle(
                      fontFamily: appFontFamily,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _SettingsRow(
                      label: i18n.t('settings_how_to_play'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            backgroundColor: Colors.black,
                            body: HowToPlayOverlay(
                              onContinue: (_) => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const _RowDivider(),
                    _SettingsRow(
                      label: i18n.t('settings_user_data'),
                      onTap: () => context.push('/settings/user-data'),
                    ),
                    const _RowDivider(),
                    _SettingsRow(
                      label: i18n.t('settings_language'),
                      trailingText: languageDisplayNames[i18n.locale],
                      onTap: () => _showLanguagePicker(context),
                    ),
                    const _RowDivider(),
                    _SettingsRow(
                      label: i18n.t('settings_theme'),
                      trailingText: ThemeModeScope.of(context)
                          ? i18n.t('settings_theme_dark')
                          : i18n.t('settings_theme_light'),
                      onTap: () => _showThemePicker(context),
                    ),
                    const _RowDivider(),
                    _SettingsRow(
                      label: i18n.t('settings_sunny_games'),
                      onTap: () => context.push('/settings/sunny-games'),
                    ),
                    const _RowDivider(),
                    _SettingsRow(
                      label: i18n.t('settings_instagram'),
                      onTap: () => _launchUrl(_instagramUrl),
                    ),
                    const _RowDivider(),
                    _SettingsRow(
                      label: i18n.t('settings_twitter'),
                      onTap: () => _launchUrl(_twitterUrl),
                    ),
                    const _RowDivider(),
                    _SettingsRow(
                      label: i18n.t('settings_open_source_info'),
                      onTap: () => context.push('/settings/open-source-info'),
                    ),
                    const _RowDivider(),
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          debugPrint('[Settings] PackageInfo failed: ${snapshot.error}');
                        }
                        final info = snapshot.data;
                        return _SettingsRow(
                          label: i18n.t('settings_app_version'),
                          trailingText: info != null ? 'V ${info.version}' : '',
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _SettingsFooter(),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(bgColor),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final code in supportedLanguages)
                ListTile(
                  title: Text(
                    languageDisplayNames[code] ?? code,
                    style: TextStyle(
                      fontFamily: appFontFamily,
                      fontSize: 18,
                      fontWeight: code == i18n.locale
                          ? FontWeight.w800
                          : FontWeight.w400,
                    ),
                  ),
                  trailing: code == i18n.locale
                      ? const Icon(Icons.check, color: Color(0xFFED613D))
                      : null,
                  onTap: () => _changeLanguage(sheetContext, code),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _changeLanguage(BuildContext sheetContext, String code) async {
    if (code == i18n.locale) {
      Navigator.of(sheetContext).pop();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(localeOverridePrefsKey, code);
    i18n = LocalizationService(code, cachedTranslations);
    if (!sheetContext.mounted) return;
    Navigator.of(sheetContext).pop();
    figureoutMain.restart(sheetContext);
  }

  void _showThemePicker(BuildContext context) {
    final currentlyDark = ThemeModeScope.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(currentlyDark ? darkBgColor : bgColor),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final textColor = currentlyDark ? Colors.white : Colors.black;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final dark in [false, true])
                ListTile(
                  title: Text(
                    dark
                        ? i18n.t('settings_theme_dark')
                        : i18n.t('settings_theme_light'),
                    style: TextStyle(
                      fontFamily: appFontFamily,
                      fontSize: 18,
                      color: textColor,
                      fontWeight: dark == currentlyDark
                          ? FontWeight.w800
                          : FontWeight.w400,
                    ),
                  ),
                  trailing: dark == currentlyDark
                      ? const Icon(Icons.check, color: Color(0xFFED613D))
                      : null,
                  onTap: () => _changeTheme(sheetContext, dark),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // 언어 변경과 달리 테마 변경은 앱을 재시작하지 않는다: isDarkModeNotifier 값만
  // 갱신하면 ThemeModeScope를 구독 중인 화면들이 제자리에서 다시 그려지고,
  // 현재 화면/네비게이션 스택은 그대로 유지된다.
  Future<void> _changeTheme(BuildContext sheetContext, bool dark) async {
    Navigator.of(sheetContext).pop();
    if (dark == isDarkModeNotifier.value) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(themeModePrefsKey, dark);
    isDarkModeNotifier.value = dark;
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final String? trailingText;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.label,
    this.onTap,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ThemeModeScope.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: appFontFamily,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          if (trailingText != null) ...[
            Text(
              trailingText!,
              style: TextStyle(
                fontFamily: appFontFamily,
                fontSize: 16,
                color: isDarkMode ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              color: isDarkMode ? Colors.white38 : Colors.black45,
            ),
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: ThemeModeScope.of(context) ? Colors.white24 : Colors.black12,
      height: 1,
    );
  }
}

class _SettingsFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final linkStyle = TextStyle(
      fontFamily: appFontFamily,
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    );

    return Container(
      width: double.infinity,
      color: const Color(0xFF2B2B2B),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _launchUrl(_sunnyHomepageUrl),
            child: Image.asset(
              'assets/SIL_logo_setting_mini_white.png',
              height: 34,
              fit: BoxFit.contain,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => _launchUrl(_termsUrl),
            child: Text(i18n.t('settings_terms'), style: linkStyle),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('|', style: TextStyle(color: Colors.white38, fontSize: 17)),
          ),
          GestureDetector(
            onTap: () => _launchUrl(_privacyUrl),
            child: Text(i18n.t('settings_privacy'), style: linkStyle),
          ),
        ],
      ),
    );
  }
}
