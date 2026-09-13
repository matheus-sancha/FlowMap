import 'package:flowmap/src/app/startup_gate.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The first data load, and what someone sees when it fails (#33).
void main() {
  Widget app(Future<void> Function() open) => ProviderScope(
    overrides: [databaseReadyProvider.overrideWith((ref) => open())],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StartupGate(child: Text('the app')),
    ),
  );

  testWidgets('an open that succeeds shows the app and nothing else', (
    tester,
  ) async {
    await tester.pumpWidget(app(() async {}));
    await tester.pumpAndSettle();
    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets('a quick open shows no waiting sentence at all', (tester) async {
    // An ordinary launch must not flash a sentence nobody can read.
    await tester.pumpWidget(
      app(() => Future.delayed(const Duration(milliseconds: 200))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Opening your data…'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets('a slow open says what is happening', (tester) async {
    await tester.pumpWidget(
      app(() => Future.delayed(const Duration(seconds: 5))),
    );
    await tester.pump(StartupGate.quietFor + const Duration(milliseconds: 50));
    expect(find.text('Opening your data…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('the app'), findsOneWidget);
  });

  testWidgets('a failed open says what to do, not what went wrong', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(() async => throw StateError('SqliteException(11): malformed')),
    );
    await tester.pumpAndSettle();

    expect(find.text('the app'), findsNothing);
    expect(find.text('FlowMap could not open its data'), findsOneWidget);
    expect(find.text('Copy details'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    // The exception is behind Copy details, never on the screen.
    expect(find.textContaining('SqliteException'), findsNothing);
  });
}
