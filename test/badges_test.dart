import 'package:flutter_test/flutter_test.dart';

import 'package:sajda_dataplus/data/badges.dart';
import 'package:sajda_dataplus/services/sajda_stats_service.dart';

void main() {
  group('Sajda badges', () {
    SajdaBadge badge(String id) =>
        sajdaBadges.firstWhere((b) => b.id == id);

    test('every badge unlocks from the stats snapshot it describes', () {
      expect(sajdaBadges, hasLength(18));
      expect(badge('first_prayer').isUnlocked(const SajdaStatsSnapshot()),
          isFalse);
      expect(
        badge('first_prayer')
            .isUnlocked(const SajdaStatsSnapshot(totalPrayers: 1)),
        isTrue,
      );
      expect(
        badge('first_complete_day')
            .isUnlocked(const SajdaStatsSnapshot(completeDays: 1)),
        isTrue,
      );
      expect(
        badge('streak_3').isUnlocked(const SajdaStatsSnapshot(bestStreak: 3)),
        isTrue,
      );
      expect(
        badge('early_bird').isUnlocked(const SajdaStatsSnapshot(fajrCount: 21)),
        isTrue,
      );
      expect(
        badge('tasbeeh_1000')
            .isUnlocked(const SajdaStatsSnapshot(tasbeehSets: 1000)),
        isTrue,
      );
      expect(
        badge('quiz_250').isUnlocked(const SajdaStatsSnapshot(quizCorrect: 250)),
        isTrue,
      );
      expect(
        badge('active_100')
            .isUnlocked(const SajdaStatsSnapshot(activeDays: 100)),
        isTrue,
      );
    });

    test('unlocked count and next badge follow list order', () {
      expect(unlockedBadgeCount(const SajdaStatsSnapshot()), 0);
      expect(
        nextLockedBadge(const SajdaStatsSnapshot())?.id,
        'first_prayer',
      );

      const one = SajdaStatsSnapshot(totalPrayers: 1);
      expect(unlockedBadgeCount(one), 1);
      expect(nextLockedBadge(one)?.id, 'first_complete_day');

      final all = SajdaStatsSnapshot(
        currentStreak: 400,
        bestStreak: 400,
        totalPrayers: 5000,
        completeDays: 400,
        activeDays: 400,
        tasbeehSets: 5000,
        quizCorrect: 500,
        quizDays: 50,
        fajrCount: 400,
        ishaCount: 400,
      );
      expect(unlockedBadgeCount(all), sajdaBadges.length);
      expect(nextLockedBadge(all), isNull);
    });
  });
}
