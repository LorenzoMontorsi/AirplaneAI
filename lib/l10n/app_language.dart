enum AppLanguage {
  it,
  en,
  zh;

  /// Nome della lingua, sempre nella lingua stessa, così resta riconoscibile
  /// anche quando il resto dell'interfaccia è in un'altra lingua.
  String get nativeName => switch (this) {
        AppLanguage.it => 'Italiano',
        AppLanguage.en => 'English',
        AppLanguage.zh => '中文',
      };

  static AppLanguage fromCode(String? code) => switch (code) {
        'en' => AppLanguage.en,
        'zh' => AppLanguage.zh,
        _ => AppLanguage.it,
      };

  String get code => name;
}
