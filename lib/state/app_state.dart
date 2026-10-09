import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone_finder/timezone_finder.dart';

import '../config.dart';
import '../data/static_data.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/hijri_date_service.dart';
import '../services/prayer_notification_service.dart';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState() {
    WidgetsBinding.instance.addObserver(this);
  }

  static const _kLang = 'sajda_lang';
  static const _kDark = 'sajda_dark';
  static const _kThemeMode = 'sajda_theme_mode';
  static const _kCity = 'sajda_city';
  static const _kNotifications = 'sajda_notifications';
  static const _kDuaNotifications = 'sajda_dua_notifications';
  static const _kWazifaNotifications = 'sajda_wazifa_notifications';
  static const _kAyahNotifications = 'sajda_ayah_notifications';
  static const _kPrayerCheckin = 'sajda_prayer_checkin';
  static const _kOnboarding = 'sajda_onboarding_done';
  static const _kLocationDone = 'sajda_location_done';
  static const _kLocation = 'sajda_location';
  static const _kQuranSurah = 'sajda_quran_surah';
  static const _kQuranAyah = 'sajda_quran_ayah';
  static const _kPrayerNotificationModes = 'sajda_prayer_notification_modes';
  static const _kTasbeehSound = 'sajda_tasbeeh_sound';
  static const _kTasbeehVibration = 'sajda_tasbeeh_vibration';
  static const _kPrayerMethod = 'sajda_prayer_method';
  static const _kAsrSchool = 'sajda_asr_school';
  static const _kContentLang = 'sajda_content_lang';
  static const _kHijriAdjust = 'sajda_hijri_adjust';

  String _language = 'en'; // 'en' | 'ur' | 'ar' | 'bn' | 'id' | 'tr' | 'fa' | 'hi' | 'ms' | 'fr'
  /// Content translation language for Ayat of the Day & Adhkar
  /// ('ar' | 'ur' | 'en' | 'hi' | 'id'). Empty = follow the app UI language.
  String _contentLang = '';
  bool _darkMode = false;
  /// Effective theme preference: light, dark, or follow the OS.
  ThemeMode _themeMode = ThemeMode.system;
  /// Cached platform brightness so [darkMode] is correct while in system mode.
  bool _platformDark = false;
  bool _notificationsEnabled = false;
  bool _duaNotificationsEnabled = false;
  bool _wazifaNotificationsEnabled = false;
  bool _ayahNotificationsEnabled = false;
  bool _prayerCheckinEnabled = false;
  bool _onboardingDone = false;
  bool _locationConfigured = false;
  int _quranSurah = 0;
  int _quranAyah = 0;
  LocationModel? _location;
  CityData? _city;
  double? _lat;
  double? _lng;
  bool _locationFixed = false;
  String? _gpsCityName;
  Locale? _deviceLocale;
  bool _loaded = false;
  Map<String, String> _prayerNotificationModes = {
    'Fajr': 'full',
    'Dhuhr': 'full',
    'Asr': 'full',
    'Maghrib': 'full',
    'Isha': 'full',
  };
  bool _tasbeehSound = true;
  bool _tasbeehVibration = true;
  int _prayerMethod = 2; // ISNA
  int _asrSchool = 0; // Shafi/Standard
  int _hijriAdjust = 0; // Hijri date offset in days (-2..+2)

  String? _authToken;
  String? _userId;
  String? _deviceId;
  String? _displayName;


  String? get authToken => _authToken;
  String? get userId => _userId;
  String? get deviceId => _deviceId;
  String? get displayName => _displayName;
  /// Delegates to AuthService (single source of truth): a cleared/rotated
  /// token there is immediately reflected here — no stale-token desync.
  bool get isAuthenticated => AuthService.instance.isAuthenticated;

  String get language => _language;
  bool get isUrdu => _language == 'ur';

  /// Effective content translation language; snaps to 'en' when the UI
  /// language is one we don't ship content translations for.
  String get contentLang {
    const supported = {'ar', 'ur', 'en', 'hi', 'id'};
    final code = _contentLang.isNotEmpty ? _contentLang : _language;
    return supported.contains(code) ? code : 'en';
  }

  bool get hasCustomContentLang => _contentLang.isNotEmpty;

  /// Explicit theme preference selected on the settings screen.
  ThemeMode get themeMode => _themeMode;

  /// True when the UI is currently dark (explicit dark, or system + OS dark).
  bool get darkMode {
    if (_themeMode == ThemeMode.system) return _platformDark;
    return _themeMode == ThemeMode.dark;
  }

  bool get notificationsEnabled => _notificationsEnabled;
  bool get duaNotificationsEnabled => _duaNotificationsEnabled;
  bool get wazifaNotificationsEnabled => _wazifaNotificationsEnabled;
  bool get ayahNotificationsEnabled => _ayahNotificationsEnabled;
  bool get prayerCheckinEnabled => _prayerCheckinEnabled;
  bool get onboardingDone => _onboardingDone;
  bool get locationConfigured => _locationConfigured;
  int get quranLastSurah => _quranSurah;
  int get quranLastAyah => _quranAyah;
  LocationModel? get location => _location;
  CityData? get city => _city;
  double? get lat => _lat;
  double? get lng => _lng;
  bool get locationFixed => _locationFixed;
  bool get loaded => _loaded;
  Locale? get deviceLocale => _deviceLocale;
  Map<String, String> get prayerNotificationModes =>
      Map.unmodifiable(_prayerNotificationModes);
  bool get tasbeehSound => _tasbeehSound;
  bool get tasbeehVibration => _tasbeehVibration;
  int get prayerMethod => _prayerMethod;
  int get asrSchool => _asrSchool;
  int get hijriAdjust => _hijriAdjust;

  String get locationSource => _location?.source ?? 'MANUAL';
  bool get isManualLocation => _location?.isManual ?? true;

  /// City name shown in the UI.
  String get displayCityName {
    if (_location != null && _location!.city.isNotEmpty) return _location!.city;
    if (_locationFixed && _gpsCityName != null) return _gpsCityName!;
    return _city?.name ?? 'Karachi';
  }

  String get displayCountryName {
    if (_location != null && _location!.country.isNotEmpty) return _location!.country;
    return _city?.country ?? 'Pakistan';
  }

  String get displayStateName {
    if (_location != null && _location!.state.isNotEmpty) return _location!.state;
    return '';
  }

  String get locationTimezone {
    if (_location != null && _location!.timezone.isNotEmpty) return _location!.timezone;
    if (_city != null && _city!.timezone.isNotEmpty) return _city!.timezone;
    return 'Asia/Karachi';
  }

  /// Current Hijri date (Umm al-Qura + user adjustment). One Hijri date per
  /// Gregorian day, matching printed calendars.
  HijriDateInfo get todayHijriDate => HijriDateService.getTodayHijri();

  /// Set the Hijri date offset (-2..+2 days) and persist it. The whole app
  /// picks this up on the next conversion because the service reads the
  /// static [HijriDateService.adjustDays].
  Future<void> setHijriAdjust(int days) async {
    _hijriAdjust = days.clamp(-2, 2);
    HijriDateService.adjustDays = _hijriAdjust;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kHijriAdjust, _hijriAdjust);
  }

  void setDeviceLocale(Locale locale) {
    _deviceLocale = locale;
    notifyListeners();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString(_kLang) ?? 'en';
    _contentLang = prefs.getString(_kContentLang) ?? '';
    _darkMode = prefs.getBool(_kDark) ?? false;
    final themePref = prefs.getString(_kThemeMode);
    _themeMode = switch (themePref) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      // Migration: users who toggled the old dark-mode switch keep it.
      _ => (_darkMode ? ThemeMode.dark : ThemeMode.system),
    };
    _platformDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    _notificationsEnabled = prefs.getBool(_kNotifications) ?? true;
    _duaNotificationsEnabled = prefs.getBool(_kDuaNotifications) ?? true;
    _wazifaNotificationsEnabled =
        prefs.getBool(_kWazifaNotifications) ?? true;
    _ayahNotificationsEnabled = prefs.getBool(_kAyahNotifications) ?? true;
    _prayerCheckinEnabled = prefs.getBool(_kPrayerCheckin) ?? true;
    _onboardingDone = prefs.getBool(_kOnboarding) ?? false;
    _locationConfigured = prefs.getBool(_kLocationDone) ?? false;

    await loadAuth();

    if (!_locationConfigured) {
      final locJson = prefs.getString(_kLocation);
      final city = prefs.getString(_kCity);
      final lat = prefs.getDouble('sajda_lat');
      final lng = prefs.getDouble('sajda_lng');
      if (locJson != null || city != null || (lat != null && lng != null)) {
        _locationConfigured = true;
      }
    }
    _quranSurah = prefs.getInt(_kQuranSurah) ?? 0;
    _quranAyah = prefs.getInt(_kQuranAyah) ?? 0;

    final modesJson = prefs.getString(_kPrayerNotificationModes);
    if (modesJson != null) {
      try {
        final map = jsonDecode(modesJson) as Map<String, dynamic>;
        _prayerNotificationModes = Map.fromEntries(
          map.entries.map((e) => MapEntry(e.key, e.value.toString())),
        );
      } catch (_) {
        // Corrupt persisted JSON -> keep defaults.
      }
    }
    _tasbeehSound = prefs.getBool(_kTasbeehSound) ?? true;
    _tasbeehVibration = prefs.getBool(_kTasbeehVibration) ?? true;
    _prayerMethod = prefs.getInt(_kPrayerMethod) ?? 2;
    _asrSchool = prefs.getInt(_kAsrSchool) ?? 0;
    // Push the persisted Hijri offset into the service BEFORE any UI or API
    // call converts a date (home header, calendar grid, prayer payloads).
    _hijriAdjust = (prefs.getInt(_kHijriAdjust) ?? 0).clamp(-2, 2);
    HijriDateService.adjustDays = _hijriAdjust;

    final cityName = prefs.getString(_kCity);
    if (cityName != null) {
      _city = citiesDb.where((c) => c.name == cityName).firstOrNull;
    }
    _city ??= citiesDb.where((c) => c.name == 'Karachi').firstOrNull;

    final locJson = prefs.getString(_kLocation);
    if (locJson != null) {
      try {
        final map = jsonDecode(locJson) as Map<String, dynamic>;
        _location = LocationModel.fromJson(map);
      } catch (_) {
        _location = null;
      }
    }

    if (_location == null) {
      final cityName = prefs.getString(_kCity);
      final lat = prefs.getDouble('sajda_lat');
      final lng = prefs.getDouble('sajda_lng');
      final gpsCity = prefs.getString('sajda_gps_city');
      if (cityName != null || (lat != null && lng != null)) {
        final city = cityName != null
            ? citiesDb.where((c) => c.name == cityName).firstOrNull
            : nearestCity(lat!, lng!);
        _location = LocationModel(
          id: 'legacy_${cityName ?? '$lat,$lng'}',
          city: city?.name ?? cityName ?? 'Karachi',
          state: '',
          country: city?.country ?? 'Pakistan',
          countryCode: '',
          latitude: lat ?? city?.lat ?? 0,
          longitude: lng ?? city?.lng ?? 0,
          timezone: city?.timezone ?? 'Asia/Karachi',
          source: lat != null && lng != null ? 'GPS' : 'MANUAL',
          isManual: lat == null || lng == null,
        );
        _lat = _location!.latitude;
        _lng = _location!.longitude;
        _locationFixed = _lat != null && _lng != null;
        _gpsCityName = gpsCity;
      }
    }

    _loaded = true;
    notifyListeners();
    await _restoreCoords();
    if (_location == null || !_location!.isManual) {
      unawaited(detectLocation(silent: true));
    }
    _setupPrayerNotificationChannel();
  }

  static const _prayerChannel = MethodChannel('com.sajda.dataplus/prayer_notifications');

  void _setupPrayerNotificationChannel() {
    _prayerChannel.setMethodCallHandler((call) async {
      if (call.method == 'reschedulePrayerNotifications') {
        await _rescheduleAllPrayerNotifications();
        return true;
      }
      return null;
    });
  }

  Future<void> _rescheduleAllPrayerNotifications() async {
    if (!notificationsEnabled) return;
    try {
      final times = await ApiClient.instance.getPrayerTimesFor(this);
      await PrayerNotificationService.instance
          .scheduleAll(times.prayers, isUrdu: isUrdu, prayerModes: prayerNotificationModes);
    } catch (_) {}
  }

  /// Auto-detect location from GPS.
  /// If [silent] is true, won't overwrite an existing manual location.
  Future<void> detectLocation({bool silent = false}) async {
    try {
      if (silent && _location != null && _location!.isManual) {
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.denied ||
            req == LocationPermission.deniedForever) {
          return;
        }
      }
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 12),
          ),
        );
      } catch (_) {
        pos = null;
      }
      pos ??= await Geolocator.getLastKnownPosition();
      if (pos == null || (pos.latitude == 0 && pos.longitude == 0)) return;

      final lat = pos.latitude;
      final lng = pos.longitude;
      final name = await _reverseGeocode(lat, lng);
      final nearest = nearestCity(lat, lng);

      String cityName = nearest?.name ?? '';
      String country = nearest?.country ?? '';
      String state = '';
      String countryCode = '';
      String timezone = nearest?.timezone ?? 'Asia/Karachi';

      if (name != null) {
        final parts = name.split(',');
        if (parts.length >= 2) {
          cityName = parts[0].trim();
          state = parts.length > 2 ? parts[1].trim() : '';
          country = parts.last.trim();
        } else {
          cityName = name.trim();
        }
      }

      final loc = LocationModel(
        id: 'gps_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}',
        city: cityName,
        state: state,
        country: country,
        countryCode: countryCode,
        latitude: lat,
        longitude: lng,
        timezone: timezone,
        source: 'GPS',
        isManual: false,
      );

      await setLocation(loc, notify: true);
    } catch (_) {}
  }

  /// Global forward geocoding search via Nominatim.
  Future<List<LocationModel>> searchLocation(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final isUrdu = _language == 'ur';
      final res = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeQueryComponent(query)}&format=json&limit=15&addressdetails=1&type=city,town,village,municipality',
        ),
        headers: {
          'User-Agent': 'SajdaDataplus/1.0',
          'Accept-Language': isUrdu ? 'ur,en' : 'en',
        },
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];

      final List<dynamic> data = jsonDecode(res.body);
      final results = <LocationModel>[];
      final seenKeys = <String>{};

      for (final item in data) {
        final addr = item['address'] as Map<String, dynamic>? ?? {};
        String city = addr['city'] ??
            addr['town'] ??
            addr['village'] ??
            addr['municipality'] ??
            addr['county'] ??
            addr['state_district'] ??
            addr['state'] ??
            item['display_name']?.split(',')[0] ??
            '';
        city = _normalizeCityName(city.toString());
        if (city.isEmpty) continue;

        final stateVal = addr['state'] ?? '';
        final country = addr['country'] ?? '';
        if (country.isEmpty) continue;

        final countryCode = addr['country_code'] ?? '';
        final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
        final lng = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
        if (lat == 0 && lng == 0) continue;

        // Deduplication key: normalized city + country
        final key = '${city.toLowerCase().trim()}|${country.toLowerCase().trim()}';
        if (seenKeys.contains(key)) continue;
        seenKeys.add(key);

        results.add(LocationModel(
          id: 'search_${item['place_id'] ?? city.toString().toLowerCase().replaceAll(' ', '_')}',
          city: city,
          state: stateVal.toString(),
          country: country.toString(),
          countryCode: countryCode.toString().toUpperCase(),
          latitude: lat,
          longitude: lng,
          timezone: '',
          source: 'MANUAL',
          isManual: true,
        ));
      }

      // Sort: exact match first, then alphabetically
      final queryLower = query.trim().toLowerCase();
      results.sort((a, b) {
        final aExact = a.city.toLowerCase() == queryLower;
        final bExact = b.city.toLowerCase() == queryLower;
        if (aExact && !bExact) return -1;
        if (!aExact && bExact) return 1;
        return a.city.toLowerCase().compareTo(b.city.toLowerCase());
      });

      return results.take(10).toList();
    } catch (_) {
      return [];
    }
  }

  String _normalizeCityName(String city) {
    final lower = city.toLowerCase().trim();
    for (final c in citiesDb) {
      if (c.name.toLowerCase() == lower) return c.name;
      for (final alias in c.aliases) {
        if (alias.toLowerCase() == lower) return c.name;
      }
    }
    return city;
  }

  /// Resolve IANA timezone from lat/lng using timezone_finder (offline, fast, accurate).
  Future<String> _resolveTimezone(double lat, double lng) async {
    try {
      final loc = findLocation(lat, lng);
      if (loc != null && loc.name.isNotEmpty) return loc.name;
    } catch (_) {}
    return 'Asia/Karachi';
  }

  /// Public reverse-geocode helper used by the location setup screen.
  Future<String?> reverseGeocodePublic(double lat, double lng) =>
      _reverseGeocode(lat, lng);

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final res = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&zoom=16'),
        headers: {'User-Agent': 'SajdaDataplus/1.0'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>? ?? {};
      final name = address['suburb'] ??
          address['neighbourhood'] ??
          address['quarter'] ??
          address['town'] ??
          address['village'] ??
          address['city'] ??
          address['county'] ??
          address['state'];
      final city = address['city'] ??
          address['town'] ??
          address['village'] ??
          address['county'] ??
          address['state'];
      final nameStr = name?.toString();
      final cityStr = city?.toString();
      if (nameStr != null && cityStr != null && nameStr != cityStr) {
        return '$nameStr, $cityStr';
      }
      return nameStr ?? cityStr;
    } catch (_) {
      return null;
    }
  }

  /// Restores previously saved GPS coordinates at startup.
  Future<void> _restoreCoords() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('sajda_lat');
    final lng = prefs.getDouble('sajda_lng');
    if (lat != null && lng != null) {
      _lat = lat;
      _lng = lng;
      _locationFixed = true;
      _gpsCityName = prefs.getString('sajda_gps_city');
    }
  }

  /// Sets the central location model. This is the single source of truth.
  Future<void> setLocation(LocationModel loc, {bool notify = true}) async {
    _location = loc;
    _lat = loc.latitude;
    _lng = loc.longitude;
    _locationFixed = loc.latitude != 0 && loc.longitude != 0;

    if (loc.isManual) {
      _city = null;
    } else if (loc.city.isNotEmpty) {
      _city = CityData(
        name: loc.city,
        country: loc.country,
        lat: loc.latitude,
        lng: loc.longitude,
        qibla: 0,
        timezone: loc.timezone,
      );
    }

    _locationConfigured = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLocationDone, true);
    await prefs.setString(_kLocation, jsonEncode(loc.toJson()));
    if (loc.isManual) {
      await prefs.remove(_kCity);
    } else if (loc.city.isNotEmpty) {
      await prefs.setString(_kCity, loc.city);
    }
    await prefs.setDouble('sajda_lat', loc.latitude);
    await prefs.setDouble('sajda_lng', loc.longitude);
    if (loc.source == 'GPS') {
      await prefs.setString('sajda_gps_city', '${loc.city}, ${loc.country}');
    }

    // Resolve timezone FIRST, then notify
    if (loc.timezone.isEmpty) {
      final tz = await _resolveTimezone(loc.latitude, loc.longitude);
      if (tz.isNotEmpty && tz != 'Asia/Karachi') {
        _location = loc.copyWith(timezone: tz);
        await prefs.setString(_kLocation, jsonEncode(_location!.toJson()));
      }
    }

    // Also update _city with resolved timezone
    if (_city != null && _location != null && _location!.timezone.isNotEmpty) {
      _city = CityData(
        name: _city!.name,
        country: _city!.country,
        lat: _city!.lat,
        lng: _city!.lng,
        qibla: _city!.qibla,
        timezone: _location!.timezone,
      );
    }

    if (notify) notifyListeners();

    // Auto-set prayer method & Asr school by country
    if (loc.country.isNotEmpty) {
      await _autoSetPrayerSettings(loc.country);
    }

    // Location changed -> keep backend User.timezone in sync (streak parity).
    unawaited(_syncTimezoneToBackend());
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLang, lang);
  }

  Future<void> setContentLanguage(String code) async {
    if (_contentLang == code) return;
    _contentLang = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kContentLang, code);
  }

  Future<void> setOnboardingDone() async {
    _onboardingDone = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarding, true);
  }

  /// Legacy saveLocation kept for compatibility with LocationSetupScreen.
  Future<void> saveLocation({
    CityData? city,
    double? lat,
    double? lng,
    String? gpsCityName,
  }) async {
    _city = city ?? _city;
    if (lat != null) _lat = lat;
    if (lng != null) _lng = lng;
    if (gpsCityName != null) _gpsCityName = gpsCityName;
    _locationFixed = _lat != null && _lng != null;
    _locationConfigured = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLocationDone, true);
    if (city != null) await prefs.setString(_kCity, city.name);
    if (lat != null) await prefs.setDouble('sajda_lat', lat);
    if (lng != null) await prefs.setDouble('sajda_lng', lng);
    if (gpsCityName != null) {
      await prefs.setString('sajda_gps_city', gpsCityName);
    }
  }

  /// Persists the last-read Quran position so "Continue Reading" can resume.
  Future<void> setQuranPosition(int surah, int ayah) async {
    _quranSurah = surah;
    _quranAyah = ayah;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kQuranSurah, surah);
    await prefs.setInt(_kQuranAyah, ayah);
  }

  /// Sets the theme preference (light / dark / system default).
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _darkMode = mode == ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, mode.name);
    // Keep the legacy flag in sync for older app versions.
    await prefs.setBool(_kDark, _darkMode);
  }

  Future<void> toggleDarkMode() {
    return setThemeMode(
      _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  @override
  void didChangePlatformBrightness() {
    _platformDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    if (_themeMode == ThemeMode.system) notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> setCity(CityData? city) async {
    _city = city;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (city != null) {
      await prefs.setString(_kCity, city.name);
    } else {
      await prefs.remove(_kCity);
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifications, enabled);
  }

  Future<void> setDuaNotificationsEnabled(bool enabled) async {
    _duaNotificationsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDuaNotifications, enabled);
  }

  Future<void> setWazifaNotificationsEnabled(bool enabled) async {
    _wazifaNotificationsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWazifaNotifications, enabled);
  }

  Future<void> setAyahNotificationsEnabled(bool enabled) async {
    _ayahNotificationsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAyahNotifications, enabled);
  }

  Future<void> setPrayerCheckinEnabled(bool enabled) async {
    _prayerCheckinEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrayerCheckin, enabled);
  }

  Future<void> setPrayerNotificationMode(String prayer, String mode) async {
    _prayerNotificationModes[prayer] = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrayerNotificationModes, jsonEncode(_prayerNotificationModes));
  }

  Future<void> setTasbeehSound(bool value) async {
    _tasbeehSound = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTasbeehSound, value);
  }

  Future<void> setTasbeehVibration(bool value) async {
    _tasbeehVibration = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kTasbeehVibration, value);
  }

  Future<void> setPrayerMethod(int method) async {
    _prayerMethod = method;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrayerMethod, method);
  }

  Future<void> setAsrSchool(int school) async {
    _asrSchool = school;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAsrSchool, school);
  }

  /// Auto-select calculation method & Asr school by country.
  /// Returns (method, asrSchool).
  static (int, int) _methodForCountry(String country) {
    final c = country.toLowerCase().trim();
    switch (c) {
      case 'pakistan':
      case 'india':
      case 'bangladesh':
      case 'afghanistan':
      case 'iran':
      case 'turkey':
      case 'azerbaijan':
      case 'uzbekistan':
      case 'kazakhstan':
      case 'kyrgyzstan':
      case 'tajikistan':
      case 'turkmenistan':
        return (3, 1); // MWL + Hanafi
      case 'saudi arabia':
      case 'saudi':
        return (4, 1); // Umm Al-Qura + Hanafi
      case 'egypt':
        return (5, 1); // Egyptian + Hanafi
      case 'united arab emirates':
      case 'uae':
      case 'qatar':
      case 'bahrain':
      case 'kuwait':
      case 'oman':
      case 'yemen':
        return (4, 1); // Umm Al-Qura + Hanafi
      case 'indonesia':
      case 'malaysia':
      case 'brunei':
      case 'singapore':
        return (3, 0); // MWL + Shafi
      case 'morocco':
      case 'algeria':
      case 'tunisia':
      case 'libya':
      case 'mauritania':
        return (3, 0); // MWL + Shafi
      case 'sudan':
      case 'somalia':
      case 'djibouti':
      case 'comoros':
        return (3, 1); // MWL + Hanafi
      case 'jordan':
      case 'lebanon':
      case 'syria':
      case 'palestine':
      case 'iraq':
        return (3, 1); // MWL + Hanafi
      default:
        return (3, 0); // MWL + Shafi (safe default)
    }
  }

  /// Auto-apply calculation method & Asr school based on country.
  Future<void> _autoSetPrayerSettings(String country) async {
    final (method, school) = _methodForCountry(country);
    if (_prayerMethod != method) await setPrayerMethod(method);
    if (_asrSchool != school) await setAsrSchool(school);
  }

  String get prayerCityParam {
    if (_location != null && _location!.city.isNotEmpty) return _location!.city;
    return _city?.name ?? 'Karachi';
  }

  String get prayerCountryParam {
    if (_location != null && _location!.country.isNotEmpty) return _location!.country;
    return _city?.country ?? 'Pakistan';
  }

  /// Localizes a string.
  String t(String en, String ur) {
    if (_language == 'ur') return ur;
    if (_language == 'en') return en;
    final map = AppStrings.translations[en];
    if (map != null) {
      final tr = map[_language];
      if (tr != null && tr.isNotEmpty) return tr;
    }
    return en;
  }

  // ---------- Auth ----------

  Future<void> loadAuth() async {
    await AuthService.instance.load();
    _authToken = AuthService.instance.token;
    _userId = AuthService.instance.userId;
    _displayName = AuthService.instance.displayName;
    _deviceId = AuthService.instance.deviceId;
    notifyListeners();
    // Keep the server's User.timezone in sync so streak recalculation
    // (getMyStreak) uses the same local day as prayer completions.
    unawaited(_syncTimezoneToBackend());
  }

  /// Pushes the selected location's timezone to the backend profile.
  /// Critical: backend streak calculation (calculateStreak) derives "today"
  /// from User.timezone; if it drifts from the timezone used to key
  /// PrayerCompletion records, streaks incorrectly reset to zero.
  Future<void> _syncTimezoneToBackend() async {
    if (!isAuthenticated) return;
    try {
      await AuthService.instance.updateProfile(timezone: locationTimezone);
    } catch (_) {
      // Non-fatal; will retry on next auth load or location change.
    }
  }

  Future<bool> ensureAuthenticated() async {
    if (isAuthenticated) return true;
    try {
      await AuthService.instance.login();
      _authToken = AuthService.instance.token;
      _userId = AuthService.instance.userId;
      _displayName = AuthService.instance.displayName;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> register(String displayName) async {
    try {
      await AuthService.instance.register(displayName);
      _authToken = AuthService.instance.token;
      _userId = AuthService.instance.userId;
      _displayName = AuthService.instance.displayName;
      notifyListeners();
      // Ensure the backend User.timezone matches the selected location so
      // streak day-counting agrees with prayer completion records.
      await AuthService.instance.updateProfile(timezone: locationTimezone);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Adopts the backend session created after a verified Firebase magic-link
  /// sign-in (AuthService.exchangeFirebaseToken already saved it). Mirrors
  /// register()/login() so every gate watching [isAuthenticated] updates.
  void adoptFirebaseSession() {
    _authToken = AuthService.instance.token;
    _userId = AuthService.instance.userId;
    _displayName = AuthService.instance.displayName;
    notifyListeners();
  }

  Future<void> updateDisplayName(String name) async {
    _displayName = name;
    notifyListeners();
    try {
      await AuthService.instance.updateProfile(
        displayName: name,
        timezone: locationTimezone,
      );
    } catch (_) {}
  }

  Future<void> logout() async {
    await AuthService.instance.clear();
    // End the Firebase magic-link session too so the next user signs in
    // with their own verified email.
    try {
      await FirebaseAuthService.instance.signOut();
    } catch (_) {}
    _authToken = null;
    _userId = null;
    _displayName = null;
    _deviceId = null;
    notifyListeners();
  }

}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}




