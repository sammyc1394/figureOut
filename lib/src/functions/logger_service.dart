import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum LogLevel {
  debug,
  info,
  warn,
  error,
}

class LoggerService {
  LoggerService._internal();
  static final LoggerService instance = LoggerService._internal();

  final String sessionId =
  DateTime.now().millisecondsSinceEpoch.toString();

  String _deviceName = 'unknown-device';

  String? _apiKey;
  String? _sheetId;

  bool _initialized = false;

  Future<void> init({
    required String apiKey,
    required String sheetId,
  }) async {
    _apiKey = apiKey;
    _sheetId = sheetId;

    _deviceName = await _getDeviceName();

    _initialized = true;

    appLog(
      'Logger',
      'Initialized logger (device=$_deviceName)',
      level: LogLevel.info,
    );
  }

  void appLog(
      String tag,
      String message, {
        LogLevel level = LogLevel.debug,
      }) {
    final now = DateTime.now().toIso8601String();

    final logText =
        '[$now][${level.name.toUpperCase()}][$tag] $message';

    debugPrint(logText);

    if (level == LogLevel.debug) return;
    if (!_initialized) return;

    _sendLogToSheet(
      tag: '${level.name.toUpperCase()}::$tag',
      message: message,
    );
  }

  Future<void> _sendLogToSheet({
    required String tag,
    required String message,
  }) async {
    try {
      final uri = Uri.parse(
        'https://sheets.googleapis.com/v4/spreadsheets/$_sheetId/values/log!A:E:append'
            '?valueInputOption=RAW&key=$_apiKey',
      );

      final body = {
        "values": [
          [
            DateTime.now().toIso8601String(),
            _deviceName,
            sessionId,
            tag,
            message,
          ]
        ]
      };

      final response = await http
          .post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint(
            '[Logger] Failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('[Logger] Exception: $e');
    }
  }

  Future<String> _getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return '${info.brand} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return '${info.name} ${info.utsname.machine}';
      }
    } catch (_) {}

    return 'unknown-device';
  }
}