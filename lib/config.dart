import 'l10n/translations.dart';

class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.sajda.online/api',
  );

  static const String appName = 'Sajda: Daily Athan & Qibla';
  static const String appTagline = 'Daily Athan & Qibla Companion';
}

class LanguageOption {
  final String code;
  final String name;
  final String nativeName;
  const LanguageOption(this.code, this.name, this.nativeName);
}

class AppStrings {
  static const Map<String, String> prayerNames = {
    'Fajr': 'فجر',
    'Sunrise': 'طلوع آفتاب',
    'Dhuhr': 'ظہر',
    'Asr': 'عصر',
    'Maghrib': 'مغرب',
    'Isha': 'عشاء',
  };

  /// Returns the localized display name for [prayerName]. On Fridays,
  /// Dhuhr is shown as "Friday" / "جمعہ" everywhere.
  static String prayerDisplayName(String prayerName,
      {bool isUrdu = false, DateTime? date}) {
    final d = date ?? DateTime.now();
    if (prayerName == 'Dhuhr' && d.weekday == DateTime.friday) {
      return isUrdu ? 'جمعہ' : 'Friday';
    }
    return isUrdu ? (prayerNames[prayerName] ?? prayerName) : prayerName;
  }

  static const List<LanguageOption> supportedLanguages = [
    LanguageOption('en', 'English', 'English'),
    LanguageOption('ur', 'Urdu', 'اردو'),
    LanguageOption('ar', 'Arabic', 'العربية'),
    LanguageOption('bn', 'Bengali', 'বাংলা'),
    LanguageOption('id', 'Indonesian', 'Bahasa Indonesia'),
    LanguageOption('tr', 'Turkish', 'Türkçe'),
    LanguageOption('fa', 'Persian', 'فارسی'),
    LanguageOption('hi', 'Hindi', 'हिन्दी'),
    LanguageOption('ms', 'Malay', 'Bahasa Melayu'),
    LanguageOption('fr', 'French', 'Français'),
  ];

  /// English-string -> { langCode: translation }. Full catalog lives in
  /// lib/l10n/translations.dart for the 8 non-English/Urdu languages.
  /// English and Urdu are provided inline at each AppState.t() call site.
  static const Map<String, Map<String, String>> translations = AppTranslations.data;
}
