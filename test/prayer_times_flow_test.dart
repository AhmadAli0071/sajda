import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sajda_dataplus/models/models.dart';
import 'package:sajda_dataplus/screens/prayer_screen.dart';
import 'package:sajda_dataplus/services/api_client.dart';
import 'package:sajda_dataplus/services/date_service.dart';
import 'package:sajda_dataplus/state/app_state.dart';

PrayerTimesResponse _resp({
  required String date,
  required String fajr,
  required String dhuhr,
}) =>
    PrayerTimesResponse(
      prayers: [
        PrayerTime('Fajr', fajr),
        PrayerTime('Sunrise', '06:30'),
        PrayerTime('Dhuhr', dhuhr),
        PrayerTime('Asr', '16:00'),
        PrayerTime('Maghrib', '18:00'),
        PrayerTime('Isha', '19:30'),
      ],
      date: date,
      hijri: HijriInfo(),
    );

void main() {
  group('date sent on the direct AlAdhan route', () {
    test('an YYYY-MM-DD stored date is sent to AlAdhan as DD-MM-YYYY', () {
      expect(ApiClient.aladhanDateFromYmd('2026-10-09'), '09-10-2026');
      expect(ApiClient.aladhanDateFromYmd('2026-01-05'), '05-01-2026');
    });

    test('a date that is already DD-MM-YYYY passes through unchanged', () {
      expect(ApiClient.aladhanDateFromYmd('09-10-2026'), '09-10-2026');
      expect(ApiClient.aladhanDateFromYmd('garbage'), 'garbage');
    });
  });

  group('backend fallback request', () {
    test('carries the same civil date as the direct request (YYYY-MM-DD)', () {
      final path = ApiClient.prayerTimesPath(
        city: 'Karachi',
        country: 'Pakistan',
        date: '2026-10-19',
        method: 2,
        school: 0,
      );
      expect(path, contains('date=2026-10-19'));
      // The backend converts this itself before calling AlAdhan.
      expect(ApiClient.aladhanDateFromYmd('2026-10-19'), '19-10-2026');
    });

    test('passes the user method/school through instead of server defaults', () {
      final path = ApiClient.prayerTimesPath(
        city: 'Lahore',
        country: 'Pakistan',
        date: '2026-12-31',
        method: 13,
        school: 1,
      );
      expect(path, contains('method=13'));
      expect(path, contains('school=1'));
      expect(path, isNot(contains('method=3')));
      expect(path, isNot(contains('school=0')));
    });

    test('city and country are URL-encoded', () {
      final path = ApiClient.prayerTimesPath(
        city: 'São Paulo',
        country: 'Brazil',
        date: '2026-10-19',
        method: 5,
        school: 0,
      );
      // Uri.encodeQueryComponent: UTF-8 percent-encoding, space as '+'.
      expect(path, contains('city=S%C3%A3o+Paulo'));
      expect(path, contains('country=Brazil'));
    });
  });

  group('prayer-times cache separation', () {
    String key({
      String date = '2026-10-19',
      int method = 2,
      int school = 0,
      String timezone = 'Asia/Karachi',
      double lat = 0.0,
      double lng = 0.0,
    }) =>
        ApiClient.prayerCacheKey(
          lat: lat,
          lng: lng,
          city: 'Karachi',
          country: 'Pakistan',
          timezone: timezone,
          date: date,
          method: method,
          school: school,
        );

    test('identical inputs share one key', () {
      expect(key(), key());
    });

    test('a new civil date never reuses the cached day', () {
      expect(key(date: '2026-10-19'), isNot(key(date: '2026-10-20')));
    });

    test('timezone, method, school and coordinates change the key', () {
      expect(key(), isNot(key(timezone: 'Europe/London')));
      expect(key(), isNot(key(method: 3)));
      expect(key(), isNot(key(school: 1)));
      expect(key(), isNot(key(lat: 24.86, lng: 67.0)));
    });
  });

  group('PrayerScreen refresh on resume', () {
    testWidgets('re-reads prayer times when the app returns to foreground',
        (tester) async {
      final api = ApiClient.instance;
      final state = AppState();
      addTearDown(api.invalidatePrayerTimesCache);

      String cacheKey() {
        const timezone = 'Asia/Karachi';
        return ApiClient.prayerCacheKey(
          lat: state.lat ?? 0.0,
          lng: state.lng ?? 0.0,
          city: state.prayerCityParam,
          country: state.prayerCountryParam,
          timezone: timezone,
          date: dateService.formatDateAsYYYYMMDD(timezone: timezone),
          method: state.prayerMethod,
          school: state.asrSchool,
        );
      }

      final today = dateService.formatDateAsYYYYMMDD(timezone: 'Asia/Karachi');
      api.primePrayerTimesCache(
        _resp(date: today, fajr: '05:10', dhuhr: '12:30'),
        cacheKey: cacheKey(),
      );

      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider<AppState>.value(
          value: state,
          child: const PrayerScreen(),
        ),
      ));
      await tester.pump();
      expect(find.text('5:10 AM'), findsWidgets);

      // A refetch (new day) lands in the cache with the same key …
      api.primePrayerTimesCache(
        _resp(date: today, fajr: '05:11', dhuhr: '12:31'),
        cacheKey: cacheKey(),
      );

      // … and the process comes back from the background.
      Future<void> setAppLifecycleState(AppLifecycleState s) async {
        final ByteData? message = const StringCodec().encodeMessage(s.toString());
        await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .handlePlatformMessage('flutter/lifecycle', message, (_) {});
      }

      await setAppLifecycleState(AppLifecycleState.paused);
      await setAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('5:11 AM'), findsWidgets);
      expect(find.text('5:10 AM'), findsNothing);
      expect(find.text('12:31 PM'), findsWidgets);
    });
  });
}
