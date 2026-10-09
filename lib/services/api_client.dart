import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/models.dart';
import '../models/azkar_model.dart';
import '../state/app_state.dart';
import '../services/hijri_date_service.dart';
import '../services/auth_service.dart';
import '../services/date_service.dart';

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

  Future<PrayerTimesResponse> getPrayerTimes(String city, String country, {int method = 3, int school = 1}) async {
    final json = await _get('/prayers/times?city=${Uri.encodeQueryComponent(city)}&country=${Uri.encodeQueryComponent(country)}&method=$method&school=$school');
    return PrayerTimesResponse.fromJson(json['data'] as Map<String, dynamic>);
  }

  Future<PrayerTimesResponse> getPrayerTimesForDate(
      String city, String country, DateTime date, {int method = 3, int school = 1}) async {
    final d =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final json = await _get(
        '/prayers/times?city=${Uri.encodeQueryComponent(city)}&country=${Uri.encodeQueryComponent(country)}&date=$d&method=$method&school=$school');
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
    final cacheKey = '$lat|$lng|$city|$country|$timezone|$dateStr|$method|$school';
    if (useCache && _prayerTimesCacheKey == cacheKey) {
      final cached = cachedPrayerTimes;
      if (cached != null) return cached;
    }

    PrayerTimesResponse result;
    if (lat != 0.0 && lng != 0.0) {
      try {
        result = await _getAladhanPrayerTimes(lat, lng, timezone, dateStr, method, school);
      } catch (_) {
        result = await getPrayerTimes(city, country, method: method, school: school);
      }
    } else {
      result = await getPrayerTimes(city, country, method: method, school: school);
    }
    _cachedPrayerTimes = result;
    _prayerTimesCacheTime = DateTime.now();
    _prayerTimesCacheKey = cacheKey;
    return result;
  }

  Future<PrayerTimesResponse> _getAladhanPrayerTimes(
      double lat, double lng, String timezone, String dateStr, int method, int school) async {
    final uri = Uri.parse(
        'https://api.aladhan.com/v1/timings/$dateStr?latitude=$lat&longitude=$lng&timezone=${Uri.encodeQueryComponent(timezone)}&method=$method&school=$school');
    final res = await http.get(uri, headers: {'User-Agent': 'SajdaDataplus/1.0'});
    if (res.statusCode >= 400) throw ApiException('AlAdhan HTTP ${res.statusCode}');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (json['code'] != 200) throw ApiException('AlAdhan API error');
    final timings = json['data']['timings'] as Map<String, dynamic>;
    final prayers = <PrayerTime>[];
    for (final name in ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      final time = (timings[name]?.toString() ?? '').replaceAll(RegExp(r'\s*\(.*\)'), '');
      if (time.isNotEmpty) prayers.add(PrayerTime(name, time));
    }

    final dateParts = dateStr.split('-');
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
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final method = state.prayerMethod;
    final school = state.asrSchool;

    if (lat != 0.0 && lng != 0.0) {
      try {
        final uri = Uri.parse(
            'https://api.aladhan.com/v1/timings/$dateStr?latitude=$lat&longitude=$lng&timezone=${Uri.encodeQueryComponent(timezone)}&method=$method&school=$school');
    final res = await http.get(uri, headers: {'User-Agent': 'SajdaDataplus/1.0'});
        if (res.statusCode >= 400) throw ApiException('AlAdhan HTTP ${res.statusCode}');
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        if (json['code'] != 200) throw ApiException('AlAdhan API error');
        final timings = json['data']['timings'] as Map<String, dynamic>;
        final prayers = <PrayerTime>[];
        for (final name in ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
          final time = timings[name]?.toString() ?? '';
          if (time.isNotEmpty) prayers.add(PrayerTime(name, time));
        }

        final gregorianDate = DateTime.now();
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
        final currentTimeHm = dateService.nowHmInTimezone(timezone);
        final currentTime = '${currentTimeHm.$1.toString().padLeft(2, '0')}:${currentTimeHm.$2.toString().padLeft(2, '0')}';
        // "Now" must be evaluated in the SAME timezone the prayer times
        // are expressed in — never the device's local clock.
        final currentMinutes = currentTimeHm.$1 * 60 + currentTimeHm.$2;
        final prayerTimes = prayers.map((p) {
          final parts = p.time.split(':');
          if (parts.length == 2) {
            return {'name': p.name, 'time': p.time, 'totalMinutes': int.parse(parts[0]) * 60 + int.parse(parts[1])};
          }
          return null;
        }).whereType<Map<String, dynamic>>().toList();
        
        final nextPrayers = prayerTimes.where((p) => (p['totalMinutes'] as int) > currentMinutes).toList();
        
        Map<String, dynamic> next;
        if (nextPrayers.isEmpty) {
          next = prayerTimes.firstWhere((p) => p['name'] == 'Fajr');
          next['isTomorrow'] = true;
        } else {
          next = nextPrayers.first;
          next['isTomorrow'] = false;
        }
        
        return NextPrayerResponse(
          currentTime: currentTime,
          name: next['name'],
          time: next['time'],
          totalMinutes: next['totalMinutes'],
          isTomorrow: next['isTomorrow'],
          countdown: next['isTomorrow'] 
              ? ((24 * 60 - currentMinutes) + (next['totalMinutes'] as int)) * 60
              : ((next['totalMinutes'] as int) - currentMinutes) * 60,
          allPrayers: prayers,
          hijri: hijriInfoModel,
        );
      } catch (_) {
        // Fallback to backend
      }
    }
    final city = state.prayerCityParam;
    final country = state.prayerCountryParam;
    final json = await _get('/prayers/next-prayer?city=${Uri.encodeQueryComponent(city)}&country=${Uri.encodeQueryComponent(country)}');
    return NextPrayerResponse.fromJson(json['data'] as Map<String, dynamic>);
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

