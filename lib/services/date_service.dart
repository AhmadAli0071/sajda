import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Centralized date/time utility.
///
/// All modules MUST use this service for local-date determination so that the
/// "today" used by streaks, prayer times, and UI is always computed in the
/// SELECTED LOCATION's timezone (not blindly the device timezone).
class DateService {
  static final DateService _instance = DateService._internal();
  factory DateService() => _instance;
  DateService._internal();

  static bool _tzInitialized = false;

  void _ensureTzInitialized() {
    if (!_tzInitialized) {
      tz_data.initializeTimeZones();
      _tzInitialized = true;
    }
  }

  /// Converts an instant into the wall-clock date (YYYY-MM-DD) of [timezone].
  ///
  /// This is the single source of truth for "which calendar day is it" and
  /// matches the backend's `getTodayDateString(timezone)` exactly, which is
  /// required for streak day-counting to agree between client and server.
  String formatDateAsYYYYMMDD({DateTime? date, String? timezone}) {
    final d = date ?? DateTime.now();
    if (timezone != null && timezone.isNotEmpty) {
      _ensureTzInitialized();
      try {
        final location = tz.getLocation(timezone);
        final zoned = tz.TZDateTime.from(d, location);
        return '${zoned.year.toString().padLeft(4, '0')}-'
            '${zoned.month.toString().padLeft(2, '0')}-'
            '${zoned.day.toString().padLeft(2, '0')}';
      } catch (_) {
        // Unknown timezone id -> fall through to device-local formatting.
      }
    }
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Today's date string in the location timezone.
  String getTodayDate({String? timezone}) =>
      formatDateAsYYYYMMDD(timezone: timezone);

  /// Yesterday's date string in the location timezone.
  String getYesterdayDate({String? timezone}) =>
      formatDateAsYYYYMMDD(date: DateTime.now().subtract(const Duration(days: 1)), timezone: timezone);

  /// Date string for an explicit date.
  String getDate({required DateTime date, String? timezone}) =>
      formatDateAsYYYYMMDD(date: date, timezone: timezone);

  /// Builds the wall-clock time [h]:[m] on [y]-[m]-[d] in [timezone] and
  /// returns the same instant expressed as a device-local DateTime.
  /// Returns null when the timezone id is unknown.
  DateTime? zonedDateTimeToInstant(
    String timezone,
    int y,
    int m,
    int d,
    int h,
    int min,
  ) {
    _ensureTzInitialized();
    try {
      final location = tz.getLocation(timezone);
      final zoned = tz.TZDateTime(location, y, m, d, h, min);
      return DateTime.fromMillisecondsSinceEpoch(zoned.millisecondsSinceEpoch);
    } catch (_) {
      return null;
    }
  }

  /// Parses "HH:mm" into (hour, minute), or null when malformed.
  (int, int)? parseHm(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0].trim());
    final m = int.tryParse(parts[1].trim());
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return (h, m);
  }

  /// Current wall-clock (hour, minute) in [timezone].
  ///
  /// Prayer times are returned in the SELECTED LOCATION's timezone; "now"
  /// must be measured in the SAME timezone or next-prayer math breaks
  /// whenever the device timezone differs from the selected location.
  (int, int) nowHmInTimezone(String timezone) {
    _ensureTzInitialized();
    try {
      final location = tz.getLocation(timezone);
      final zoned = tz.TZDateTime.now(location);
      return (zoned.hour, zoned.minute);
    } catch (_) {
      final now = DateTime.now();
      return (now.hour, now.minute);
    }
  }

  /// Current wall-clock as a naive DateTime in [timezone].
  ///
  /// [computePrayerWindow] compares prayer times (location wall-clock
  /// strings) against a "now" DateTime; feeding it DateTime.now() (device
  /// clock) highlights the wrong current/next prayer whenever the device
  /// timezone differs from the selected location (travel).
  DateTime nowInTimezone(String timezone) {
    _ensureTzInitialized();
    try {
      final location = tz.getLocation(timezone);
      final zoned = tz.TZDateTime.now(location);
      return DateTime(zoned.year, zoned.month, zoned.day, zoned.hour, zoned.minute);
    } catch (_) {
      return DateTime.now();
    }
  }

  /// Parses YYYY-MM-DD into a local DateTime at midnight.
  DateTime parseDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
    return DateTime.now();
  }

  /// True when [date] falls on today (location timezone aware).
  bool isToday(DateTime date, {String? timezone}) =>
      formatDateAsYYYYMMDD(date: date, timezone: timezone) ==
      getTodayDate(timezone: timezone);

  /// True when [date] falls on yesterday (location timezone aware).
  bool isYesterday(DateTime date, {String? timezone}) =>
      formatDateAsYYYYMMDD(date: date, timezone: timezone) ==
      getYesterdayDate(timezone: timezone);

  String formatDate(DateTime date, {String locale = 'en'}) {
    if (locale == 'ur') {
      return DateFormat('dd MMMM yyyy', 'ur').format(date);
    }
    return DateFormat('dd MMMM yyyy').format(date);
  }

  String formatTime(DateTime date, {String locale = 'en'}) {
    if (locale == 'ur') {
      return DateFormat('HH:mm', 'ur').format(date);
    }
    return DateFormat('HH:mm').format(date);
  }

  int getTimeDifferenceInMinutes(DateTime date1, DateTime date2) =>
      date1.difference(date2).inMinutes;

  bool isFuture(DateTime date) => date.isAfter(DateTime.now());

  bool isPast(DateTime date) => date.isBefore(DateTime.now());

  String formatTimeOnly(DateTime date) => DateFormat('HH:mm').format(date);

  String formatDateOnly(DateTime date) => DateFormat('MM/dd/yyyy').format(date);
}

/// Global instance for easy access.
final dateService = DateService();
