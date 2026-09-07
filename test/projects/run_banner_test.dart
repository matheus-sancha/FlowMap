import 'package:flowmap/src/features/projects/presentation/project_workspace_screen.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the last run says, until it is dismissed (DESIGN.md §12.1).
///
/// The banner rather than the workspace around it: mounting that needs a
/// project, a study list and a database, and none of it bears on the two rules
/// under test.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool failed,
    VoidCallback? onViewResults,
    VoidCallback? onDismiss,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RunBanner(
          outcome: (
            message: failed ? 'Simulation failed' : 'On-time delivery: 3%',
            failed: failed,
          ),
          onViewResults: onViewResults ?? () {},
          onDismiss: onDismiss ?? () {},
        ),
      ),
    ),
  );

  testWidgets('a finished run offers the headline and a way to the rest', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    await pump(tester, failed: false);

    expect(find.text('On-time delivery: 3%'), findsOne);
    expect(find.text('Simulation Results'), findsOne);
    expect(find.text('Close'), findsOne);
  });

  testWidgets('a failed run offers no results to view', (tester) async {
    // There is no run to look at, so a button promising one would be a lie.
    await pump(tester, failed: true);

    expect(find.text('Simulation failed'), findsOne);
    expect(find.text('Simulation Results'), findsNothing);
    // Still dismissible: a bar that cannot be got rid of is worse than the
    // snackbar this replaced, which at least went away on its own.
    expect(find.text('Close'), findsOne);
  });

  testWidgets('both actions are wired', (tester) async {
    var viewed = 0;
    var dismissed = 0;
    await pump(
      tester,
      failed: false,
      onViewResults: () => viewed++,
      onDismiss: () => dismissed++,
    );

    await tester.tap(find.text('Simulation Results'));
    await tester.pump();
    expect(viewed, 1);

    await tester.tap(find.text('Close'));
    await tester.pump();
    expect(dismissed, 1);
  });

  testWidgets('it pushes content down rather than covering it', (tester) async {
    // The whole reason this is a banner and not a snackbar: since the Gantt
    // took the full body height (§8.6), a bar that never goes away would park
    // permanently over the last station's row.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              RunBanner(
                outcome: (message: 'On-time delivery: 3%', failed: false),
                onViewResults: () {},
                onDismiss: () {},
              ),
              const Expanded(child: Placeholder(key: ValueKey('workspace'))),
            ],
          ),
        ),
      ),
    );

    final banner = tester.getRect(find.byType(MaterialBanner));
    final workspace = tester.getRect(find.byKey(const ValueKey('workspace')));
    expect(workspace.top, greaterThanOrEqualTo(banner.bottom));
  });
}
