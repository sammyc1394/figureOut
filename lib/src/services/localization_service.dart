class LocalizationService {
  final String locale;
  final Map<String, Map<String, String>> _data;

  LocalizationService(this.locale, this._data);

  String t(String key) {
    return _data[key]?[locale]
        ?? _data[key]?['en']
        ?? key; // fallback
  }
}
