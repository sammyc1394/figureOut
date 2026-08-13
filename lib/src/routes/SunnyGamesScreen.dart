import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';

class _SunnyApp {
  final String name;
  final String desc;
  final String iosLink;
  final String androidLink;

  const _SunnyApp({
    required this.name,
    required this.desc,
    required this.iosLink,
    required this.androidLink,
  });
}

// Sunny Innovation Lab 앱 목록 (General Settings 기획서 slide 11-14)
const List<_SunnyApp> _sunnyApps = [
  _SunnyApp(
    name: 'Dual Flashlight',
    desc: 'Two Lights, One Versatile App!',
    iosLink: 'https://apps.apple.com/us/app/dual-flashlight/id6741048362',
    androidLink:
        'https://play.google.com/store/apps/details?id=com.sunnyinnolab.dualflash',
  ),
  _SunnyApp(
    name: 'World Movie Trailer',
    desc: 'All the World\'s Movie Trailers and Box Office Information in One Hand!',
    iosLink: 'https://apps.apple.com/ca/app/world-movie-trailer/id6670228768',
    androidLink:
        'https://play.google.com/store/apps/details?id=com.sunnyinnolab.worldMovieTrailer',
  ),
  _SunnyApp(
    name: 'Sky Peacemaker - Finger Force',
    desc:
        'Command the skies in Sky Peacemaker! Strategic, creative, and fast-paced fighter battles with innovative one-finger controls.',
    iosLink:
        'https://apps.apple.com/ca/app/sky-peacemaker-finger-force/id6744907473',
    androidLink: 'https://play.google.com/store/apps/details?id=com.mwm.ffigher.gg',
  ),
  _SunnyApp(
    name: 'Find Four',
    desc:
        'Spot and identify subtle variations between two seemingly identical images side by side.',
    iosLink:
        'https://apps.apple.com/ca/app/find-four-find-4-differences/id6478101361',
    androidLink:
        'https://play.google.com/store/apps/details?id=com.mwm.findfour.gg',
  ),
];

class SunnyGamesScreen extends StatelessWidget {
  const SunnyGamesScreen({super.key});

  String _storeLinkFor(_SunnyApp app) {
    if (!kIsWeb && Platform.isIOS) return app.iosLink;
    return app.androidLink;
  }

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
                    i18n.t('settings_sunny_games'),
                    style: TextStyle(
                      fontFamily: appFontFamily,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: _sunnyApps.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Colors.black12, height: 1),
                itemBuilder: (context, index) {
                  final app = _sunnyApps[index];
                  return InkWell(
                    onTap: () => launchUrl(
                      Uri.parse(_storeLinkFor(app)),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE4E0D3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.apps_rounded,
                              color: Color(0xFFED613D),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app.name,
                                  style: TextStyle(
                                    fontFamily: appFontFamily,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  app.desc,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: Colors.black45),
                        ],
                      ),
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
