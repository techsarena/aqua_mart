import 'dart:ui';

/// The three languages offered on the first screen.
///
/// Roman Urdu is Urdu written in Latin script, so it keeps LTR direction and
/// the Latin font — only `ur` flips the layout and switches to Nastaliq.
enum AppLanguage {
  english('en', 'English', 'Order water in English'),
  urdu('ur', 'اردو', 'اردو میں پانی منگوائیں'),
  romanUrdu('ur_Latn', 'Roman Urdu', 'Pani ka order Roman Urdu mein');

  const AppLanguage(this.code, this.label, this.subtitle);

  final String code;
  final String label;
  final String subtitle;

  bool get isRtl => this == AppLanguage.urdu;

  /// Nastaliq needs ~2x line-height and one size step up.
  bool get usesNastaliq => this == AppLanguage.urdu;

  Locale get locale => switch (this) {
    AppLanguage.english => const Locale('en'),
    AppLanguage.urdu => const Locale('ur'),
    AppLanguage.romanUrdu => const Locale.fromSubtags(
      languageCode: 'ur',
      scriptCode: 'Latn',
    ),
  };

  static AppLanguage fromCode(String code) => AppLanguage.values.firstWhere(
    (l) => l.code == code,
    orElse: () => AppLanguage.english,
  );
}
