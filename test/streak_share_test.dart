import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sajda_dataplus/state/app_state.dart';
import 'package:sajda_dataplus/utils/streak_share_text.dart';
import 'package:sajda_dataplus/widgets/streak/streak_share_card.dart';

/// F1: share card — caption must carry the store link, must NEVER mention
/// ratings/reviews (Play policy), and the card must render its data.
void main() {
  group('buildStreakShareCaption', () {
    test('includes streak with singular day', () {
      final text = buildStreakShareCaption(currentStreak: 1);
      expect(text, contains('1 day'));
      expect(text.contains('1 days'), isFalse);
    });

    test('plural days + personal best line', () {
      final text = buildStreakShareCaption(currentStreak: 12, bestStreak: 30);
      expect(text, contains('12 days'));
      expect(text, contains('Personal best: 30 days'));
    });

    test('omits best line when best is zero', () {
      final text = buildStreakShareCaption(currentStreak: 4, bestStreak: 0);
      expect(text.contains('Personal best'), isFalse);
    });

    test('always includes the Play Store link', () {
      final text = buildStreakShareCaption(currentStreak: 3);
      expect(text, contains(kDefaultAppUrl));
    });

    test('empty custom url falls back to the store link', () {
      final text =
          buildStreakShareCaption(currentStreak: 3, appUrl: '   ');
      expect(text, contains(kDefaultAppUrl));
    });

    test('never asks for a rating or review (Play policy)', () {
      final text = buildStreakShareCaption(currentStreak: 8, bestStreak: 10);
      final lower = text.toLowerCase();
      expect(lower.contains('rate us'), isFalse);
      expect(lower.contains('rating'), isFalse);
      expect(lower.contains('review'), isFalse);
      expect(lower.contains('star'), isFalse);
    });
  });

  group('shareCardMonthLabel', () {
    test('formats month + year', () {
      expect(shareCardMonthLabel(DateTime(2026, 10, 19)), 'October 2026');
      expect(shareCardMonthLabel(DateTime(2027, 1, 1)), 'January 2027');
      expect(shareCardMonthLabel(DateTime(2025, 12, 31)), 'December 2025');
    });
  });

  group('StreakShareCard', () {
    Future<void> pumpCard(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppState>.value(
            value: AppState(),
            child: const Scaffold(
              body: Center(
                child: StreakShareCard(
                  currentStreak: 12,
                  bestStreak: 30,
                  todayCount: 3,
                  monthLabel: 'October 2026',
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders streak, best, today count and month',
        (tester) async {
      await pumpCard(tester);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Best: 30'), findsOneWidget);
      expect(find.text('Today 3/5'), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text('SAJDA'), findsOneWidget);
    });

    testWidgets('clamps out-of-range today count instead of overflowing',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AppState>.value(
            value: AppState(),
            child: const Scaffold(
              body: Center(
                child: StreakShareCard(
                  currentStreak: 2,
                  bestStreak: 5,
                  todayCount: 9,
                  monthLabel: 'January 2026',
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Today 5/5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
