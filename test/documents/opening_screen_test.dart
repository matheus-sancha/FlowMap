import 'dart:async';

import 'package:flowmap/src/features/documents/presentation/opening_screen.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opening a project says so, and covers the window while it happens.
void main() {
  testWidgets('the opening screen stands for exactly as long as the work', (
    tester,
  ) async {
    final work = Completer<String>();
    late Future<String> result;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = whileOpening(
                context,
                'Plan Q1',
                () => work.future,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(l10n.documentsOpening('Plan Q1')), findsOneWidget);

    work.complete('done');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(l10n.documentsOpening('Plan Q1')), findsNothing);
    expect(await result, 'done');
  });

  testWidgets('a failure takes the screen down too', (tester) async {
    final work = Completer<void>();
    Object? caught;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => whileOpening(
                context,
                'Broken',
                () => work.future,
              ).catchError((Object e) => caught = e),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 200));
    work.completeError(StateError('unreadable'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(l10n.documentsOpening('Broken')), findsNothing);
    expect(caught, isA<StateError>());
  });
}
