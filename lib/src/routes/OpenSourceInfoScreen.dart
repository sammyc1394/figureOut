import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../theme_mode_scope.dart';

class _OssPackage {
  final String name;
  final String version;

  const _OssPackage(this.name, this.version);
}

// pubspec.yaml의 direct dependencies 목록 (Settings > Open Source Info 기획서 slide 참고)
const List<_OssPackage> _ossPackages = [
  _OssPackage('flame', '1.30.1'),
  _OssPackage('flame_svg', '1.11.14'),
  _OssPackage('flutter_svg', '2.0.9'),
  _OssPackage('flutter_dotenv', '5.2.1'),
  _OssPackage('http', '1.6.0'),
  _OssPackage('google_fonts', '6.3.3'),
  _OssPackage('carousel_slider', '5.1.2'),
  _OssPackage('shared_preferences', '2.5.5'),
  _OssPackage('go_router', '14.8.1'),
  _OssPackage('device_info_plus', '12.4.0'),
  _OssPackage('firebase_core', '3.15.2'),
  _OssPackage('cloud_firestore', '5.6.12'),
  _OssPackage('audioplayers', '6.7.1'),
  _OssPackage('amplitude_flutter', '4.6.2'),
  _OssPackage('google_mobile_ads', '5.3.1'),
  _OssPackage('url_launcher', '6.3.2'),
  _OssPackage('package_info_plus', '8.3.1'),
  _OssPackage('cupertino_icons', '1.0.8'),
];

class OpenSourceInfoScreen extends StatelessWidget {
  const OpenSourceInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ThemeModeScope.of(context);
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
                    i18n.t('settings_open_source_info'),
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
                itemCount: _ossPackages.length,
                separatorBuilder: (_, __) => Divider(
                  color: isDarkMode ? Colors.white24 : Colors.black12,
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final package = _ossPackages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            package.name,
                            style: TextStyle(
                              fontFamily: appFontFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          package.version,
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
