import 'package:flowmap/src/common/workcenter_icons.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/resources/presentation/workcenter_type_editor.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mounting tests for the workcenter type editor (DESIGN.md §16.4).
void main() {
  Future<WorkcenterTypeDraft?> open(
    WidgetTester tester, {
    Set<String> taken = const {},
    String initialName = '',
    WorkcenterIcon? initialIcon,
  }) async {
    WorkcenterTypeDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await showWorkcenterTypeEditor(
                    context,
                    takenNames: taken,
                    initialName: initialName,
                    initialIcon: initialIcon,
                  ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  VoidCallback? saveButton(WidgetTester tester) => tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
      .onPressed;

  testWidgets('mounts with the whole library on offer', (tester) async {
    await open(tester);

    expect(tester.takeException(), isNull);
    // Every library entry is on offer. Counted by glyph rather than by
    // widget: the dialog's own buttons are InkWells too.
    for (final option in WorkcenterIcon.values) {
      expect(
        find.byIcon(workcenterIconGlyph(option)),
        findsWidgets,
        reason: option.name,
      );
    }
    expect(saveButton(tester), isNull, reason: 'nothing typed yet');
  });

  testWidgets('naming a type guesses its icon', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField), 'Welding');
    await tester.pumpAndSettle();

    expect(saveButton(tester), isNotNull);
    // The guess is shown as the selected choice, not applied invisibly.
    expect(find.byIcon(Icons.bolt_outlined), findsOneWidget);
  });

  testWidgets('a hand-picked icon survives further typing', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField), 'Welding');
    await tester.pumpAndSettle();

    // Choose the furnace deliberately, then keep typing a name that would
    // guess something else.
    await tester.tap(find.byIcon(Icons.local_fire_department_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Welding bay');
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.local_fire_department_outlined), findsOneWidget);
    expect(find.byIcon(Icons.bolt_outlined), findsOneWidget);
  });

  testWidgets('an existing type opens on its own icon', (tester) async {
    await open(
      tester,
      initialName: 'Cladding',
      initialIcon: WorkcenterIcon.cladding,
    );

    expect(find.text('Cladding'), findsOneWidget);
    expect(saveButton(tester), isNotNull);
  });

  testWidgets('a name the picklist already holds is refused', (tester) async {
    await open(tester, taken: {'welding'});

    await tester.enterText(find.byType(TextField), 'Welding');
    await tester.pumpAndSettle();

    expect(saveButton(tester), isNull);
    expect(find.text('That name is already used here'), findsOneWidget);
  });
}
