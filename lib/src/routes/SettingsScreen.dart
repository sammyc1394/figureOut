import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:figureout/main.dart';
import '../config.dart';
import '../functions/localization_service.dart';
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
    return Scaffold(
      backgroundColor: const Color(bgColor),
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
                      color: Colors.black,
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
                color: Colors.black87,
              ),
            ),
          ),
          if (trailingText != null) ...[
            Text(
              trailingText!,
              style: TextStyle(
                fontFamily: appFontFamily,
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (onTap != null)
            const Icon(Icons.chevron_right_rounded, color: Colors.black45),
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
    return const Divider(color: Colors.black12, height: 1);
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
