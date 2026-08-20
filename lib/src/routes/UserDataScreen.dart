import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class UserDataScreen extends StatelessWidget {
  const UserDataScreen({super.key});

  Future<(String, int, String)> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final startDateRaw = prefs.getString(userDataStartDatePrefsKey);
    final startDate = startDateRaw != null
        ? DateTime.parse(startDateRaw)
        : DateTime.now();
    final formattedDate =
        '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final useCount = prefs.getInt(userDataUseCountPrefsKey) ?? 1;
    final playTimeSeconds = prefs.getInt(userDataPlayTimeSecondsPrefsKey) ?? 0;
    return (formattedDate, useCount, _formatPlayTime(playTimeSeconds));
  }

  String _formatPlayTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m';
    return '${totalSeconds}s';
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
                    i18n.t('settings_user_data'),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FutureBuilder<(String, int, String)>(
                future: _loadUserData(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(height: 8);
                  }
                  final (startDate, useCount, playTime) = snapshot.data!;
                  return Column(
                    children: [
                      const SizedBox(height: 8),
                      _UserDataRow(
                        label: i18n.t('settings_user_data_start_date'),
                        value: startDate,
                      ),
                      const Divider(color: Colors.black12, height: 1),
                      _UserDataRow(
                        label: i18n.t('settings_user_data_use_count'),
                        value: '$useCount',
                      ),
                      const Divider(color: Colors.black12, height: 1),
                      _UserDataRow(
                        label: i18n.t('settings_user_data_play_time'),
                        value: playTime,
                      ),
                    ],
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

class _UserDataRow extends StatelessWidget {
  final String label;
  final String value;

  const _UserDataRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          Text(
            value,
            style: TextStyle(
              fontFamily: appFontFamily,
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
