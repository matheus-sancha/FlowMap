import 'package:flowmap/src/app/app_scale.dart';
import 'package:flowmap/src/app/app_scale_button.dart';
import 'package:flowmap/src/app/app_scale_setting.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The one control for the app-wide scale (#51).
///
/// **The reachability rule is the load-bearing one here.** There is no keyboard
/// shortcut and no Settings row, so if this hides itself at 100 % the scale
/// becomes unreachable and the feature is gone. That is asserted directly,
/// because "tidy up the chrome when nothing is set" is exactly the change
/// someone would make later in good faith.
void main() {
  Widget harness({double initial = AppScale.noScale}) => ProviderScope(
    overrides: [initialAppScaleProvider.overrideWithValue(initial)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: Align(child: AppScaleButton())),
    ),
  );

  /// The scale the app is actually running at, read the way `app.dart` reads it.
  double scaleOf(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(AppScaleButton)),
  ).read(appScaleSettingProvider);

  testWidgets('shows the current scale, and shows it at 100 %', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Not hidden when nothing is set: this is the only way back.
    expect(find.byType(AppScaleButton), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('shows a scale that is not the identity', (tester) async {
    await tester.pumpWidget(harness(initial: 0.8));
    await tester.pumpAndSettle();
    expect(find.text('80%'), findsOneWidget);
  });

  testWidgets('offers every step, and no Reset', (tester) async {
    await tester.pumpWidget(harness(initial: 0.8));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    for (final step in AppScale.steps) {
      final label = '${(step * 100).round()}%';
      expect(
        find.text(label),
        findsWidgets,
        reason: '$label is missing from the menu',
      );
    }

    // 100 % is a step, which is what makes a Reset item redundant (#49).
    expect(find.text('100%'), findsWidgets);
    expect(find.textContaining(RegExp('reset', caseSensitive: false)), findsNothing);
  });

  testWidgets('picking a step moves the app and closes the menu', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    expect(scaleOf(tester), AppScale.noScale);

    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    // The menu's 70 %, not the button's label — the button reads 100 % here.
    await tester.tap(find.text('70%').last);
    await tester.pumpAndSettle();

    expect(scaleOf(tester), 0.7);
    // And the button now reads what was picked.
    expect(find.text('70%'), findsOneWidget);
  });

  testWidgets('the current step is ticked', (tester) async {
    await tester.pumpWidget(harness(initial: 0.9));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();

    // Exactly one, or the tick is telling the reader something untrue.
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
