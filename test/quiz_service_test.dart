import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sajda_dataplus/services/quiz_service.dart';
import 'package:sajda_dataplus/services/sajda_stats_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SajdaStatsService.instance.reload();
  });

  group('daily quiz', () {
    test('bank is large and offline', () {
      expect(QuizService.instance.bank.length, greaterThan(300));
    });

    test('same day yields the same ten unique questions', () {
      final day = DateTime(2026, 10, 19);
      final first = QuizService.instance.dailyQuestions(day);
      final second = QuizService.instance.dailyQuestions(day);
      expect(first, hasLength(QuizService.questionsPerDay));
      expect(
        first.map((q) => q.id).toSet(),
        hasLength(QuizService.questionsPerDay),
      );
      expect(
        first.map((q) => q.id).toList(),
        second.map((q) => q.id).toList(),
      );
      for (final q in first) {
        expect(q.options, hasLength(4));
        expect(q.options.toSet(), hasLength(4));
        expect(q.correctIndex, inInclusiveRange(0, 3));
        expect(q.correctAnswer, isNotEmpty);
      }
    });

    test('a different day yields a different question set', () {
      final a = QuizService.instance
          .dailyQuestions(DateTime(2026, 10, 19))
          .map((q) => q.id)
          .toList();
      final b = QuizService.instance
          .dailyQuestions(DateTime(2026, 11, 19))
          .map((q) => q.id)
          .toList();
      expect(a, isNot(equals(b)));
    });

    test('stable seed does not depend on platform hashing', () {
      final seed = QuizService.stableSeed('2026-10-19');
      expect(seed, QuizService.stableSeed('2026-10-19'));
      expect(seed, isNot(QuizService.stableSeed('2026-10-20')));
      expect(seed, greaterThanOrEqualTo(0));
    });

    test('submitting records the day and feeds stats once', () async {
      final day = QuizService.dayKey(DateTime.now());
      final first = await QuizService.instance.submit(day: day, correct: 7);
      expect(first.lastDay, day);
      expect(first.lastScore, 7);
      expect(first.bestScore, 7);
      expect(first.streak, 1);
      expect(SajdaStatsService.instance.quizCorrect, 7);
      expect(SajdaStatsService.instance.quizDays, 1);

      final second = await QuizService.instance.submit(day: day, correct: 5);
      expect(second.lastScore, 7);
      expect(second.streak, 1);
      expect(SajdaStatsService.instance.quizCorrect, 7);

      final better = await QuizService.instance.submit(day: day, correct: 9);
      expect(better.lastScore, 9);
      expect(better.bestScore, 9);
      expect(SajdaStatsService.instance.quizCorrect, 7);
    });

    test('streak continues only when yesterday was played', () async {
      final yesterday =
          QuizService.dayKey(DateTime.now().subtract(const Duration(days: 1)));
      SharedPreferences.setMockInitialValues({
        'sajda_quiz_progress_v1':
            '{"lastDay":"$yesterday","lastScore":8,"bestScore":8,"streak":4,"totalQuestions":10}',
      });
      await SajdaStatsService.instance.reload();

      final today = QuizService.dayKey(DateTime.now());
      final progress = await QuizService.instance.submit(
        day: today,
        correct: 6,
      );
      expect(progress.streak, 5);
      expect(progress.bestScore, 8);
    });

    test('a skipped day resets the quiz streak', () async {
      final twoDaysAgo = QuizService.dayKey(
        DateTime.now().subtract(const Duration(days: 2)),
      );
      SharedPreferences.setMockInitialValues({
        'sajda_quiz_progress_v1':
            '{"lastDay":"$twoDaysAgo","lastScore":8,"bestScore":8,"streak":4,"totalQuestions":10}',
      });
      await SajdaStatsService.instance.reload();

      final progress = await QuizService.instance.submit(
        day: QuizService.dayKey(DateTime.now()),
        correct: 6,
      );
      expect(progress.streak, 1);
    });

    test('corrupt progress falls back to a clean slate', () async {
      SharedPreferences.setMockInitialValues({
        'sajda_quiz_progress_v1': 'not-json',
      });
      final progress = await QuizService.instance.loadProgress();
      expect(progress.lastDay, isEmpty);
      expect(progress.streak, 0);
    });
  });
}
