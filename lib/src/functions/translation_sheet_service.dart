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
  String get range => 'A2:D'; // key | ko | en | ja

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

      result[key] = {
        'ko': row.length > 1 ? row[1]?.toString().trim() ?? '' : '',
        'en': row.length > 2 ? row[2]?.toString().trim() ?? '' : '',
        'ja': row.length > 3 ? row[3]?.toString().trim() ?? '' : '',
      };
    }

    return result;
  }
}
