import 'package:flowmap/src/common/dialogs.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/resources/data/resources_repository.dart';
import 'package:flowmap/src/features/resources/presentation/workcenter_editor.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every dialog that takes a name has to enable Save as the name is typed.
///
/// Reported from the field: "I'm only able to save by pressing enter." A button
/// whose enabled state is read from a `TextEditingController` does not rebuild
/// when that controller changes — the controller is a `ValueListenable`, and
/// nothing was listening. Typing looked like it did nothing, and the only way
/// out was the `onSubmitted` path.
///
/// One test per dialog, because the fault is per-dialog and a shared helper
/// would only prove the helper.
void main() {
  final now = DateTime(2026, 8, 1);

  Future<void> pump(WidgetTester tester, Widget Function() open) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Builder(builder: (context) => open())),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The Save button's `onPressed`, or null when it is disabled.
  VoidCallback? saveButton(WidgetTester tester) => tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
      .onPressed;

  group('promptForName', () {
    // Plants, production cells, production lines, pools and workcenter types
    // all go through this one dialog, so all five were broken together.
    Future<void> open(WidgetTester tester, {String? Function(String)? validate}) {
      return pump(tester, () {
        return Builder(
          builder: (context) => TextButton(
            onPressed: () => promptForName(
              context,
              title: 'New production line',
              label: 'Name',
              validate: validate,
            ),
            child: const Text('open'),
          ),
        );
      });
    }

    testWidgets('Save enables as soon as a name is typed', (tester) async {
      await open(tester);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(saveButton(tester), isNull, reason: 'nothing typed yet');

      await tester.enterText(find.byType(TextField), 'Line 1');
      await tester.pumpAndSettle();

      expect(saveButton(tester), isNotNull);
    });

    testWidgets('Save writes the name through', (tester) async {
      String? saved;
      await pump(
        tester,
        () => Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                saved = await promptForName(
                  context,
                  title: 'New production line',
                  label: 'Name',
                ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Line 1');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(saved, 'Line 1');
    });

    testWidgets('Save stays disabled while the name is refused', (
      tester,
    ) async {
      await open(
        tester,
        validate: (value) => value == 'Line 1' ? 'Taken' : null,
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Line 1');
      await tester.pumpAndSettle();
      expect(saveButton(tester), isNull);
      expect(find.text('Taken'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Line 2');
      await tester.pumpAndSettle();
      expect(saveButton(tester), isNotNull);
    });

    testWidgets('a name of nothing but spaces does not enable Save', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();
      expect(saveButton(tester), isNull);
    });
  });

  group('the workcenter editor', () {
    Future<void> open(WidgetTester tester, {Set<String> taken = const {}}) {
      return pump(
        tester,
        () => Builder(
          builder: (context) => TextButton(
            onPressed: () => showWorkcenterEditor(
              context,
              lines: [
                PlantLine(
                  cell: ProductionCell(
                    id: 'cell-1',
                    plantId: 'plant-1',
                    name: 'Cell A',
                    createdAt: now,
                    updatedAt: now,
                  ),
                  line: ProductionLine(
                    id: 'line-1',
                    cellId: 'cell-1',
                    name: 'Line 1',
                    createdAt: now,
                    updatedAt: now,
                  ),
                ),
              ],
              types: [
                WorkcenterType(
                  id: 'type-1',
                  name: 'Cladding',
                  isBuiltIn: true,
                  createdAt: now,
                ),
              ],
              takenNames: taken,
            ),
            child: const Text('open'),
          ),
        ),
      );
    }

    /// The first field in the dialog. Named rather than taken as "the"
    /// TextField, because the units field (§3.1) is a second one — and a
    /// finder that breaks when a field is added was never asserting anything
    /// about which field it meant.
    final nameField = find.byType(TextField).first;

    testWidgets('Save enables as soon as a name is typed', (tester) async {
      await open(tester);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(saveButton(tester), isNull);

      await tester.enterText(nameField, 'CLAD04');
      await tester.pumpAndSettle();

      expect(saveButton(tester), isNotNull);
    });

    testWidgets('Enter saves too, without reaching for the mouse', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(nameField, 'CLAD04');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a name the plant already carries is refused', (tester) async {
      await open(tester, taken: {'clad04'});
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(nameField, 'CLAD04');
      await tester.pumpAndSettle();

      expect(saveButton(tester), isNull);
    });

    testWidgets('the name help wraps rather than being cut', (tester) async {
      await open(tester);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Reported from the field: the sentence under the name field was clipped
      // at one line. `helperMaxLines` has to be set, since the default is 1
      // however long the string is.
      final helper = tester.widget<TextField>(find.byType(TextField).first);
      expect(helper.decoration?.helperMaxLines, greaterThan(1));
      expect(tester.takeException(), isNull);
    });
  });
}
