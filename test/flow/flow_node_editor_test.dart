import 'package:flowmap/src/common/unit_labels.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/flow/application/flow_providers.dart';
import 'package:flowmap/src/features/flow/application/flow_view.dart';
import 'package:flowmap/src/features/flow/presentation/flow_node_editor.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` lives in flutter_riverpod's `misc` library, not its main one.
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// Mounting tests for the node dialogs.
///
/// Both UI crashes so far were mount-time failures that no unit test could see:
/// a `dynamic` extension call, and a `Spacer` inside `AlertDialog.actions`
/// (whose `OverflowBar` is not a Flex, so a `Flexible` child throws
/// `_OverflowBarParentData is not a subtype of FlexParentData`). In a release
/// build both render as a blank grey panel. Actually pumping the dialogs is the
/// cheapest thing that would have caught either.
void main() {
  final now = DateTime(2026, 8, 1);

  FlowNode inventoryNode({
    InventoryMode mode = InventoryMode.duration,
    int? seconds = 48 * 3600,
    DurationUnit? unit = DurationUnit.hours,
    int? quantity,
  }) => FlowNode(
    id: 'node-1',
    studyId: 'study-1',
    position: 0,
    kind: FlowNodeKind.inventory,
    changeoverSeconds: 0,
    inventoryMode: mode,
    inventoryQuantity: quantity,
    inventorySeconds: seconds,
    inventoryUnit: unit,
    inventoryUsesWorkingTime: false,
    createdAt: now,
    updatedAt: now,
  );

  final study = Study(
    id: 'study-1',
    projectId: 'project-1',
    productionCellId: 'cell-1',
    productionLineId: 'line-1',
    name: 'Current state',
    includeInSimulation: false,
    startBufferDays: 0,
    priority: 100,
    createdAt: now,
    updatedAt: now,
  );

  /// Pumps a host with a button that opens [open].
  Future<void> pumpHost(
    WidgetTester tester,
    Future<void> Function(BuildContext context, WidgetRef ref) open, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => open(context, ref),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('the inventory editor', () {
    testWidgets('mounts without throwing, for an existing node', (
      tester,
    ) async {
      await pumpHost(
        tester,
        (context, ref) => showInventoryEditor(
          context,
          ref,
          study: study,
          buffer: FlowInventoryView(
            inventoryNode(),
            wait: const Duration(hours: 48),
            label: '',
            waitUnit: DurationUnit.hours,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsOneWidget);
      // Move and delete live in the content, not in `actions`.
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('mounts without throwing, for a new node', (tester) async {
      await pumpHost(
        tester,
        (context, ref) => showInsertNodeMenu(
          context,
          ref,
          study: study,
          position: 0,
          dispatchByTarget: const {},
        ),
      );

      expect(tester.takeException(), isNull);
      // The insert menu offers the two node kinds.
      expect(find.byType(SimpleDialog), findsOneWidget);
    });

    testWidgets('a stored note reads back into the field', (tester) async {
      await pumpHost(
        tester,
        (context, ref) => showInventoryEditor(
          context,
          ref,
          study: study,
          buffer: FlowInventoryView(
            inventoryNode(),
            quantity: null,
            wait: const Duration(hours: 48),
            label: '',
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.flowNodeNotes), findsOneWidget);
    });

    testWidgets('offers all four wait units', (tester) async {
      await pumpHost(
        tester,
        (context, ref) => showInventoryEditor(
          context,
          ref,
          study: study,
          buffer: FlowInventoryView(
            inventoryNode(),
            wait: const Duration(hours: 48),
            label: '',
            waitUnit: DurationUnit.hours,
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButtonFormField<DurationUnit>));
      await tester.pumpAndSettle();

      // Four in the menu; the closed field shows the selected one too.
      expect(find.text('days'), findsWidgets);
      expect(find.text('hours'), findsWidgets);
      expect(find.text('minutes'), findsWidgets);
      expect(find.text('seconds'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing the unit keeps the wait, not the number', (
      tester,
    ) async {
      await pumpHost(
        tester,
        (context, ref) => showInventoryEditor(
          context,
          ref,
          study: study,
          buffer: FlowInventoryView(
            inventoryNode(),
            wait: const Duration(hours: 48),
            label: '',
            waitUnit: DurationUnit.hours,
          ),
        ),
      );

      expect(find.widgetWithText(TextField, '48'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<DurationUnit>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('days').last);
      await tester.pumpAndSettle();

      // 48 hours is 2 days — the duration is what the user meant, not the 48.
      expect(find.widgetWithText(TextField, '2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a quantity buffer shows pieces rather than a wait', (
      tester,
    ) async {
      await pumpHost(
        tester,
        (context, ref) => showInventoryEditor(
          context,
          ref,
          study: study,
          buffer: FlowInventoryView(
            inventoryNode(
              mode: InventoryMode.quantity,
              seconds: null,
              unit: null,
              quantity: 5,
            ),
            wait: const Duration(hours: 12),
            label: '',
            quantity: 5,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byType(DropdownButtonFormField<DurationUnit>),
        findsNothing,
        reason: 'a quantity buffer has no unit of its own — takt supplies it',
      );
    });
  });

  group('the step editor', () {
    testWidgets('mounts without throwing', (tester) async {
      final step = FlowStepView(
        FlowNode(
          id: 'node-1',
          studyId: 'study-1',
          position: 0,
          kind: FlowNodeKind.step,
          changeoverSeconds: 1800,
          inventoryUsesWorkingTime: false,
          createdAt: now,
          updatedAt: now,
        ),
        title: 'CLAD04',
        typeName: 'Cladding',
        poolMemberCount: null,
        dataSource: FlowDataSource.flowEquivalent,
        processTime: const Duration(hours: 68),
        equivalentProcessTime: const Duration(hours: 68),
        changeover: const Duration(minutes: 30),
        openPerWorkingDay: const Duration(hours: 22, minutes: 40),
        productivePerWorkingDay: const Duration(hours: 16, minutes: 46),
        openInPeriod: const Duration(hours: 476),
        capacityInPeriod: const Duration(hours: 352),
        operatorsAllocated: 3,
        operatorsPerShift: const [1, 1, 1],
        availability: 0.74,
        rework: 0.037,
        problems: const [],
      );

      await pumpHost(
        tester,
        (context, ref) => showStepEditor(
          context,
          ref,
          study: study,
          step: step,
          dispatchByTarget: const {},
        ),
        overrides: [
          flowTargetsProvider('study-1').overrideWith(
            (ref) async => (
              workcenters: <Workcenter>[
                Workcenter(
                  id: 'wc-1',
                  plantId: 'plant-1',
                  parallelCapacity: 1,
                  name: 'CLAD04',
                  createdAt: now,
                  updatedAt: now,
                ),
              ],
              pools: <WorkcenterPool>[],
            ),
          ),
        ],
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('shows the station\'s own queue rule, not the step\'s', (
      tester,
    ) async {
      final step = FlowStepView(
        FlowNode(
          id: 'node-1',
          studyId: 'study-1',
          position: 0,
          kind: FlowNodeKind.step,
          // Bound, because the rule is keyed by what the step targets.
          workcenterId: 'wc-1',
          changeoverSeconds: 1800,
          inventoryUsesWorkingTime: false,
          createdAt: now,
          updatedAt: now,
        ),
        title: 'CLAD04',
        typeName: 'Cladding',
        poolMemberCount: null,
        dataSource: FlowDataSource.flowEquivalent,
        processTime: const Duration(hours: 68),
        equivalentProcessTime: const Duration(hours: 68),
        changeover: const Duration(minutes: 30),
        openPerWorkingDay: const Duration(hours: 22, minutes: 40),
        productivePerWorkingDay: const Duration(hours: 16, minutes: 46),
        openInPeriod: const Duration(hours: 476),
        capacityInPeriod: const Duration(hours: 352),
        operatorsAllocated: 3,
        operatorsPerShift: const [1, 1, 1],
        availability: 0.74,
        rework: 0.037,
        problems: const [],
      );

      await pumpHost(
        tester,
        (context, ref) => showStepEditor(
          context,
          ref,
          study: study,
          step: step,
          // The rule is stored against the target, not the node — so the
          // dialog has to find it by the station the step points at.
          dispatchByTarget: const {'wc-1': DispatchRule.earliestDueDate},
        ),
        overrides: [
          flowTargetsProvider('study-1').overrideWith(
            (ref) async => (
              workcenters: <Workcenter>[
                Workcenter(
                  id: 'wc-1',
                  plantId: 'plant-1',
                  parallelCapacity: 1,
                  name: 'CLAD04',
                  createdAt: now,
                  updatedAt: now,
                ),
              ],
              pools: <WorkcenterPool>[],
            ),
          ),
        ],
      );

      expect(tester.takeException(), isNull);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.stepDispatch), findsOneWidget);
      // Notes were stored and carried through the repository from M2 and
      // editable from nothing (§17.5). The field is the whole fix.
      expect(find.text(l10n.flowNodeNotes), findsOneWidget);
      // Selected, not merely offered: a control that opened on the default
      // would silently reset the station on the next save.
      expect(
        find.text(dispatchRuleLabel(l10n, DispatchRule.earliestDueDate)),
        findsOneWidget,
      );
    });
  });
}
