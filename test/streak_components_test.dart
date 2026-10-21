import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sajda_dataplus/models/streak_v2.dart';
import 'package:sajda_dataplus/state/app_state.dart';
import 'package:sajda_dataplus/widgets/streak/streak_components.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: AppState(),
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
  }

  ActivityItem item(String type) => ActivityItem(
        id: 'a1',
        groupId: 'g1',
        userId: 'u1',
        displayName: 'Aisha',
        type: type,
        createdAt: DateTime(2026, 10, 19, 12),
      );

  group('ActivityRow', () {
    testWidgets('shield activity reads as a sentence', (tester) async {
      await pump(tester, ActivityRow(item: item('group_shield_used')));
      expect(find.textContaining('Shield saved the group day'), findsOneWidget);
      expect(find.textContaining('group_shield_used'), findsNothing);
    });

    testWidgets('archived activity reads as a sentence', (tester) async {
      await pump(tester, ActivityRow(item: item('group_archived')));
      expect(find.textContaining('Group archived'), findsOneWidget);
      expect(find.textContaining('group_archived'), findsNothing);
    });

    testWidgets('unknown types never leak raw snake_case', (tester) async {
      await pump(tester, ActivityRow(item: item('some_new_event')));
      expect(find.textContaining('Group activity'), findsOneWidget);
      expect(find.textContaining('some_new_event'), findsNothing);
    });

    testWidgets('group name suffix is appended when provided', (tester) async {
      await pump(
        tester,
        ActivityRow(item: item('group_shield_used'), groupName: ' · Testers'),
      );
      expect(find.textContaining('Shield saved the group day · Testers'),
          findsOneWidget);
    });
  });

  group('MemberProgressRow badges', () {
    testWidgets('ghost members show only the inactive badge', (tester) async {
      await pump(
        tester,
        const MemberProgressRow(
          member: MemberProgress(
            userId: 'u2',
            displayName: 'Ghost',
            eligible: true,
            isRequiredToday: false,
            excludedInactive: true,
          ),
        ),
      );
      expect(find.text('inactive'), findsOneWidget);
      expect(find.text('from tomorrow'), findsNothing);
    });

    testWidgets('brand-new joiners keep the from-tomorrow badge',
        (tester) async {
      await pump(
        tester,
        const MemberProgressRow(
          member: MemberProgress(
            userId: 'u3',
            displayName: 'Newbie',
            eligible: true,
            isRequiredToday: false,
          ),
        ),
      );
      expect(find.text('from tomorrow'), findsOneWidget);
      expect(find.text('inactive'), findsNothing);
    });
  });
}
