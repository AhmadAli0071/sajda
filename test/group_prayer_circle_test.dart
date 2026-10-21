import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sajda_dataplus/models/streak_v2.dart';
import 'package:sajda_dataplus/state/app_state.dart';
import 'package:sajda_dataplus/widgets/streak/group_prayer_circle.dart';

void main() {
  Future<void> pumpCircle(
    WidgetTester tester,
    List<MemberProgress> members,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 350,
                child: GroupPrayerCircle(
                  members: members,
                  completed: 2,
                  needed: 5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  const fiveMembers = [
    MemberProgress(
      userId: '1',
      displayName: 'Aisha',
      eligible: true,
      completedCount: 5,
      isDayComplete: true,
    ),
    MemberProgress(userId: '2', displayName: 'Bilal', eligible: true, completedCount: 3),
    MemberProgress(userId: '3', displayName: 'Cody', eligible: true, completedCount: 1),
    MemberProgress(userId: '4', displayName: 'Dua', eligible: true, completedCount: 0),
    MemberProgress(userId: '5', displayName: 'Emaan', eligible: true, completedCount: 4),
  ];

  Finder outerStack() => find
      .descendant(
        of: find.byType(GroupPrayerCircle),
        matching: find.byType(Stack),
      )
      .first;

  testWidgets('avatar ring stack is a square centered in the card',
      (tester) async {
    await pumpCircle(tester, fiveMembers);

    final stackRect = tester.getRect(outerStack());
    expect(stackRect.width, moreOrLessEquals(stackRect.height, epsilon: 0.1),
        reason: 'a non-square stack means the ring math is laid out wrong');
    expect(stackRect.width, moreOrLessEquals(220, epsilon: 0.5));

    final cardRect = tester.getRect(find.byType(GroupPrayerCircle));
    expect(stackRect.center.dx, moreOrLessEquals(cardRect.center.dx, epsilon: 0.5));
  });

  testWidgets('every avatar sits on the ring and stays inside the stack',
      (tester) async {
    await pumpCircle(tester, fiveMembers);

    final stackRect = tester.getRect(outerStack());
    final radius = stackRect.width / 2 - 28;

    const names = ['Aisha', 'Bilal', 'Cody', 'Dua', 'Emaan'];
    final centers = [
      for (final name in names) tester.getCenter(find.byTooltip(name)),
    ];

    final avg = Offset(
      centers.map((c) => c.dx).reduce((a, b) => a + b) / centers.length,
      centers.map((c) => c.dy).reduce((a, b) => a + b) / centers.length,
    );
    expect(avg.dx, moreOrLessEquals(stackRect.center.dx, epsilon: 0.5));
    expect(avg.dy, moreOrLessEquals(stackRect.center.dy, epsilon: 0.5));

    for (final center in centers) {
      expect(
        (center - stackRect.center).distance,
        moreOrLessEquals(radius, epsilon: 0.5),
        reason: 'avatars must orbit the hub center, not the top-left corner',
      );
    }

    for (final name in names) {
      final rect = tester.getRect(find.byTooltip(name));
      expect(rect.left, greaterThanOrEqualTo(stackRect.left - 0.01));
      expect(rect.right, lessThanOrEqualTo(stackRect.right + 0.01));
      expect(rect.top, greaterThanOrEqualTo(stackRect.top - 0.01));
      expect(rect.bottom, lessThanOrEqualTo(stackRect.bottom + 0.01),
          reason: 'side avatars used to be clipped by the 96px stack');
    }
  });

  testWidgets('overflow chip stays on the same ring', (tester) async {
    final members = [
      ...fiveMembers,
      const MemberProgress(userId: '6', displayName: 'Farah', eligible: true),
      const MemberProgress(userId: '7', displayName: 'Gul', eligible: true),
      const MemberProgress(userId: '8', displayName: 'Hamza', eligible: true),
      const MemberProgress(userId: '9', displayName: 'Imran', eligible: true),
    ];
    await pumpCircle(tester, members);

    final stackRect = tester.getRect(outerStack());
    final radius = stackRect.width / 2 - 28;
    final chip = find.text('+1');
    expect(chip, findsOneWidget);

    final chipCenter = tester.getCenter(chip);
    expect(
      (chipCenter - stackRect.center).distance,
      moreOrLessEquals(radius, epsilon: 0.5),
    );
    final chipRect = tester.getRect(chip);
    expect(chipRect.left, greaterThanOrEqualTo(stackRect.left - 0.01));
    expect(chipRect.right, lessThanOrEqualTo(stackRect.right + 0.01));
  });
}
