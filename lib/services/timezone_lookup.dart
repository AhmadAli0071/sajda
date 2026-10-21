import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone_finder/timezone_finder.dart';

bool _tzReady = false;

/// Initializes the `timezone` database once. `findLocation` needs it (and
/// needs `latest_all`, not `latest`, or link ids throw).
void ensureTimezoneDatabase() {
  if (!_tzReady) {
    tz_data.initializeTimeZones();
    _tzReady = true;
  }
}

/// IANA timezone for [latitude]/[longitude], or null when the point is not
/// covered by land boundaries (open ocean, polar areas) or the database is
/// unavailable.
///
/// Argument order is the trap here: `timezone_finder` 0.2.0 takes
/// `findLocation(longitude, latitude)` (GeoJSON order). Passing `(lat, lng)`
/// silently resolves the mirrored point — e.g. Rahim Yar Khan
/// (28.3902, 70.3216) became Europe/Oslo, shifting every prayer time by 3
/// hours. All coordinate → timezone lookups in the app must go through this
/// helper.
String? ianaTimezoneForCoordinates(double latitude, double longitude) {
  try {
    ensureTimezoneDatabase();
    final location = findLocation(longitude, latitude);
    final name = location?.name;
    if (name == null || name.isEmpty || name == 'UTC') return null;
    return name;
  } catch (_) {
    return null;
  }
}
