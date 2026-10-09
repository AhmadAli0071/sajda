import 'dart:convert';

import 'package:http/http.dart' as http;

/// Category of a live radio station — drives the filter chips on the Radio
/// screen. [all] is a UI-only pseudo-category.
class RadioCategory {
  static const all = 'all';
  static const recitation = 'recitation';
  static const translation = 'translation';
  static const tafsir = 'tafsir';
  static const adhkar = 'adhkar';
  static const hadith = 'hadith';
  static const occasion = 'occasion';

  static const List<String> values = [
    recitation,
    translation,
    tafsir,
    adhkar,
    hadith,
    occasion,
  ];
}

/// A live Quran radio station from the MP3Quran.net radio API
/// (Icecast streams, freely broadcast for public listening).
class RadioStation {
  final String id;
  final String name; // raw API name (kept for search / back-compat)
  final String url;
  final String category; // one of [RadioCategory.values]
  final String displayName; // friendly label shown in the UI
  final String? translationLanguage; // translation stations only (e.g. 'Urdu')
  final String? reciter; // translation stations only, when a reciter is named

  const RadioStation({
    required this.id,
    required this.name,
    required this.url,
    required this.category,
    required this.displayName,
    this.translationLanguage,
    this.reciter,
  });
}

/// Fetches live Quran radio stations from MP3Quran.net.
///
/// Endpoint: https://mp3quran.net/api/radio/radio_en.json
/// Response shape: {"Radios": [{"Id": "...", "Name": "...", "URL": "..."}]}
///
/// The raw feed mixes reciters, translations, tafsir, adhkar, hadith and
/// seasonal streams, and several reciters share a name across riwayat
/// (Mojawwad / Warsh / Qalun …). We normalize each entry into a category and
/// a friendly display name, disambiguating duplicate reciters by the URL slug.
class RadioService {
  static final RadioService instance = RadioService._();
  RadioService._();

  static const _endpoint =
      'https://mp3quran.net/api/radio/radio_en.json';
  static const _timeout = Duration(seconds: 20);

  List<RadioStation>? _cached;
  Future<List<RadioStation>>? _inFlight;

  List<RadioStation>? get cachedStations => _cached;

  Future<List<RadioStation>> getStations({bool forceRefresh = false}) async {
    if (!forceRefresh && _cached != null) return _cached!;
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = _fetch();
    _inFlight = future;
    try {
      final stations = await future;
      _cached = stations;
      return stations;
    } finally {
      _inFlight = null;
    }
  }

  Future<List<RadioStation>> _fetch() async {
    try {
      final res = await http.get(Uri.parse(_endpoint)).timeout(_timeout);
      if (res.statusCode != 200) {
        throw Exception('status ${res.statusCode}');
      }
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final radios = body['Radios'];
      if (radios is! List) throw Exception('bad shape');

      final stations = <RadioStation>[];
      final seen = <String>{};
      for (final r in radios) {
        if (r is! Map) continue;
        final url = (r['URL'] ?? r['url'])?.toString() ?? '';
        if (!url.startsWith('https://')) continue;
        final name = (r['Name'] ?? r['name'])?.toString().trim() ?? '';
        if (name.isEmpty || !seen.add(url)) continue;
        stations.add(_normalize(
          id: (r['Id'] ?? r['id'])?.toString() ?? url,
          name: name,
          url: url,
        ));
      }
      if (stations.isEmpty) throw Exception('empty');
      stations.sort(
        (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
      return stations;
    } catch (_) {
      throw const RadioApiException(
        'Could not load radio stations. Please check your connection and try again.',
      );
    }
  }

  // ── Normalization ──

  static RadioStation _normalize({
    required String id,
    required String name,
    required String url,
  }) {
    final category = _categorize(name, url);

    if (category == RadioCategory.translation) {
      final lang = _translationLanguage(name);
      final reciter = _translationReciter(name);
      final display = lang != null
          ? 'Quran with $lang Translation'
          : _cleanLabel(name);
      return RadioStation(
        id: id,
        name: name,
        url: url,
        category: category,
        displayName: display,
        translationLanguage: lang,
        reciter: reciter,
      );
    }

    // Reciters can repeat across riwayat — disambiguate via the URL slug.
    var display = _cleanLabel(name);
    if (category == RadioCategory.recitation) {
      final riwayah = _riwayah(url);
      if (riwayah != null) display = '$display ($riwayah)';
    }

    return RadioStation(
      id: id,
      name: name,
      url: url,
      category: category,
      displayName: display,
    );
  }

  static String _categorize(String name, String url) {
    final n = name.toLowerCase();
    final u = url.toLowerCase();

    if (n.contains('translation of the') || u.contains('translation_quran')) {
      return RadioCategory.translation;
    }
    if (n.contains('interpretation') ||
        n.contains('tafsir') ||
        n.contains('tafseer') ||
        u.contains('mokhtasr') ||
        u.contains('mukhtasar') ||
        u.contains('tabri') ||
        u.contains('tafseer')) {
      return RadioCategory.tafsir;
    }
    if (n.contains('remembrance') ||
        n.contains('verses of tranquility') ||
        u.contains('athkar') ||
        u.contains('sakeenah') ||
        u.contains('roqiah') ||
        u.contains('shmaeel')) {
      return RadioCategory.adhkar;
    }
    if (n.contains('sahih') ||
        n.contains('riyad') ||
        n.contains('biography') ||
        n.contains('companions') ||
        n.contains('الفتاوى') ||
        u.contains('saheh') ||
        u.contains('riyad') ||
        u.contains('siyra') ||
        u.contains('sahabah') ||
        u.contains('fatwa')) {
      return RadioCategory.hadith;
    }
    if (n.contains('eid') ||
        n.contains('ramadan') ||
        n.contains('shawwal') ||
        n.contains('dhul-hijjah') ||
        n.contains('ashoora') ||
        n.contains('beautiful recitations') ||
        n.contains('short recitations') ||
        u.contains('/eid') ||
        u.contains('ramadan') ||
        u.contains('sixdaysofshawwal') ||
        u.contains('ten_dhul_hijjah') ||
        u.contains('thedayofashoora') ||
        u.contains('surah_al-mulk') ||
        u.contains('tarateel') ||
        u.contains('/salma')) {
      return RadioCategory.occasion;
    }
    return RadioCategory.recitation;
  }

  static const Map<String, String> _translationLangs = {
    'urdu': 'Urdu',
    'english': 'English',
    'bosnian': 'Bosnian',
    'chinese': 'Chinese',
    'kurdish': 'Kurdish',
    'tamazight': 'Tamazight',
    'turkish': 'Turkish',
    'greek': 'Greek',
    'korean': 'Korean',
    'russian': 'Russian',
    'spanish': 'Spanish',
    'albanian': 'Albanian',
    'french': 'French',
    'german': 'German',
    'hausa': 'Hausa',
    'hungarian': 'Hungarian',
    'persian': 'Persian',
    'portuguese': 'Portuguese',
  };

  static String? _translationLanguage(String name) {
    final n = name.toLowerCase();
    for (final entry in _translationLangs.entries) {
      if (n.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static String? _translationReciter(String name) {
    final m = RegExp(r'[–-]\s*Recit(?:er|ed by)\s+(.+)$', caseSensitive: false)
        .firstMatch(name);
    return m?.group(1)?.trim();
  }

  /// Riwayah marker encoded in the stream URL for duplicate reciters.
  static String? _riwayah(String url) {
    final u = url.toLowerCase();
    if (u.contains('mojawwad')) return 'Mojawwad';
    if (u.contains('warsh')) return 'Warsh';
    if (u.contains('qalon') || u.contains('qalun')) return 'Qalun';
    if (u.contains('assosi')) return 'As-Susi';
    if (u.contains('_khalaf')) return 'Khalaf';
    if (u.contains('aldori_an_abi_amr')) return "Ad-Duri 'an Abi 'Amr";
    if (u.contains('aldorai')) return 'Ad-Duri';
    if (u.contains('ibn_thakwan')) return "Ibn Thakwan 'an Ibn 'Amr";
    if (u.contains('alasbahani')) return 'Al-Asbahani';
    return null;
  }

  /// Strips decorative leading/trailing dashes the feed sometimes wraps
  /// names in (e.g. "-Beautiful Recitations-").
  static String _cleanLabel(String name) {
    var s = name.trim();
    while (s.startsWith('-') || s.startsWith('–')) {
      s = s.substring(1).trim();
    }
    while (s.endsWith('-') || s.endsWith('–')) {
      s = s.substring(0, s.length - 1).trim();
    }
    return s;
  }
}

class RadioApiException implements Exception {
  final String message;
  const RadioApiException(this.message);
  @override
  String toString() => message;
}
