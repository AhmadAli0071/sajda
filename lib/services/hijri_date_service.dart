import 'package:hijri/hijri_calendar.dart';

/// Local Hijri date calculation using the Umm al-Qura algorithm, with a
/// user-adjustable day offset.
///
/// WHY AN OFFSET EXISTS:
/// The Umm al-Qura civil calendar is astronomical and frequently differs from
/// local moon sighting (ruet) by 1-2 days. Every consumer-facing Islamic date
/// (home header, Islamic calendar grid, prayer-time payloads) flows through
/// [convertPlain], so setting [adjustDays] shifts the whole app consistently.
/// Users match it against their local mosque calendar in Settings.
///
/// CONVENTION: one Hijri date per Gregorian day (same as printed calendars).
/// The Islamic day is NOT advanced at Maghrib — that made evening dates run
/// a day ahead of the printed calendar users compare against.
class HijriDateService {
  /// User adjustment in days (-2..+2). Displayed Hijri date equals the Umm
  /// al-Qura date of (gregorian + adjustDays). AppState persists this.
  static int adjustDays = 0;
  static const arabicMonths = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الثاني', 'جمادى الأولى', 'جمادى الآخرة',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];

  static const englishMonths = [
    'Muharram', 'Safar', 'Rabi al-Awwal', 'Rabi al-Thani',
    'Jumada al-Awwal', 'Jumada al-Thani', 'Rajab', 'Sha\'ban',
    'Ramadan', 'Shawwal', 'Dhu al-Qi\'dah', 'Dhu al-Hijjah',
  ];

  /// Gregorian -> Hijri conversion with the user adjustment applied.
  /// Every displayed Islamic date in the app goes through here.
  static HijriDateInfo convertPlain(DateTime gregorian) {
    HijriCalendar.language = 'en';
    final dateOnly =
        DateTime(gregorian.year, gregorian.month, gregorian.day)
            .add(Duration(days: adjustDays));
    final calendar = HijriCalendar.fromDate(dateOnly);
    final weekday = calendar.wkDay ?? calendar.weekDay();
    return HijriDateInfo(
      day: calendar.hDay,
      month: calendar.hMonth,
      year: calendar.hYear,
      monthEn: englishMonths[calendar.hMonth - 1],
      monthAr: arabicMonths[calendar.hMonth - 1],
      weekdayEn: _weekdayEn(weekday),
      weekdayAr: _weekdayAr(weekday),
    );
  }

  /// Hijri date for [gregorian] (adjustment applied). Kept as a named method
  /// so call sites read clearly.
  static HijriDateInfo getHijriDate(DateTime gregorian) =>
      convertPlain(gregorian);

  /// Hijri date for today.
  static HijriDateInfo getTodayHijri() => convertPlain(DateTime.now());

  static String _weekdayEn(int weekday) {
    // weekday: 1=Monday ... 7=Sunday (from HijriCalendar.weekDay())
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  static String _weekdayAr(int weekday) {
    const days = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    return days[weekday - 1];
  }
}

class HijriDateInfo {
  final int day;
  final int month;
  final int year;
  final String monthEn;
  final String monthAr;
  final String weekdayEn;
  final String weekdayAr;

  HijriDateInfo({
    required this.day,
    required this.month,
    required this.year,
    required this.monthEn,
    required this.monthAr,
    required this.weekdayEn,
    required this.weekdayAr,
  });

  String get full => '$day $monthEn $year AH';
  String get fullAr => '$day $monthAr $year هـ';
  String get fullWithWeekday => '$weekdayEn, $day $monthEn $year AH';
  String get fullWithWeekdayAr => '$weekdayAr، $day $monthAr $year هـ';

  Map<String, dynamic> toJson() => {
    'day': day,
    'month': month,
    'monthEn': monthEn,
    'monthAr': monthAr,
    'year': year,
    'weekdayEn': weekdayEn,
    'weekdayAr': weekdayAr,
    'full': full,
    'fullAr': fullAr,
  };
}
