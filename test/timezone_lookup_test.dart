import 'package:flutter_test/flutter_test.dart';
import 'package:sajda_dataplus/services/timezone_lookup.dart';

/// Regression guard for the 19 Oct 2026 bug where a swapped
/// `findLocation(lat, lng)` call resolved Rahim Yar Khan to Europe/Oslo
/// (UTC+2 DST) instead of Asia/Karachi (UTC+5), shifting every prayer time
/// 3 hours early on the device.
void main() {
  group('ianaTimezoneForCoordinates', () {
    test('Rahim Yar Khan resolves to Asia/Karachi, never Europe/Oslo', () {
      final zone = ianaTimezoneForCoordinates(28.3902, 70.3216);
      expect(zone, 'Asia/Karachi');
      expect(zone, isNot('Europe/Oslo'));
    });

    test('Lahore and Raiwind resolve to Asia/Karachi', () {
      expect(ianaTimezoneForCoordinates(31.5497, 74.3436), 'Asia/Karachi');
      expect(ianaTimezoneForCoordinates(31.25, 74.23), 'Asia/Karachi');
    });

    test('other regions resolve to their own zones', () {
      expect(ianaTimezoneForCoordinates(52.52, 13.405), 'Europe/Berlin');
      expect(ianaTimezoneForCoordinates(30.0444, 31.2357), 'Africa/Cairo');
    });

    test('points outside land boundaries return null instead of throwing', () {
      expect(ianaTimezoneForCoordinates(0.0, 0.0), isNull);
      expect(ianaTimezoneForCoordinates(10.0, -140.0), isNull);
      expect(ianaTimezoneForCoordinates(-30.0, -30.0), isNull);
    });

    test('resolved zone is stable across repeated lookups', () {
      for (var i = 0; i < 3; i++) {
        expect(ianaTimezoneForCoordinates(28.3902, 70.3216), 'Asia/Karachi');
      }
    });
  });
}
