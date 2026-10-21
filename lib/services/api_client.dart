import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/models.dart';
import '../models/azkar_model.dart';
import '../state/app_state.dart';
import '../services/hijri_date_service.dart';
import '../services/auth_service.dart';
import '../services/date_service.dart';
import '../services/local_prayer_times_service.dart';
import '../services/widget_service.dart';

class ApiException implements Exception {
  final String message;
  /// Machine-readable error code from the backend (e.g. INVALID_INVITE,
  /// HAVE_ACTIVE_STREAK, STREAK_NOT_ACTIVE...). Null when the backend did
  /// not send one — callers must fall back to [message]/[status].
  final String? code;
  /// HTTP status code (400/401/403/404...) or null for transport errors.
  final int? status;
  ApiException(this.message, {this.code, this.status});
  bool get isAuthError => status == 401 || code == 'UNAUTHORIZED' || code == 'TOKEN_EXPIRED' || code == 'INVALID_TOKEN';
  bool get isNetworkError => status == null;
  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient instance = ApiClient._();
  ApiClient._();

  final String _base = AppConfig.apiBaseUrl;

  PrayerTimesResponse? _cachedPrayerTimes;
  DateTime? _prayerTimesCacheTime;
  // Cache is only valid for the exact inputs it was built with — a location
  // or calculation-method change must NEVER serve stale times.
  String? _prayerTimesCacheKey;

  PrayerTimesResponse? get cachedPrayerTimes {
    if (_cachedPrayerTimes == null || _prayerTimesCacheTime == null) return null;
    if (DateTime.now().difference(_prayerTimesCacheTime!) > const Duration(hours: 1)) {
      _cachedPrayerTimes = null;
      _prayerTimesCacheTime = null;
      return null;
    }
    return _cachedPrayerTimes;
  }

  void invalidatePrayerTimesCache() {
    _cachedPrayerTimes = null;
    _prayerTimesCacheTime = null;
    _prayerTimesCacheKey = null;
  }

  /// Test-only: seed the prayer-times cache so widget tests can exercise
  /// screen refreshes (e.g. app resume) without any network.
  @visibleForTesting
  void primePrayerTimesCache(PrayerTimesResponse times,
      {required String cacheKey}) {
    _cachedPrayerTimes = times;
    _prayerTimesCacheTime = DateTime.now();
    _prayerTimesCacheKey = cacheKey;
  }


  Map<String, String> _headers() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = AuthService.instance.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, dynamic> _unwrap(http.Response res) {
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Server returned invalid response', status: res.statusCode);
    }
    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'API error',
        code: json['code']?.toString(),
        status: res.statusCode,
      );
    }
    return json;
  }

  Future<Map<String, dynamic>> _get(String path) async {
    http.Response res;
    try {
      res = await http.get(Uri.parse('$_base$path'), headers: _headers())
          .timeout(const Duration(seconds: 15));
    } on Exception {
      rethrow;
    }
    return _unwrapChecked(res);
  }

  Map<String, dynamic> _unwrapChecked(http.Response res) {
    if (res.statusCode >= 400) {
      Map<String, dynamic>? json;
      try {
        json = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
      throw ApiException(
        json?['message']?.toString() ?? 'HTTP ${res.statusCode}',
        code: json?['code']?.toString(),
        status: res.statusCode,
      );
    }
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> get(String path) => _get(path);

  /// Public POST for feature repositories (v2 streak, etc.).
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) => _post(path, body);

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$_base$path'),
      headers: _headers(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    return _unwrapChecked(res);
  }

  // ---------- Prayer ----------

  /// Backend `/prayers/times` path. The date travels in the URL as
  /// YYYY-MM-DD (the backend converts it to AlAdhan's DD-MM-YYYY itself,
  /// see prayerService.js) so the server-side cache — keyed by request URL
  /// — gets one entry per day instead of serving yesterday's times across
  /// midnight. [method]/[school] are always the caller's resolved settings
  /// (manual choice wins over country auto-detect).
  @visibleForTesting
  static String prayerTimesPath({
    required String city,
    required String country,
    required String date,
    required int method,
    required int school,
  }) =>
      '/prayers/times?city=${Uri.encodeQueryComponent(city)}'
      '&country=${Uri.encodeQueryComponent(country)}&date=$date'
      '&method=$method&school=$school';

  /// AlAdhan's `/timings/{date}` path expects DD-MM-YYYY while the app
  /// stores YYYY-MM-DD. Sending YYYY-MM-DD makes AlAdhan silently misread
  /// the YEAR (e.g. 2026-10-09 -> 09 Oct 2009), which applies outdated DST
  /// rules and throws every prayer off by an hour.
  @visibleForTesting
  static String aladhanDateFromYmd(String dateStr) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(dateStr);
    if (m == null) return dateStr;
    return '${m[3]}-${m[2]}-${m[1]}';
  }

  /// Prayer-times cache key. Only the exact inputs the times were built
  /// with may be served from cache — coordinates, city, country, timezone,
  /// civil date, method and school each get their own entry.
  @visibleForTesting
  static String prayerCacheKey({
    required double lat,
    required double lng,
    required String city,
    required String country,
    required String timezone,
    required String date,
    required int method,
    required int school,
  }) =>
      '$lat|$lng|$city|$country|$timezone|$date|$method|$school';

  /// The failures the direct AlAdhan call may reasonably hit: HTTP/API
  /// errors, timeout, transport errors. Anything else (JSON shape errors,
  /// other programming errors) is NOT a route failure and must reach the
  /// caller instead of silently switching routes.
  static bool _isAladhanRouteFailure(Object e) =>
      e is ApiException ||
      e is TimeoutException ||
      e is http.ClientException ||
      e is IOException;

  /// Sanitized reason for logs. Never the request URL/exception text —
  /// those embed the user's coordinates and timezone.
  static String _routeFailureReason(Object e) {
    if (e is ApiException) return e.message;
    if (e is TimeoutException) return 'timed out';
    return e.runtimeType.toString();
  }

  Future<PrayerTimesResponse> getPrayerTimes(String city, String country,
      {required String date, required int method, required int school}) async {
    final json = await _get(prayerTimesPath(
        city: city,
        country: country,
        date: date,
        method: method,
        school: school));
    return PrayerTimesResponse.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<PrayerTimesResponse> getPrayerTimesForDate(
      String city, String country, DateTime date,
      {required int method, required int school}) async {
    final d =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final json = await _get(prayerTimesPath(
        city: city,
        country: country,
        date: d,
        method: method,
        school: school));
    return PrayerTimesResponse.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<PrayerTimesResponse> getPrayerTimesByCoords(double lat, double lng) async {
    final json = await _get('/prayers/times?lat=$lat&lng=$lng');
    return PrayerTimesResponse.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<PrayerTimesResponse> getPrayerTimesFor(AppState state, {bool useCache = true}) async {
    final lat = state.lat ?? 0.0;
    final lng = state.lng ?? 0.0;
    final city = state.prayerCityParam;
    final country = state.prayerCountryParam;
    final timezone = state.locationTimezone;
    final date = DateTime.now();
    final dateStr = dateService.formatDateAsYYYYMMDD(date: date, timezone: timezone);
    final method = state.prayerMethod;
    final school = state.asrSchool;

    // Cache is only valid for the exact inputs it was built with — a
    // location/method/school change or a new day must refetch.
    final cacheKey = prayerCacheKey(
        lat: lat,
        lng: lng,
        city: city,
        country: country,
        timezone: timezone,
        date: dateStr,
        method: method,
        school: school);
    if (useCache && _prayerTimesCacheKey == cacheKey) {
      final cached = cachedPrayerTimes;
      if (cached != null) return cached;
    }

    // non-final: Dart's flow analysis can't prove a `final` is assigned at
    // most once across the try/catch fallback below.
    // ignore: prefer_final_locals
    PrayerTimesResponse result;
    if (lat != 0.0 && lng != 0.0) {
      // Local first: `adhan` computes offline in-process — zero network,
      // zero server load, and correct even without connectivity (F3).
      final local = LocalPrayerTimesService.calculate(
        lat: lat,
        lng: lng,
        timezone: timezone,
        // The location's civil day (never the device's date fields): near
        // midnight the device can already be on tomorrow while [dateStr]
        // — and every other route below — is still today.
        date: DateTime.parse(dateStr),
        method: method,
        school: school,
      );
      if (local != null) {
        debugPrint('PrayerTimes: route=local (adhan)');
        result = local;
      } else {
        // Coordinates rejected by the local calculator (should be rare) —
        // keep the old network paths as a safety net.
        try {
          result = await _getAladhanPrayerTimes(lat, lng, timezone, dateStr, method, school);
          debugPrint('PrayerTimes: route=aladhan-direct');
        } catch (e) {
          if (!_isAladhanRouteFailure(e)) rethrow;
          debugPrint(
              'PrayerTimes: aladhan-direct failed (${_routeFailureReason(e)}) -> route=backend-city');
          result = await getPrayerTimes(city, country,
              date: dateStr, method: method, school: school);
        }
      }
    } else {
      debugPrint('PrayerTimes: route=backend-city (no coordinates)');
      result = await getPrayerTimes(city, country,
          date: dateStr, method: method, school: school);
    }
    _cachedPrayerTimes = result;
    _prayerTimesCacheTime = DateTime.now();
    _prayerTimesCacheKey = cacheKey;
    // Home screen widget (F2): keep the widget's copy of today's times in
    // sync whenever fresh times land (fire-and-forget, fully guarded).
    unawaited(WidgetService.savePrayerTimes(result, city: state.displayCityName));
    return result;
  }

  Future<PrayerTimesResponse> _getAladhanPrayerTimes(
      double lat, double lng, String timezone, String dateStr, int method, int school) async {
    final dateParts = dateStr.split('-');
    final aladhanDate = aladhanDateFromYmd(dateStr);
    final uri = Uri.parse(
        'https://api.aladhan.com/v1/timings/$aladhanDate?latitude=$lat&longitude=$lng&timezone=${Uri.encodeQueryComponent(timezone)}&method=$method&school=$school');
    final res = await http
        .get(uri, headers: {'User-Agent': 'SajdaDataplus/1.0'})
        .timeout(const Duration(seconds: 15));
    if (res.statusCode >= 400) throw ApiException('AlAdhan HTTP ${res.statusCode}');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (json['code'] != 200) throw ApiException('AlAdhan API error');
    final timings = json['data']['timings'] as Map<String, dynamic>;
    final prayers = <PrayerTime>[];
    for (final name in ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      final time = (timings[name]?.toString() ?? '').replaceAll(RegExp(r'\s*\(.*\)'), '');
      if (time.isNotEmpty) prayers.add(PrayerTime(name, time));
    }

    final gregorianDate = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );
    final hijriInfo = HijriDateService.getHijriDate(gregorianDate);

    final hijriInfoModel = HijriInfo(
      day: hijriInfo.day.toString(),
      month: hijriInfo.monthEn,
      monthAr: hijriInfo.monthAr,
      year: hijriInfo.year.toString(),
      full: hijriInfo.full,
      fullAr: hijriInfo.fullAr,
      monthNumber: hijriInfo.month,
    );
    return PrayerTimesResponse(prayers: prayers, date: dateStr, hijri: hijriInfoModel);
  }

  Future<NextPrayerResponse> getNextPrayer(String city, String country) async {
    final json = await _get('/prayers/next-prayer?city=${Uri.encodeQueryComponent(city)}&country=${Uri.encodeQueryComponent(country)}');
    return NextPrayerResponse.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<NextPrayerResponse> getNextPrayerByCoords(AppState state) async {
    final lat = state.lat ?? 0.0;
    final lng = state.lng ?? 0.0;
    final timezone = state.locationTimezone;
    final date = DateTime.now();
    // Same rule as getPrayerTimesFor: the location's civil day, never the
    // device's date fields (they can already be tomorrow near midnight).
    final dateStr = dateService.formatDateAsYYYYMMDD(date: date, timezone: timezone);
    final method = state.prayerMethod;
    final school = state.asrSchool;

    if (lat != 0.0 && lng != 0.0) {
      // Local first (F3): on-device `adhan` calculation, zero network.
      final local = LocalPrayerTimesService.calculate(
        lat: lat,
        lng: lng,
        timezone: timezone,
        date: DateTime.parse(dateStr),
        method: method,
        school: school,
      );
      if (local != null) return _buildNextPrayer(local, timezone);

      try {
        final uri = Uri.parse(
            'https://api.aladhan.com/v1/timings/${aladhanDateFromYmd(dateStr)}?latitude=$lat&longitude=$lng&timezone=${Uri.encodeQueryComponent(timezone)}&method=$method&school=$school');
        final res = await http
            .get(uri, headers: {'User-Agent': 'SajdaDataplus/1.0'})
            .timeout(const Duration(seconds: 15));
        if (res.statusCode >= 400) throw ApiException('AlAdhan HTTP ${res.statusCode}');
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        if (json['code'] != 200) throw ApiException('AlAdhan API error');
        final timings = json['data']['timings'] as Map<String, dynamic>;
        final prayers = <PrayerTime>[];
        for (final name in ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
          final time = (timings[name]?.toString() ?? '').replaceAll(RegExp(r'\s*\(.*\)'), '');
          if (time.isNotEmpty) prayers.add(PrayerTime(name, time));
        }

        final gregorianDate = DateTime.parse(dateStr);
        final hijriInfo = HijriDateService.getHijriDate(gregorianDate);

        final hijriInfoModel = HijriInfo(
          day: hijriInfo.day.toString(),
          month: hijriInfo.monthEn,
          monthAr: hijriInfo.monthAr,
          year: hijriInfo.year.toString(),
          full: hijriInfo.full,
          fullAr: hijriInfo.fullAr,
          monthNumber: hijriInfo.month,
        );
        return _buildNextPrayer(
          PrayerTimesResponse(prayers: prayers, date: dateStr, hijri: hijriInfoModel),
          timezone,
        );
      } catch (e) {
        if (!_isAladhanRouteFailure(e)) rethrow;
        debugPrint(
            'PrayerTimes: aladhan-direct failed (${_routeFailureReason(e)}) -> route=backend-city (next-prayer)');
      }
    }
    final city = state.prayerCityParam;
    final country = state.prayerCountryParam;
    final json = await _get('/prayers/next-prayer?city=${Uri.encodeQueryComponent(city)}&country=${Uri.encodeQueryComponent(country)}');
    return NextPrayerResponse.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Derives the current/next prayer from [response] evaluated in the
  /// SAME timezone the prayer times are expressed in — never the device
  /// clock (device TZ can differ from the selected location while travel).
  NextPrayerResponse _buildNextPrayer(PrayerTimesResponse response, String timezone) {
    final prayers = response.prayers;
    final currentTimeHm = dateService.nowHmInTimezone(timezone);
    final currentTime =
        '${currentTimeHm.$1.toString().padLeft(2, '0')}:${currentTimeHm.$2.toString().padLeft(2, '0')}';
    final currentMinutes = currentTimeHm.$1 * 60 + currentTimeHm.$2;
    final prayerTimes = prayers.map((p) {
      final clean = p.time.replaceAll(RegExp(r'\s*\(.*\)'), '');
      final parts = clean.split(':');
      final h = parts.length >= 2 ? int.tryParse(parts[0]) : null;
      final m = parts.length >= 2 ? int.tryParse(parts[1]) : null;
      if (h == null || m == null) return null;
      return {
        'name': p.name,
        'time': clean,
        'totalMinutes': h * 60 + m,
      };
    }).whereType<Map<String, dynamic>>().toList();

    final nextPrayers =
        prayerTimes.where((p) => (p['totalMinutes'] as int) > currentMinutes).toList();

    Map<String, dynamic> next;
    bool isTomorrow;
    if (nextPrayers.isEmpty) {
      next = prayerTimes.firstWhere((p) => p['name'] == 'Fajr');
      isTomorrow = true;
    } else {
      next = nextPrayers.first;
      isTomorrow = false;
    }

    return NextPrayerResponse(
      currentTime: currentTime,
      name: next['name'] as String,
      time: next['time'] as String,
      totalMinutes: next['totalMinutes'] as int,
      isTomorrow: isTomorrow,
      countdown: isTomorrow
          ? ((24 * 60 - currentMinutes) + (next['totalMinutes'] as int)) * 60
          : ((next['totalMinutes'] as int) - currentMinutes) * 60,
      allPrayers: prayers,
      hijri: response.hijri,
    );
  }

  Future<QiblaResponse> getQibla(double lat, double lng) async {
    final json = await _get('/qibla/direction?lat=$lat&lng=$lng');
    return QiblaResponse.fromJson(json['data'] as Map<String, dynamic>);
  }

  // ---------- Events ----------

  Future<List<IslamicEvent>> getTodayEvents() async {
    final json = await _get('/events/today');
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return (data['events'] as List? ?? [])
        .map((e) => IslamicEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<IslamicEvent>> getMonthEvents(String month) async {
    final json = await _get('/events/month/$month');
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return (data['events'] as List? ?? [])
        .map((e) => IslamicEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<IslamicEvent>> getUpcomingEvents({int limit = 10}) async {
    final json = await _get('/events/upcoming?limit=$limit');
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return (data['events'] as List? ?? [])
        .map((e) => IslamicEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------- Ayat of the Day (multi-language) ----------

  /// Returns the ayat translations document:
  /// { surah, ayah, arabic, translations: {ar,ur,en,hi,id} } or null.
  Future<Map<String, dynamic>?> getAyatTranslations(int surah, int ayah) async {
    final json = await _get('/ayat/$surah/$ayah');
    return json['data'] as Map<String, dynamic>?;
  }

  // ---------- Adhkar (multi-language) ----------

  Future<List<ZikrCategory>> getAdhkar() async {
    final json = await _get('/adhkar');
    return (json['data'] as List? ?? [])
        .map((e) => ZikrCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------- Hijri ----------

  Future<HijriToday> getHijriToday() async {
    final json = await _get('/hijri/today');
    return HijriToday.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<List<HijriDay>> getHijriCalendar({int? month, int? year}) async {
    final params = <String>[];
    if (month != null) params.add('month=$month');
    if (year != null) params.add('year=$year');
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    final json = await _get('/hijri/calendar$q');
    return (json['data'] as List? ?? [])
        .map((e) => HijriDay.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------- Streak (v2) ----------
  // The v2 streak API lives in streak_v2_api.dart (typed repository).
  // v1 streak endpoints remain available on the server for old app versions
  // but are no longer called from this client.

  // ---------- Account ----------

  Future<void> deleteAccount(AppState state) async {
    await http.delete(
      Uri.parse('$_base/auth/account'),
      headers: _headers(),
    ).timeout(const Duration(seconds: 15));
  }
}

