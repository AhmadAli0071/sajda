import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sajda_dataplus/screens/card_studio_screen.dart';
import 'package:sajda_dataplus/screens/wrapped_screen.dart';
import 'package:sajda_dataplus/services/sajda_stats_service.dart';
import 'package:sajda_dataplus/state/app_state.dart';
import 'package:sajda_dataplus/state/streak_state.dart';

void main() {
  Future<void> setScale(WidgetTester tester, double scale) async {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(960, 2000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Widget appWith(Widget home, List<ChangeNotifierProvider<dynamic>> providers) {
    return MultiProvider(
      providers: providers,
      child: MaterialApp(
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.25,
          child: child ?? const SizedBox.shrink(),
        ),
        home: home,
      ),
    );
  }

  for (final urdu in [false, true]) {
    final suffix = urdu ? ' (Urdu)' : '';

    testWidgets(
      'card studio: no overflow at max font scale + Next works$suffix',
      (tester) async {
        await setScale(tester, 2.0);
        SharedPreferences.setMockInitialValues({});
        final app = AppState();
        if (urdu) await app.setLanguage('ur');

        await tester.pumpWidget(
          appWith(const CardStudioScreen(), [
            ChangeNotifierProvider<AppState>.value(value: app),
          ]),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(urdu ? 'قرآن 13:28' : 'Quran 13:28'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.byIcon(Icons.shuffle_rounded),
          300,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.byIcon(Icons.shuffle_rounded));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(urdu ? 'قرآن 94:5' : 'Quran 94:5'), findsOneWidget);
      },
    );

    testWidgets(
      'wrapped: no overflow at max font scale + buttons work$suffix',
      (tester) async {
        await setScale(tester, 2.0);
        SharedPreferences.setMockInitialValues({});
        final app = AppState();
        if (urdu) await app.setLanguage('ur');
        final stats = SajdaStatsService.instance;
        final streak = StreakState();

        await tester.pumpWidget(
          appWith(const WrappedScreen(), [
            ChangeNotifierProvider<AppState>.value(value: app),
            ChangeNotifierProvider<SajdaStatsService>.value(value: stats),
            ChangeNotifierProvider<StreakState>.value(value: streak),
          ]),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pumpAndSettle();
        expect(find.text('2/5'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byIcon(Icons.chevron_left_rounded));
        await tester.pumpAndSettle();
        expect(find.text('1/5'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byIcon(Icons.ios_share_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Share Image'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Share Image'), findsNothing);
      },
    );
  }
}
