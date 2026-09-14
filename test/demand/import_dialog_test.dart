import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/demand/application/demand_import.dart';
import 'package:flowmap/src/features/demand/application/demand_table.dart';
import 'package:flowmap/src/features/demand/data/import_reader.dart';
import 'package:flowmap/src/features/demand/presentation/import_dialog.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mounting tests for the import dialog (DESIGN.md §16.4).
///
/// The mapping rows are built from localized column names, which is exactly
/// the sort of thing that reads an inherited widget too early and shows a blank
/// grey panel in a release build. What the mapping *means* is tested in
/// `demand_import_test.dart`; this proves the dialog draws.
void main() {
  final now = DateTime(2026, 8, 1);

  final study = Study(
    id: 'study-1',
    projectId: 'project-1',
    productionCellId: 'cell-1',
    productionLineId: 'line-1',
    name: 'Current state',
    includeInSimulation: false,
    startBufferDays: 0,
    createdAt: now,
    updatedAt: now,
  );

  final table = DemandTable(
    parts: [
      DemandPart(
        id: 'p1',
        studyId: 'study-1',
        partNumber: 'PN1',
        createdAt: now,
        updatedAt: now,
      ),
    ],
    columns: const [
      DemandColumn(nodeId: 'node-0', targetId: 'wc-1', title: 'CLAD04'),
      DemandColumn(nodeId: 'node-1', targetId: 'wc-2', title: 'TTAT'),
    ],
    times: const {},
  );

  Future<void> pump(
    WidgetTester tester, {
    required ImportTarget target,
    required List<List<String>> rows,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DemandImportDialog(
              study: study,
              table: table,
              target: target,
              fileName: 'demand.csv',
              sheets: [ImportSheet(name: 'demand.csv', rows: rows)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the parts dialog mounts and guesses its mapping', (
    tester,
  ) async {
    await pump(
      tester,
      target: ImportTarget.parts,
      rows: [
        ['Part number', 'Description', 'CLAD04', 'TTAT'],
        ['PN1', 'Housing', '55:00:00', '3:00:00'],
        ['PN2', 'Cover', '8:00:00', ''],
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Import from demand.csv'), findsOneWidget);
    // Every column matched, so both rows are ready and Import is live.
    expect(find.text('2 rows ready'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Import 2 Rows'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('a required column with nothing mapped blocks the import', (
    tester,
  ) async {
    await pump(
      tester,
      target: ImportTarget.parts,
      rows: [
        ['mystery a', 'mystery b'],
        ['PN1', '55:00:00'],
      ],
    );

    expect(tester.takeException(), isNull);
    // Nothing is written until the user has said which column is the part
    // number — guessing by position would import the wrong data quietly.
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.text('Required'), findsWidgets);
  });

  testWidgets('the preview names the rows that will be skipped', (
    tester,
  ) async {
    await pump(
      tester,
      target: ImportTarget.sequence,
      rows: [
        ['Part number', 'Batch', 'Need date', 'Material date'],
        ['PN1', '1', '2026-08-13', ''],
        ['PN404', '1', '2026-08-13', ''],
        ['PN1', '1', 'soon', ''],
      ],
    );

    expect(tester.takeException(), isNull);
    expect(find.text('1 rows ready'), findsOneWidget);
    expect(find.text('2 skipped'), findsOneWidget);
    expect(find.textContaining('No part with that number'), findsOneWidget);
    // Worst first, and by the line number the user sees in their own file.
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('a need date before its material is a warning, not a skip', (
    tester,
  ) async {
    await pump(
      tester,
      target: ImportTarget.sequence,
      rows: [
        ['Part number', 'Need date', 'Material date'],
        ['PN1', '2026-08-01', '2026-08-10'],
      ],
    );

    expect(find.text('1 rows ready'), findsOneWidget);
    expect(find.text('1 to look at'), findsOneWidget);
    expect(
      find.textContaining('Needed before its material arrives'),
      findsOneWidget,
    );
  });
}
