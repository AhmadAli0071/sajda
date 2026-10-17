import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:quran/quran.dart' as q;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class SurahInfo {
  final int number;
  final String nameAr;
  final String nameEn;
  final int ayahCount;
  final String revelation;
  SurahInfo({
    required this.number,
    required this.nameAr,
    required this.nameEn,
    required this.ayahCount,
    required this.revelation,
  });
}

class SearchResult {
  final int surah;
  final int ayah;
  final String arabic;
  final String english;
  final String urdu;
  SearchResult({
    required this.surah,
    required this.ayah,
    required this.arabic,
    this.english = '',
    this.urdu = '',
  });

  String translation(String lang) {
    if (lang == 'ur' && urdu.isNotEmpty) return urdu;
    if (lang == 'en' && english.isNotEmpty) return english;
    return english.isNotEmpty ? english : urdu;
  }
}

class ReciterChoice {
  final String code;
  final String name;
  const ReciterChoice(this.code, this.name);
}

class QuranService {
  static final QuranService instance = QuranService._();
  QuranService._();

  /// Exact Bismillah orthography used by the `quran` package (Tanzil text).
  /// It prefixes verse 1 of every surah except Al-Fatiha (1) and At-Tawbah
  /// (9). Translations never include it — so verse 1's Arabic (Bismillah +
  /// "Alif Lam Meem") would not match its translation ("A.L.M."). Stripped
  /// in [_verseText]; the surah screen shows Bismillah as a header instead.
  static const String _bismillahPrefix = 'بِسْمِ اللَّهِ الرَّحْمَـٰنِ الرَّحِيمِ';

  static const _kBookmarks = 'sajda_quran_bookmarks';
  static const _kDailyAyah = 'sajda_daily_ayah';
  static const _kDailyAyahTr = 'sajda_daily_ayah_tr';

  /// Deterministic verse-of-the-day: changes at midnight, shared across devices.
  Future<SearchResult?> dailyAyah({bool forceNew = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dayKey = '${now.year}-${now.month}-${now.day}';
    final saved = prefs.getString(_kDailyAyah);
    if (!forceNew && saved != null && saved.startsWith('$dayKey|')) {
      final parts = saved.split('|');
      return _result(int.parse(parts[1]), int.parse(parts[2]));
    }
    final dayOfYear = now.difference(DateTime(now.year)).inDays;
    final (s, v) = ayahForDay(dayOfYear);
    final res = _result(s, v);
    await prefs.setString(_kDailyAyah, '$dayKey|$s|$v');
    return res;
  }

  /// Returns the (surah, ayah) for a given day of the year.
  static (int, int) ayahForDay(int dayOfYear) {
    final index = dayOfYear % 6236;
    var remaining = index;
    for (var s = 1; s <= 114; s++) {
      final count = q.getVerseCount(s);
      if (remaining < count) {
        return (s, remaining + 1);
      }
      remaining -= count;
    }
    return (1, 1);
  }

  SearchResult _result(int surah, int ayah) {
    final arabic = _verseText(surah, ayah);
    return SearchResult(
      surah: surah,
      ayah: ayah,
      arabic: arabic,
      english: '',
      urdu: '',
    );
  }

  /// Multi-language translations (ar/ur/en/hi/id) for the daily ayah, served
  /// by the backend from the seeded `ayat_translations` collection. Cached
  /// in prefs for the whole day; null on any failure (Arabic-only fallback).
  Future<Map<String, String>?> dailyAyahTranslations(int surah, int ayah) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final dayKey = '${now.year}-${now.month}-${now.day}';
    final saved = prefs.getString(_kDailyAyahTr);
    if (saved != null && saved.startsWith('$dayKey|')) {
      final rest = saved.substring(dayKey.length + 1);
      final p1 = rest.indexOf('|');
      final p2 = rest.indexOf('|', p1 + 1);
      if (p1 > 0 && p2 > p1 && rest.substring(0, p1) == '$surah' && rest.substring(p1 + 1, p2) == '$ayah') {
        try {
          final decoded = jsonDecode(rest.substring(p2 + 1)) as Map<String, dynamic>;
          return decoded.map((k, v) => MapEntry(k, v?.toString() ?? ''));
        } catch (_) {
          // Corrupt cache → refetch below.
        }
      }
    }
    try {
      final data = await ApiClient.instance.getAyatTranslations(surah, ayah);
      final tr = data?['translations'];
      if (tr is! Map || tr.isEmpty) return null;
      final map = tr.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      await prefs.setString(
        _kDailyAyahTr,
        '$dayKey|$surah|$ayah|${jsonEncode(map)}',
      );
      return map;
    } catch (_) {
      return null;
    }
  }

  static const List<ReciterChoice> reciters = [
    ReciterChoice('ar.alafasy', 'Mishary Alafasy'),
    ReciterChoice('ar.husary', 'Mahmoud Al-Husary'),
    ReciterChoice('ar.ahmedajamy', 'Ahmed Al-Ajamy'),
    ReciterChoice('ar.hudhaify', 'Ali Al-Hudhaify'),
    ReciterChoice('ar.mahermuaiqly', 'Maher Al-Muaiqly'),
    ReciterChoice('ar.muhammadayyoub', 'Muhammad Ayyoub'),
    ReciterChoice('ar.muhammadjibreel', 'Muhammad Jibreel'),
    ReciterChoice('ar.minshawi', 'Minshawi'),
    ReciterChoice('ar.shaatree', 'Abu Bakr Ash-Shaatree'),
  ];

  List<SurahInfo> get surahs {
    return List.generate(114, (i) {
      final n = i + 1;
      return SurahInfo(
        number: n,
        nameAr: q.getSurahNameArabic(n),
        nameEn: q.getSurahNameEnglish(n),
        ayahCount: q.getVerseCount(n),
        revelation: q.getPlaceOfRevelation(n),
      );
    });
  }

  SurahInfo surah(int number) => surahs[number - 1];

  /// Bismillah for the surah-screen header (same orthography as the text).
  static String get bismillahText => _bismillahPrefix;

  /// Verse text with the Bismillah prefix removed from verse 1 (except
  /// Al-Fatiha where it IS verse 1 and At-Tawbah which has none).
  String _verseText(int surah, int ayah) {
    final text = q.getVerse(surah, ayah);
    if (ayah == 1 && surah != 1 && surah != 9 && text.startsWith(_bismillahPrefix)) {
      final rest = text.substring(_bismillahPrefix.length).trim();
      if (rest.isNotEmpty) return rest;
    }
    return text;
  }

  String verseArabic(int surah, int ayah) => _verseText(surah, ayah);

  /// Verse translations fetched from the backend (public-domain sources:
  /// Yusuf Ali/Pickthall for English, Jalandhari/Junagarhi for Urdu).
  /// Cached in memory for the session.
  final Map<String, String> _trCache = {};

  Future<String> verseTranslationAsync(
    int surah,
    int ayah, {
    bool urdu = false,
  }) async {
    final lang = urdu ? 'ur' : 'en';
    final key = '$surah:$ayah:$lang';
    final cached = _trCache[key];
    if (cached != null) return cached;
    try {
      final res = await ApiClient.instance
          .get('/quran/verses/$surah/$ayah/translations?lang=$lang');
      final data = res['data'];
      if (data is Map && data['verse'] is Map) {
        final verse = data['verse'] as Map<String, dynamic>;
        final tr = verse['translations'];
        if (tr is List && tr.isNotEmpty) {
          final text = tr.first['text']?.toString() ?? '';
          if (text.isNotEmpty) {
            _trCache[key] = text;
            return text;
          }
        }
      }
    } catch (_) {
      // Network/API failure → fall through to empty string.
    }
    return '';
  }

  /// Synchronous, cache-only accessor (returns '' until fetched once).
  String verseTranslation(int surah, int ayah, {bool urdu = false}) =>
      _trCache['$surah:$ayah:${urdu ? 'ur' : 'en'}'] ?? '';

  List<SearchResult> search(String query, {bool urdu = false}) {
    final qry = query.trim().toLowerCase();
    if (qry.isEmpty) return const [];
    final results = <SearchResult>[];
    for (var s = 1; s <= 114 && results.length < 200; s++) {
      final count = q.getVerseCount(s);
      for (var v = 1; v <= count; v++) {
        final txt = q.getVerse(s, v);
        if (txt.toLowerCase().contains(qry)) {
          results.add(SearchResult(
            surah: s,
            ayah: v,
            // display text: Bismillah stripped (matching still uses raw txt)
            arabic: _verseText(s, v),
            english: '',
            urdu: '',
          ));
          if (results.length >= 200) break;
        }
      }
    }
    return results;
  }

  /// Full-corpus scan on a background isolate — same results as [search]
  /// but never blocks the UI thread (6,236 verses of toLowerCase+contains
  /// froze low-end devices for 100-500ms per query).
  Future<List<SearchResult>> searchAsync(String query) async {
    final raw = await compute(_searchIsolate, query.trim());
    return raw
        .map((m) => SearchResult(
              surah: m['s'] as int,
              ayah: m['v'] as int,
              arabic: m['a'] as String,
            ))
        .toList(growable: false);
  }

  // ---------- Bookmarks ----------

  Future<Set<String>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kBookmarks);
    if (raw == null) return {};
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> toggleBookmark(int surah, int ayah) async {
    final key = '$surah:$ayah';
    final prefs = await SharedPreferences.getInstance();
    final set = await getBookmarks();
    if (!set.add(key)) set.remove(key);
    await prefs.setString(_kBookmarks, jsonEncode(set.toList()));
  }

  String surahNameWithNumber(int surah) =>
      '$surah. ${q.getSurahNameEnglish(surah)}';
}

/// Top-level isolate entry point for [QuranService.searchAsync].
/// `compute()` requires a top-level/static function; the scan itself is a
/// pure-Dart walk over the embedded Tanzil text (safe off the main isolate).
List<Map<String, dynamic>> _searchIsolate(String qry) {
  if (qry.isEmpty) return const [];
  final lower = qry.toLowerCase();
  final results = <Map<String, dynamic>>[];
  for (var s = 1; s <= 114 && results.length < 200; s++) {
    final count = q.getVerseCount(s);
    for (var v = 1; v <= count; v++) {
      final txt = q.getVerse(s, v);
      if (txt.toLowerCase().contains(lower)) {
        // Strip the Bismillah prefix from verse 1 (same rule as
        // QuranService._verseText) so displayed text stays consistent.
        var arabic = txt;
        if (v == 1 && s != 1 && s != 9 && txt.startsWith(QuranService.bismillahText)) {
          final rest = txt.substring(QuranService.bismillahText.length).trim();
          if (rest.isNotEmpty) arabic = rest;
        }
        results.add({'s': s, 'v': v, 'a': arabic});
        if (results.length >= 200) break;
      }
    }
  }
  return results;
}

