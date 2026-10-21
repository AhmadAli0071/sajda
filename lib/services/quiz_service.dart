import 'dart:convert';
import 'dart:math';

import 'package:quran/quran.dart' as q;
import 'package:shared_preferences/shared_preferences.dart';

import 'sajda_stats_service.dart';

class QuizQuestion {
  final String id;
  final String category;
  final String prompt;
  final List<String> options;
  final int correctIndex;

  const QuizQuestion({
    required this.id,
    required this.category,
    required this.prompt,
    required this.options,
    required this.correctIndex,
  });

  String get correctAnswer => options[correctIndex];
}

class QuizProgress {
  final String lastDay;
  final int lastScore;
  final int bestScore;
  final int streak;
  final int totalQuestions;

  const QuizProgress({
    this.lastDay = '',
    this.lastScore = 0,
    this.bestScore = 0,
    this.streak = 0,
    this.totalQuestions = 10,
  });

  bool completedOn(String day) => lastDay == day;

  Map<String, dynamic> toJson() => {
        'lastDay': lastDay,
        'lastScore': lastScore,
        'bestScore': bestScore,
        'streak': streak,
        'totalQuestions': totalQuestions,
      };

  factory QuizProgress.fromJson(Map<String, dynamic> json) => QuizProgress(
        lastDay: json['lastDay']?.toString() ?? '',
        lastScore: (json['lastScore'] as num?)?.toInt() ?? 0,
        bestScore: (json['bestScore'] as num?)?.toInt() ?? 0,
        streak: (json['streak'] as num?)?.toInt() ?? 0,
        totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 10,
      );
}

/// Daily Islamic quiz built entirely from the bundled `quran` package.
///
/// The 341-question bank (surah lengths, surah order, surah numbers) works
/// offline, needs no new API and no extra licensed content. The same 10
/// questions are served to every device on a given calendar day.
class QuizService {
  QuizService._();
  static final QuizService instance = QuizService._();

  static const _kProgress = 'sajda_quiz_progress_v1';
  static const questionsPerDay = 10;

  List<QuizQuestion>? _bank;

  List<QuizQuestion> get bank => _bank ??= _buildBank();

  static String dayKey(DateTime day) => SajdaStatsService.dayKeyOf(day);

  List<QuizQuestion> dailyQuestions([DateTime? now]) {
    final key = dayKey(now ?? DateTime.now());
    final pool = List<QuizQuestion>.of(bank);
    pool.shuffle(Random(stableSeed(key)));
    return pool.take(questionsPerDay).toList(growable: false);
  }

  /// Deterministic seed shared across devices for the same day key.
  static int stableSeed(String value) {
    var hash = 17;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }

  Future<QuizProgress> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kProgress);
    if (raw == null || raw.isEmpty) return const QuizProgress();
    try {
      return QuizProgress.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const QuizProgress();
    }
  }

  /// Records today's attempt once. Returns the updated progress.
  Future<QuizProgress> submit({
    required String day,
    required int correct,
    int total = questionsPerDay,
  }) async {
    final previous = await loadProgress();
    if (previous.completedOn(day)) {
      if (correct > previous.lastScore) {
        final updated = QuizProgress(
          lastDay: day,
          lastScore: correct,
          bestScore: max(previous.bestScore, correct),
          streak: previous.streak,
          totalQuestions: total,
        );
        await _save(updated);
        return updated;
      }
      return previous;
    }

    var streak = 1;
    if (previous.lastDay.isNotEmpty) {
      try {
        final last = DateTime.parse(previous.lastDay);
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        if (dayKey(last) == dayKey(yesterday)) {
          streak = previous.streak + 1;
        }
      } catch (_) {}
    }
    final updated = QuizProgress(
      lastDay: day,
      lastScore: correct,
      bestScore: max(previous.bestScore, correct),
      streak: streak,
      totalQuestions: total,
    );
    await _save(updated);
    await SajdaStatsService.instance.addQuizResult(correct);
    return updated;
  }

  Future<void> _save(QuizProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProgress, jsonEncode(progress.toJson()));
  }

  List<QuizQuestion> _buildBank() {
    final names = <int, String>{
      for (var s = 1; s <= 114; s++) s: q.getSurahNameEnglish(s),
    };
    final questions = <QuizQuestion>[];

    // 1. Surah lengths (114).
    for (var s = 1; s <= 114; s++) {
      final name = names[s]!;
      final count = q.getVerseCount(s);
      final options = _uniqueOptions(
        [
          '$count',
          '${count + 1}',
          '${count + 2}',
          '${max(1, count - 1)}',
        ],
        seed: s * 31,
      );
      questions.add(
        QuizQuestion(
          id: 'ayahs_$s',
          category: 'Quran',
          prompt: 'How many ayahs are in Surah $name?',
          options: options,
          correctIndex: options.indexOf('$count'),
        ),
      );
    }

    // 2. Surah order (113).
    for (var s = 1; s < 114; s++) {
      final name = names[s]!;
      final next = names[s + 1]!;
      final options = _uniqueOptions(
        [
          next,
          names[((s + 11) % 114) + 1]!,
          names[((s + 41) % 114) + 1]!,
          names[((s + 79) % 114) + 1]!,
        ],
        seed: s * 53,
      );
      questions.add(
        QuizQuestion(
          id: 'order_$s',
          category: 'Surah order',
          prompt: 'Which surah comes right after Surah $name?',
          options: options,
          correctIndex: options.indexOf(next),
        ),
      );
    }

    // 3. Surah numbers (114).
    for (var s = 1; s <= 114; s++) {
      final name = names[s]!;
      final options = _uniqueOptions(
        [
          name,
          names[((s + 7) % 114) + 1]!,
          names[((s + 44) % 114) + 1]!,
          names[((s + 88) % 114) + 1]!,
        ],
        seed: s * 71,
      );
      questions.add(
        QuizQuestion(
          id: 'number_$s',
          category: 'Surah number',
          prompt: 'Which surah is number $s in the Quran?',
          options: options,
          correctIndex: options.indexOf(name),
        ),
      );
    }
    return questions;
  }

  /// Keeps exactly four unique options (pads from a fallback pool) and
  /// shuffles them with a stable seed.
  List<String> _uniqueOptions(List<String> candidates, {required int seed}) {
    final out = <String>[];
    for (final value in candidates) {
      if (!out.contains(value)) out.add(value);
    }
    var extra = 1;
    while (out.length < 4) {
      final fallback = 'Option $extra';
      if (!out.contains(fallback)) out.add(fallback);
      extra++;
    }
    out.shuffle(Random(seed));
    return out;
  }
}
