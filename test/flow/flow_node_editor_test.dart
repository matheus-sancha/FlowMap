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
import 'package:flowmap/src/common/unit_labels.dart';
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

  FlowQueueView queueView({
    String? name,
    DispatchRule? rule,
    int? capacity,
    Duration wait = const Duration(hours: 48),
    DurationUnit? unit = DurationUnit.hours,
    int? quantity,
  }) => FlowQueueView(
    targetId: 'CLAD04',
    targetName: 'CLAD04',
    name: name,
    rule: rule,
    capacity: capacity,
    wait: wait,
    quantity: quantity,
    unit: unit,
    isCalendarWait: quantity == null,
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

  group('the queue editor (§7.3)', () {
    testWidgets('mounts without throwing, and names its target', (
      tester,
    ) async {
      await pumpHost(
        tester,
        (context, ref) => showQueueEditor(
          context,
          ref,
          projectId: 'project-1',
          queue: queueView(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsOneWidget);
      // Move and delete are a *node's* actions; a queue is not on the spine and
      // cannot be reordered off it.
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.flowQueueTitle('CLAD04')), findsOneWidget);
      // Said out loud, because a planner editing this from inside one study has
      // to know the other study's orders stand in the same line.
      expect(find.text(l10n.flowQueueShared('CLAD04')), findsOneWidget);
    });

    testWidgets('inserting a node offers a step, with no menu in the way', (
      tester,
    ) async {
      await pumpHost(
        tester,
        (context, ref) =>
            showInsertNodeMenu(context, ref, study: study, position: 0),
        overrides: [
          // It reaches straight for the targets now rather than asking which
          // kind of node first, so the provider it reads has to be stubbed.
          flowTargetsProvider('study-1').overrideWith(
            (ref) async => (
              workcenters: <Workcenter>[],
              pools: <WorkcenterPool>[],
            ),
          ),
        ],
      );

      expect(tester.takeException(), isNull);
      // One thing goes on the spine now (§7.3), so the choice dialog went with
      // the inventory node and the step dialog opens directly.
      expect(find.byType(SimpleDialog), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('offers all four wait units', (tester) async {
      await pumpHost(
        tester,
        (context, ref) => showQueueEditor(
          context,
          ref,
          projectId: 'project-1',
          queue: queueView(),
        ),
      );

      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<DurationUnit>),
      );
      await tester.pumpAndSettle();
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
        (context, ref) => showQueueEditor(
          context,
          ref,
          projectId: 'project-1',
          queue: queueView(),
        ),
      );

      expect(find.widgetWithText(TextField, '48'), findsOneWidget);

      await tester.ensureVisible(
        find.byType(DropdownButtonFormField<DurationUnit>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<DurationUnit>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('days').last);
      await tester.pumpAndSettle();

      // 48 hours is 2 days — the duration is what the user meant, not the 48.
      expect(find.widgetWithText(TextField, '2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('it carries the name, rule and capacity it was given', (
      tester,
    ) async {
      await pumpHost(
        tester,
        (context, ref) => showQueueEditor(
          context,
          ref,
          projectId: 'project-1',
          queue: queueView(
            name: 'FIFO CEU27',
            rule: DispatchRule.earliestDueDate,
            capacity: 3,
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // Selected rather than merely offered: a control that opened on the
      // default would silently reset the queue on the next save (§7.3).
      expect(
        find.text(dispatchRuleLabel(l10n, DispatchRule.earliestDueDate)),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextField, 'FIFO CEU27'), findsOneWidget);
      expect(find.widgetWithText(TextField, '3'), findsOneWidget);
    });

    testWidgets('an untouched queue says it is a push, not FIFO', (
      tester,
    ) async {
      await pumpHost(
        tester,
        (context, ref) => showQueueEditor(
          context,
          ref,
          projectId: 'project-1',
          queue: queueView(),
        ),
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // The distinction §5.2 rests on: "nobody has decided" is not the same
      // state as "someone chose FIFO", and only the second draws a channel.
      expect(find.text(l10n.queueTypePush), findsOneWidget);
      expect(find.text(l10n.laneCapacity), findsOneWidget);
    });

    testWidgets('supermarket is named and cannot be chosen', (tester) async {
      await pumpHost(
        tester,
        (context, ref) => showQueueEditor(
          context,
          ref,
          projectId: 'project-1',
          queue: queueView(),
        ),
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // Opened through the entry it is showing, because the picker's own type
      // is private to the dialog.
      await tester.tap(find.text(l10n.queueTypePush));
      await tester.pumpAndSettle();

      // Listed rather than omitted, so a reader looking for it finds out why it
      // is not there: the engine cannot honour it, and a supermarket symbol
      // over FIFO behaviour would be a map that lies about the plant (§7.3).
      expect(find.text(l10n.queueTypeSupermarket), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a queue holding pieces shows a count rather than a wait', (
      tester,
    ) async {
      await pumpHost(
        tester,
        (context, ref) => showQueueEditor(
          context,
          ref,
          projectId: 'project-1',
          queue: queueView(
            quantity: 5,
            unit: null,
            wait: const Duration(hours: 12),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byType(DropdownButtonFormField<DurationUnit>),
        findsNothing,
        reason: 'a quantity has no unit of its own — takt supplies it',
      );
    });
  });

  group('the step editor', () {
    FlowStepView stepView({
      double? setupValue,
      double? teardownValue,
      double? samePartPercent,
    }) => FlowStepView(
        FlowNode(
          id: 'node-1',
          studyId: 'study-1',
          position: 0,
          kind: FlowNodeKind.step,
          changeoverSeconds: 0,
          setupValue: setupValue,
          setupUnit: setupValue == null ? null : TaktUnit.minutes,
          teardownValue: teardownValue,
          teardownUnit: teardownValue == null ? null : TaktUnit.minutes,
          samePartPercent: samePartPercent,
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

    Future<void> open(WidgetTester tester, FlowStepView step) => pumpHost(
        tester,
        (context, ref) => showStepEditor(
          context,
          ref,
          study: study,
          step: step,
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

    testWidgets('mounts without throwing', (tester) async {
      await open(tester, stepView(setupValue: 30));

      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('a stored setup and teardown read back into their fields', (
      tester,
    ) async {
      await open(tester, stepView(setupValue: 30, teardownValue: 10));

      expect(find.widgetWithText(TextField, '30'), findsOneWidget);
      expect(find.widgetWithText(TextField, '10'), findsOneWidget);
    });

    testWidgets('the same-part percentage appears only with a changeover', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // A step with neither half shows the five fields it always showed. That
      // is what "optional for the user" has to mean on a dialog that already
      // scrolls at the app's minimum window height.
      await open(tester, stepView());
      expect(find.text(l10n.stepSamePart), findsNothing);

      // Typing a setup reveals it, because now there is something for it to
      // modify.
      await tester.enterText(
        find.widgetWithText(TextField, l10n.stepSetup),
        '45',
      );
      await tester.pump();
      expect(find.text(l10n.stepSamePart), findsOneWidget);
    });

    testWidgets('a stored percentage comes back with its changeover', (
      tester,
    ) async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await open(tester, stepView(setupValue: 30, samePartPercent: 25));

      expect(find.text(l10n.stepSamePart), findsOneWidget);
      expect(find.widgetWithText(TextField, '25'), findsOneWidget);
    });
  });
}
