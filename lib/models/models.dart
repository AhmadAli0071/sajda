// ---------- Utility ----------

String _s(dynamic v, [String fallback = '']) =>
    v == null ? fallback : v.toString();

int _i(dynamic v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

double _d(dynamic v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;

bool _b(dynamic v, [bool fallback = false]) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true' || v == '1';
  return fallback;
}

// ---------- Location ----------

class LocationModel {
  final String id;
  final String city;
  final String state;
  final String country;
  final String countryCode;
  final double latitude;
  final double longitude;
  final String timezone;
  final String source; // 'GPS' | 'MANUAL'
  final bool isManual;

  const LocationModel({
    required this.id,
    required this.city,
    required this.state,
    required this.country,
    required this.countryCode,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.source,
    required this.isManual,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) => LocationModel(
        id: _s(json['id']),
        city: _s(json['city']),
        state: _s(json['state']),
        country: _s(json['country']),
        countryCode: _s(json['countryCode']),
        latitude: _d(json['latitude']),
        longitude: _d(json['longitude']),
        timezone: _s(json['timezone']),
        source: _s(json['source'], 'MANUAL'),
        isManual: _b(json['isManual'], true),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'city': city,
        'state': state,
        'country': country,
        'countryCode': countryCode,
        'latitude': latitude,
        'longitude': longitude,
        'timezone': timezone,
        'source': source,
        'isManual': isManual,
      };

  LocationModel copyWith({
    String? id,
    String? city,
    String? state,
    String? country,
    String? countryCode,
    double? latitude,
    double? longitude,
    String? timezone,
    String? source,
    bool? isManual,
  }) =>
      LocationModel(
        id: id ?? this.id,
        city: city ?? this.city,
        state: state ?? this.state,
        country: country ?? this.country,
        countryCode: countryCode ?? this.countryCode,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        timezone: timezone ?? this.timezone,
        source: source ?? this.source,
        isManual: isManual ?? this.isManual,
      );

  @override
  String toString() => '$city, $state, $country';
}

// ---------- Prayer ----------

class PrayerTime {
  final String name;
  final String time;
  PrayerTime(this.name, this.time);
  factory PrayerTime.fromJson(Map<String, dynamic> json) =>
      // AlAdhan's city endpoint returns "05:47 (PKT)"; strip the parenthetical
      // so every consumer sees a clean "HH:mm" (prayer_window._dt would
      // otherwise return null and the `!` on Fajr would throw).
      PrayerTime(
          _s(json['name']),
          _s(json['time']).replaceAll(RegExp(r'\s*\(.*\)'), '').trim());
}

class HijriInfo {
  final String day;
  final String month;
  final String monthAr;
  final String year;
  final String full;
  final String fullAr;
  final int monthNumber;
  HijriInfo({
    this.day = '',
    this.month = '',
    this.monthAr = '',
    this.year = '',
    this.full = '',
    this.fullAr = '',
    this.monthNumber = 0,
  });

  factory HijriInfo.fromJson(Map<String, dynamic> json) => HijriInfo(
        day: _s(json['day']),
        month: _s(json['month']),
        monthAr: _s(json['monthAr']),
        year: _s(json['year']),
        full: _s(json['full']),
        fullAr: _s(json['fullAr']),
        monthNumber: _i(json['monthNumber']),
      );
}

class PrayerTimesResponse {
  final List<PrayerTime> prayers;
  final String date;
  final HijriInfo hijri;
  PrayerTimesResponse({required this.prayers, required this.date, required this.hijri});

  factory PrayerTimesResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['prayers'] as List? ?? [])
        .map((e) => PrayerTime.fromJson(e as Map<String, dynamic>))
        .toList();
    return PrayerTimesResponse(
      prayers: list,
      date: _s(json['date']),
      hijri: HijriInfo.fromJson(json['hijri'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class NextPrayerResponse {
  final String currentTime;
  final String name;
  final String time;
  final int totalMinutes;
  final bool isTomorrow;
  final int countdown;
  final List<PrayerTime> allPrayers;
  final HijriInfo hijri;
  NextPrayerResponse({
    required this.currentTime,
    required this.name,
    required this.time,
    required this.totalMinutes,
    required this.isTomorrow,
    required this.countdown,
    required this.allPrayers,
    required this.hijri,
  });

  factory NextPrayerResponse.fromJson(Map<String, dynamic> json) {
    final next = json['nextPrayer'] as Map<String, dynamic>? ?? {};
    return NextPrayerResponse(
      currentTime: _s(json['currentTime']),
      name: _s(next['name']),
      time: _s(next['time']),
      totalMinutes: _i(next['totalMinutes']),
      isTomorrow: _b(next['isTomorrow']),
      countdown: _i(next['countdown']),
      allPrayers: (json['allPrayers'] as List? ?? [])
          .map((e) => PrayerTime.fromJson(e as Map<String, dynamic>))
          .toList(),
      hijri: HijriInfo.fromJson(json['hijri'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class QiblaResponse {
  final int degree;
  final String direction;
  final int distance;
  QiblaResponse({required this.degree, required this.direction, required this.distance});

  factory QiblaResponse.fromJson(Map<String, dynamic> json) => QiblaResponse(
        degree: _i(json['degree']),
        direction: _s(json['direction']),
        distance: _i(json['distance']),
      );
}

// ---------- Events ----------

class EventDua {
  final String arabic;
  final String urdu;
  final String transliteration;
  EventDua({this.arabic = '', this.urdu = '', this.transliteration = ''});
  factory EventDua.fromJson(Map<String, dynamic> json) => EventDua(
        arabic: _s(json['arabic']),
        urdu: _s(json['urdu']),
        transliteration: _s(json['transliteration']),
      );
}

class IslamicEvent {
  final String id;
  final String month;
  final int monthNumber;
  final int day;
  final String titleEn;
  final String titleUr;
  final String type;
  final String descriptionEn;
  final String descriptionUr;
  final List<String> amal;
  final List<EventDua> duas;
  IslamicEvent({
    required this.id,
    required this.month,
    required this.monthNumber,
    required this.day,
    required this.titleEn,
    required this.titleUr,
    required this.type,
    required this.descriptionEn,
    required this.descriptionUr,
    required this.amal,
    required this.duas,
  });

  String title(String lang) => lang == 'ur' && titleUr.isNotEmpty ? titleUr : titleEn;
  String description(String lang) =>
      lang == 'ur' && descriptionUr.isNotEmpty ? descriptionUr : descriptionEn;

  factory IslamicEvent.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as Map<String, dynamic>? ?? {};
    final desc = json['description'] as Map<String, dynamic>? ?? {};
    return IslamicEvent(
      id: _s(json['_id']),
      month: _s(json['month']),
      monthNumber: _i(json['monthNumber']),
      day: _i(json['day']),
      titleEn: _s(title['en']),
      titleUr: _s(title['ur']),
      type: _s(json['type'], 'general'),
      descriptionEn: _s(desc['en']),
      descriptionUr: _s(desc['ur']),
      amal: (json['amal'] as List? ?? []).map((e) => e.toString()).toList(),
      duas: (json['duas'] as List? ?? [])
          .map((e) => EventDua.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class EventsResponse {
  final List<IslamicEvent> events;
  final String hijriDate;
  EventsResponse({required this.events, this.hijriDate = ''});
  factory EventsResponse.fromJson(Map<String, dynamic> json) => EventsResponse(
        events: (json['events'] as List? ?? [])
            .map((e) => IslamicEvent.fromJson(e as Map<String, dynamic>))
            .toList(),
        hijriDate: _s((json['hijriDate'] as Map<String, dynamic>? ?? {})['full']),
      );
}

// ---------- Hijri calendar ----------

class HijriDay {
  final String gregorian;
  final String day;
  final String month;
  final String monthNumber;
  final String year;
  HijriDay({
    required this.gregorian,
    required this.day,
    required this.month,
    required this.monthNumber,
    required this.year,
  });

  factory HijriDay.fromJson(Map<String, dynamic> json) {
    final h = json['hijri'] as Map<String, dynamic>? ?? {};
    return HijriDay(
      gregorian: _s(json['gregorian']),
      day: _s(h['day']),
      month: _s(h['month']),
      monthNumber: _s(h['monthNumber']),
      year: _s(h['year']),
    );
  }
}

class HijriToday {
  final String day;
  final String month;
  final String monthNumber;
  final String year;
  final String full;
  final String fullAr;
  HijriToday({
    required this.day,
    required this.month,
    required this.monthNumber,
    required this.year,
    required this.full,
    required this.fullAr,
  });

  factory HijriToday.fromJson(Map<String, dynamic> json) => HijriToday(
        day: _s(json['day']),
        month: _s(json['month']),
        monthNumber: _s(json['monthNumber']),
        year: _s(json['year']),
        full: _s(json['full']),
        fullAr: _s(json['fullAr']),
      );
}

// ---------- Salah Streak ----------

