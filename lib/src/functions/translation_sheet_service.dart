import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TranslationSheetService {
  final String sheetId;
  final String apiKey;

  TranslationSheetService()
      : sheetId = dotenv.env['GOOGLESHEETID'] ?? '',
        apiKey = dotenv.env['GOOGLESHEETAPIKEY'] ?? '' {
    if (sheetId.isEmpty || apiKey.isEmpty) {
      throw Exception('Missing Google Sheet credentials');
    }
  }

  String get sheetName => 'Translations';
  String get encodedSheetName => Uri.encodeComponent(sheetName);
  // key | ko | en | ja | zh-Hans | zh-Hant | fr | es
  String get range => 'A2:H';

  static const _columnLocales = ['ko', 'en', 'ja', 'zh-Hans', 'zh-Hant', 'fr', 'es'];

  Future<Map<String, Map<String, String>>> fetchTranslations() async {
    final uri = Uri.parse(
      'https://sheets.googleapis.com/v4/spreadsheets/'
      '$sheetId/values/$encodedSheetName!$range?key=$apiKey',
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Translation sheet fetch failed');
    }

    final data = jsonDecode(res.body);
    final values = (data['values'] as List).cast<List<dynamic>>();

    final Map<String, Map<String, String>> result = {};

    for (final row in values) {
      if (row.isEmpty) continue;

      final key = row[0]?.toString().trim();
      if (key == null || key.isEmpty) continue;

      final entry = <String, String>{};
      for (var i = 0; i < _columnLocales.length; i++) {
        final cellIndex = i + 1; // column B is index 1, right after the key
        final value = row.length > cellIndex ? row[cellIndex]?.toString().trim() ?? '' : '';
        if (value.isNotEmpty) {
          entry[_columnLocales[i]] = value;
        }
      }
      result[key] = entry;
    }

    return result;
  }
}
