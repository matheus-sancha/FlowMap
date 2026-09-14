import 'package:flowmap/src/features/resources/application/resources_providers.dart';
import 'package:flowmap/src/features/resources/presentation/plant_structure_view.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Plant tab of an empty plant (field report, 2026-09-13).
///
/// Its empty state replaced the whole tree, and the tree is where the add
/// buttons lived — so a new project told the reader to add a workcenter and
/// offered nothing to press.
void main() {
  testWidgets('an empty plant offers both ways in', (tester) async {
    const plantId = 'plant-1';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cellsProvider(plantId).overrideWith((ref) => Stream.value(const [])),
          plantLinesProvider(
            plantId,
          ).overrideWith((ref) => Stream.value(const [])),
          workcentersProvider(
            plantId,
          ).overrideWith((ref) => Stream.value(const [])),
          workcenterLinesProvider(
            plantId,
          ).overrideWith((ref) => Stream.value(const {})),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: PlantStructureView(plantId: plantId)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.resourcesNoWorkcenters), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, l10n.productionCellNew),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, l10n.workcenterNew),
      findsOneWidget,
    );
  });
}
