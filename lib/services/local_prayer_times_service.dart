import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';
import 'hijri_date_service.dart';

/// On-device prayer time calculation (feature F3).
///
/// Uses the `adhan` package (MIT, batoulapps algorithm) so prayer times are
/// computed locally — no network round-trip, works 100% offline, and keeps
/// load off the AlAdhan API / api.sajda.online backend.
class LocalPrayerTimesService {
  LocalPrayerTimesService._();

  /// Settings' AlAdhan `method` ids -> adhan calculation methods.
  static const Map<int, CalculationMethod> _methodById = {
    1: CalculationMethod.karachi, // University of Islamic Sciences, Karachi
    2: CalculationMethod.north_america, // ISNA (North America)
    3: CalculationMethod.muslim_world_league,
    4: CalculationMethod.umm_al_qura, // Umm Al-Qura, Makkah
    5: CalculationMethod.egyptian, // Egyptian General Authority
    8: CalculationMethod.dubai, // Gulf region
    13: CalculationMethod.moon_sighting_committee,
    15: CalculationMethod.turkey, // Turkey (Diyanet)
  };

  static bool _tzReady = false;

  static void _ensureTz() {
    if (!_tzReady) {
      tz_data.initializeTimeZones();
      _tzReady = true;
    }
  }

  /// Calculates prayer times for [date] at [lat]/[lng], returned as "HH:mm"
  /// wall-clock strings in [timezone] (the selected location's timezone,
  /// never the device clock).
  ///
  /// [school]: 0 = Shafi (standard Asr), 1 = Hanafi — matches AlAdhan's
  /// `school` query parameter used elsewhere in the app.
  ///
  /// Returns null when coordinates are missing/unusable or calculation
  /// fails, so callers can fall back to the network paths.
  static PrayerTimesResponse? calculate({
    required double lat,
    required double lng,
    required String timezone,
    required DateTime date,
    required int method,
    required int school,
  }) {
    if (lat == 0.0 && lng == 0.0) return null;
    final calculationMethod = _methodById[method];
    if (calculationMethod == null) {
      // Never silently substitute MWL for an unmapped id — callers fall back
      // to the network routes, which honour the requested method id.
      debugPrint(
          'PrayerTimes: method id $method has no adhan mapping -> network fallback');
      return null;
    }
    try {
      final params = calculationMethod.getParameters();
      if (school == 1) params.madhab = Madhab.hanafi;

      // utcOffset makes adhan express the results as UTC+offset, so the
      // DateTime's hour/minute fields are the location's wall clock even
      // when the device timezone differs from the selected location.
      final prayerTimes = PrayerTimes(
        Coordinates(lat, lng),
        DateComponents(date.year, date.month, date.day),
        params,
        utcOffset: _utcOffsetFor(timezone, date),
      );

      String hm(DateTime t) =>
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

      final prayers = <PrayerTime>[
        PrayerTime('Fajr', hm(prayerTimes.fajr)),
        PrayerTime('Sunrise', hm(prayerTimes.sunrise)),
        PrayerTime('Dhuhr', hm(prayerTimes.dhuhr)),
        PrayerTime('Asr', hm(prayerTimes.asr)),
        PrayerTime('Maghrib', hm(prayerTimes.maghrib)),
        PrayerTime('Isha', hm(prayerTimes.isha)),
      ];

      // The civil day that was just calculated. Taken from [date]'s own
      // fields — re-deriving it through the timezone would re-interpret the
      // naive midnight as an instant and can land on the neighbouring day
      // whenever the device timezone differs from [timezone].
      final dateStr =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final hijri = HijriDateService.getHijriDate(
          DateTime(date.year, date.month, date.day));

      return PrayerTimesResponse(
        prayers: prayers,
        date: dateStr,
        hijri: HijriInfo(
          day: hijri.day.toString(),
          month: hijri.monthEn,
          monthAr: hijri.monthAr,
          year: hijri.year.toString(),
          full: hijri.full,
          fullAr: hijri.fullAr,
          monthNumber: hijri.month,
        ),
      );
    } catch (e) {
      // Null => the caller falls back to the network routes. Log only the
      // error class (never the inputs, which carry the user's location).
      debugPrint(
          'PrayerTimes: local calculation failed (${e.runtimeType}) -> network fallback');
      return null;
    }
  }

  /// UTC offset of [timezone] on [date] (evaluated at local noon so DST
  /// transitions that day cannot pick the wrong side).
  static Duration _utcOffsetFor(String timezone, DateTime date) {
    _ensureTz();
    try {
      final loc = tz.getLocation(timezone);
      return tz.TZDateTime(loc, date.year, date.month, date.day, 12)
          .timeZoneOffset;
    } catch (_) {
      return date.timeZoneOffset;
    }
  }
}
