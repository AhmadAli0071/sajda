import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sajda_dataplus/screens/wrapped_screen.dart';
import 'package:sajda_dataplus/services/sajda_stats_service.dart';
import 'package:sajda_dataplus/state/app_state.dart';
import 'package:sajda_dataplus/state/streak_state.dart';

void main() {
  Future<void> pumpWrapped(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final app = AppState();
    final stats = SajdaStatsService.instance;
    final streak = StreakState();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: app),
        ChangeNotifierProvider<SajdaStatsService>.value(value: stats),
        ChangeNotifierProvider<StreakState>.value(value: streak),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WrappedScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(WrappedScreen), findsOneWidget);
  }

  testWidgets('AppBar back button pops the wrapped screen', (tester) async {
    await pumpWrapped(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(WrappedScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('bottom Back exits on the first card instead of doing nothing',
      (tester) async {
    await pumpWrapped(tester);
    expect(find.text('1/5'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(WrappedScreen), findsNothing,
        reason: 'first card Back must never be a silent no-op');
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('bottom Back goes to the previous card after swiping',
      (tester) async {
    await pumpWrapped(tester);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/5'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('1/5'), findsOneWidget);
    expect(find.byType(WrappedScreen), findsOneWidget,
        reason: 'Back on card 2 shows card 1, it does not leave the screen');
  });

  testWidgets('All-Features flow (pop sheet + push) keeps back working',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final app = AppState();
    final stats = SajdaStatsService.instance;
    final streak = StreakState();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: app),
        ChangeNotifierProvider<SajdaStatsService>.value(value: stats),
        ChangeNotifierProvider<StreakState>.value(value: streak),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                // Mirrors home_screen._showAllFeatures: pop the sheet, then
                // push the feature screen in the same callback.
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (sheetCtx) => Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(sheetCtx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WrappedScreen(),
                          ),
                        );
                      },
                      child: const Text('go wrapped'),
                    ),
                  ),
                ),
                child: const Text('open sheet'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('go wrapped'));
    await tester.pumpAndSettle();
    expect(find.byType(WrappedScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(WrappedScreen), findsNothing);
    expect(find.text('open sheet'), findsOneWidget);
  });
}
