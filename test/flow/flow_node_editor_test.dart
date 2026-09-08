import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/flow/application/flow_providers.dart';
import 'package:flowmap/src/features/flow/data/flow_queues_repository.dart';
import 'package:flowmap/src/features/studies/application/studies_providers.dart';
import 'package:flowmap/src/features/studies/data/studies_repository.dart';
import 'package:flowmap/src/features/flow/application/flow_view.dart';
import 'package:flowmap/src/features/flow/application/takt_balance.dart';
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

  final clad = Workcenter(
    id: 'wc-1',
    plantId: 'plant-1',
    parallelCapacity: 1,
    name: 'CLAD04',
    createdAt: now,
    updatedAt: now,
  );

  /// A stored queue in front of [target].
  ProjectQueue queueRow(
    String target, {
    DispatchRule? rule,
    int? capacity,
    InventoryMode mode = InventoryMode.duration,
    int? quantity,
    int? seconds = 48 * 3600,
    DurationUnit? unit = DurationUnit.hours,
  }) => ProjectQueue(
    projectId: 'project-1',
    targetId: target,
    rule: rule,
    capacity: capacity,
    stockMode: mode,
    stockQuantity: quantity,
    stockSeconds: seconds,
    stockUnit: unit,
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

  group('the queue, in the step dialog (§7.3)', () {
    /// A step bound to CLAD04, so it has a target and therefore a queue.
    FlowStepView boundStep() => FlowStepView(
      FlowNode(
        id: 'node-1',
        studyId: 'study-1',
        position: 0,
        kind: FlowNodeKind.step,
        workcenterId: 'wc-1',
        changeoverSeconds: 0,
        inventoryUsesWorkingTime: false,
        createdAt: now,
        updatedAt: now,
      ),
      title: 'CLAD04',
      typeName: null,
      poolMemberCount: null,
      dataSource: FlowDataSource.flowEquivalent,
      processTime: const Duration(hours: 68),
      measuredProcessTime: const Duration(hours: 68),
      equivalentProcessTime: const Duration(hours: 68),
      changeover: Duration.zero,
      openPerWorkingDay: const Duration(hours: 22, minutes: 40),
      productivePerWorkingDay: const Duration(hours: 16, minutes: 46),
      openInPeriod: const Duration(hours: 476),
      capacityInPeriod: const Duration(hours: 352),
      operatorsAllocated: 3,
      operatorsPerShift: const [1, 1, 1],
      availability: 1,
      rework: 0,
      problems: const [],
    );

    Future<void> openStep(
      WidgetTester tester, {
      List<ProjectQueue> queues = const [],
      List<Workcenter> workcenters = const [],
      FlowStepView? step,
    }) => pumpHost(
      tester,
      (context, ref) {
        final byTarget = {for (final row in queues) row.targetId: row};
        return step == null
            ? showInsertNodeMenu(
                context,
                ref,
                study: study,
                position: 0,
                queues: byTarget,
              )
            : showStepEditor(
                context,
                ref,
                study: study,
                step: step,
                queues: byTarget,
              );
      },
      overrides: [
        flowTargetsProvider('study-1').overrideWith(
          (ref) async => (
            workcenters: workcenters.isEmpty ? [clad] : workcenters,
            pools: <WorkcenterPool>[],
          ),
        ),
      ],
    );

    /// The caption under the rebalance switch, which is the surface §9.5 drove
    /// and the one place the two balanced standings are told apart.
    FlowStepView balancedStep({
      required BalanceStanding standing,
      required Duration processTime,
      required Duration equivalent,
      double rework = 0.037,
    }) => FlowStepView(
      FlowNode(
        id: 'node-1',
        studyId: 'study-1',
        position: 0,
        kind: FlowNodeKind.step,
        workcenterId: 'wc-1',
        changeoverSeconds: 0,
        inventoryUsesWorkingTime: false,
        createdAt: now,
        updatedAt: now,
      ),
      title: 'CEU32',
      typeName: 'Machining - HBM',
      poolMemberCount: null,
      dataSource: FlowDataSource.singlePart,
      processTime: processTime,
      // Different from the derived share, which is what makes it balanced.
      measuredProcessTime: const Duration(hours: 1),
      equivalentProcessTime: equivalent,
      standing: standing,
      changeover: Duration.zero,
      openPerWorkingDay: const Duration(hours: 22, minutes: 40),
      productivePerWorkingDay: const Duration(hours: 19, minutes: 2),
      openInPeriod: const Duration(hours: 476),
      capacityInPeriod: const Duration(hours: 352),
      operatorsAllocated: 3,
      operatorsPerShift: const [1, 1, 1],
      availability: 0.84,
      rework: rework,
      problems: const [],
    );

    /// The caption under the rebalance switch — the surface §9.5 drove, and
    /// the one place the two balanced standings are told apart.
    group('the rebalance caption (§9.5)', () {
      testWidgets('the last member of a group is not told it filled to a takt', (
        tester,
      ) async {
        // **The §9.5 finding, on the figures it was found with.** CEU32 took
        // 165.2 h of remainder against a takt of 90.7 h and the caption written
        // for a fill said that much content *"uses one whole takt"*. It is two
        // takts and a bit, and the group is over capacity — which is the thing
        // worth telling a planner and the opposite of what it said.
        await openStep(
          tester,
          step: balancedStep(
            standing: BalanceStanding.balancedRemainder,
            processTime: const Duration(hours: 165, minutes: 12),
            equivalent: const Duration(hours: 90, minutes: 42),
          ),
        );

        expect(tester.takeException(), isNull);
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        expect(
          find.text(
            l10n.stepRebalanceRemainderOver(
              'Machining - HBM',
              '165.2 h',
              '90.7 h',
            ),
          ),
          findsOneWidget,
        );
        // And emphatically not the sentence that would claim it fits.
        expect(
          find.text(
            l10n.stepRebalanceOnWithRework(
              'Machining - HBM',
              '165.2 h',
              '90.7 h',
              '3.7',
            ),
          ),
          findsNothing,
        );
      });

      testWidgets('a remainder inside one takt says so without alarm', (
        tester,
      ) async {
        // The other half of §7.4's "under or over": a group with slack leaves its
        // last station short of a takt, and that is not a warning about anything.
        // 57.1 h charged at 3.7 % is 59.2 h, inside 76.2 h.
        await openStep(
          tester,
          step: balancedStep(
            standing: BalanceStanding.balancedRemainder,
            processTime: const Duration(hours: 57, minutes: 6),
            equivalent: const Duration(hours: 76, minutes: 12),
          ),
        );

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(
          find.text(
            l10n.stepRebalanceRemainder('Machining - HBM', '57.1 h', '76.2 h'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('a station that did fill to its takt still says so', (
        tester,
      ) async {
        // The sentence §9.8 added is unchanged for the stations it was written
        // for — this round parts the two, it does not replace one with the other.
        await openStep(
          tester,
          step: balancedStep(
            standing: BalanceStanding.balanced,
            processTime: const Duration(hours: 73, minutes: 30),
            equivalent: const Duration(hours: 76, minutes: 12),
          ),
        );

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(
          find.text(
            l10n.stepRebalanceOnWithRework(
              'Machining - HBM',
              '73.5 h',
              '76.2 h',
              '3.7',
            ),
          ),
          findsOneWidget,
        );
      });
    });

    testWidgets('a bound step carries its target\'s queue, and says it is '
        'shared', (tester) async {
      await openStep(
        tester,
        step: boundStep(),
        queues: [
          queueRow('wc-1', rule: DispatchRule.lifo, capacity: 3),
        ],
      );

      expect(tester.takeException(), isNull);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      // **The heading is the caption the map will draw** (#5, v27), so the
      // dialog and the process box cannot disagree about what this queue is
      // called — and choosing a type visibly renames it.
      expect(find.text('LIFO · CLAD04'), findsOneWidget);
      // Said out loud, because a planner editing this from inside one study has
      // to know the other study's orders stand in the same line.
      expect(find.text(l10n.flowQueueShared('CLAD04')), findsOneWidget);

      // Selected rather than merely offered: a control that opened on the
      // default would silently reset the queue on the next save.
      expect(
        find.text(dispatchRuleLabel(l10n, DispatchRule.lifo)),
        findsOneWidget,
      );
      // **No Name field**: the queue's name went with the label in v27, and
      // all 15 in the live database were `FIFO ` plus a mangled target name.
      expect(find.text(l10n.flowQueueName), findsNothing);
      expect(find.widgetWithText(TextField, '3'), findsOneWidget);
    });

    testWidgets('a step that targets nothing has no queue section', (
      tester,
    ) async {
      // There is no floor space in front of a step that names no station, and
      // nothing to key a row by.
      await openStep(tester);

      expect(tester.takeException(), isNull);
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.flowQueueName), findsNothing);
      expect(find.text(l10n.flowQueueStock), findsNothing);
    });

    testWidgets('picking a workcenter reveals that target\'s queue', (
      tester,
    ) async {
      // The insert path: the section is absent until a target is chosen, then
      // fills from the row that target already has — which may be one another
      // study wrote, and is shown rather than overwritten.
      await openStep(
        tester,
        queues: [queueRow('wc-1', capacity: 4)],
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.flowQueueName), findsNothing);

      await tester.tap(find.text(l10n.valueNone));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CLAD04').last);
      await tester.pumpAndSettle();

      // An untyped lane captions as `Queue`, not FIFO (§5.5).
      expect(find.text('Queue · CLAD04'), findsOneWidget);
      expect(find.widgetWithText(TextField, '4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an untouched queue says it is a push, not FIFO', (
      tester,
    ) async {
      await openStep(tester, step: boundStep());

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // The distinction §5.2 rests on: "nobody has decided" is not the same
      // state as "someone chose FIFO", and only the second draws a channel.
      // The entry is called *Queue* since v27 (#5) — the dropdown says what the
      // lane is, while `FlowConnectionKind.push` and the striped VSM arrow keep
      // the word for how material moves into it.
      expect(find.text(l10n.queueTypeQueue), findsOneWidget);
      expect(find.text(l10n.laneCapacity), findsOneWidget);
    });

    testWidgets('supermarket is named and cannot be chosen', (tester) async {
      await openStep(tester, step: boundStep());

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // Opened through the entry it is showing, because the picker's own type
      // is private to the dialog. Scrolled to first: the step dialog carries
      // the whole queue below the changeover now, so the picker starts below
      // the fold on an 800 px test surface.
      await tester.ensureVisible(find.text(l10n.queueTypeQueue));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.queueTypeQueue));
      await tester.pumpAndSettle();

      // Listed rather than omitted, so a reader looking for it finds out why it
      // is not there: the engine cannot honour it, and a supermarket symbol
      // over FIFO behaviour would be a map that lies about the plant (§7.3).
      expect(find.text(l10n.queueTypeSupermarket), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('changing the unit keeps the wait, not the number', (
      tester,
    ) async {
      await openStep(
        tester,
        step: boundStep(),
        queues: [queueRow('wc-1')],
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

    testWidgets('a queue holding pieces shows a count rather than a wait', (
      tester,
    ) async {
      await openStep(
        tester,
        step: boundStep(),
        queues: [
          queueRow(
            'wc-1',
            mode: InventoryMode.quantity,
            quantity: 5,
            seconds: null,
            unit: null,
          ),
        ],
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byType(DropdownButtonFormField<DurationUnit>),
        findsNothing,
        reason: 'a quantity has no unit of its own — takt supplies it',
      );
      expect(find.widgetWithText(TextField, '5'), findsOneWidget);
    });

    testWidgets('saving a step edit leaves the shared queue alone', (
      tester,
    ) async {
      // **The rule the two studies depend on.** They share five targets on the
      // real database, and a step dialog is opened to change its notes or its
      // times far more often than to retune a floor space — so a save that
      // always wrote the queue would let one study revert the other's capacity
      // without either of them seeing it (§7.3, §12.6).
      //
      // Edited through the notes field since v27 (#5): the step's own label is
      // gone, and notes is the other free-text field a reader opens the dialog
      // to change.
      final writes = _RecordingQueues();

      await pumpHost(
        tester,
        (context, ref) => showStepEditor(
          context,
          ref,
          study: study,
          step: boundStep(),
          queues: {
            'wc-1': queueRow(
              'wc-1',
              rule: DispatchRule.earliestDueDate,
              capacity: 4,
            ),
          },
        ),
        overrides: [
          flowTargetsProvider('study-1').overrideWith(
            (ref) async => (workcenters: [clad], pools: <WorkcenterPool>[]),
          ),
          flowQueuesRepositoryProvider.overrideWithValue(writes),
          // Save writes the step before it writes the queue, and the step's
          // repository holds a database this test has no use for.
          studiesRepositoryProvider.overrideWithValue(_SilentSteps()),
        ],
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      // Found by the field it is labelled with rather than by position — the
      // dialog has several text fields.
      await tester.enterText(
        find.ancestor(
          of: find.text(l10n.flowNodeNotes),
          matching: find.byType(TextField),
        ),
        'A finding from the walk',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.actionSave));
      await tester.pumpAndSettle();

      // Not "wrote the same values back" — **did not write at all**. An upsert
      // of what it loaded would still stamp `updated_at` and would still race
      // the other study's dialog.
      expect(writes.saved, isEmpty);
    });

    testWidgets('typing a lane capacity writes it', (tester) async {
      // **Reported from the field:** "I'm trying to input the lane capacity to
      // 2, but it's not saving." The queue this opens on is untyped and
      // uncapped, which is what the live plant's Coating lane is.
      final writes = _RecordingQueues();

      await pumpHost(
        tester,
        (context, ref) => showStepEditor(
          context,
          ref,
          study: study,
          step: boundStep(),
          queues: {'wc-1': queueRow('wc-1', rule: null, capacity: null)},
        ),
        overrides: [
          flowTargetsProvider('study-1').overrideWith(
            (ref) async => (workcenters: [clad], pools: <WorkcenterPool>[]),
          ),
          flowQueuesRepositoryProvider.overrideWithValue(writes),
          studiesRepositoryProvider.overrideWithValue(_SilentSteps()),
        ],
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.enterText(
        find.ancestor(
          of: find.text(l10n.laneCapacity),
          matching: find.byType(TextField),
        ),
        '2',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.actionSave));
      await tester.pumpAndSettle();

      expect(writes.saved, hasLength(1));
      expect(writes.saved.single.capacity, 2);
    });

    testWidgets('the queue is written after the step, from a closed dialog', (
      tester,
    ) async {
      // **The defect the field hit four times in one evening.** The queue is
      // written *after* the step, which is an await — and `_saveQueue` used to
      // reach for its repository through the `ref` of a widget that had by then
      // been unmounted. Riverpod throws on that, so the step row moved, the
      // queue row did not, and the only trace was a platform error in the log.
      //
      // Reproduced by making the step write take a turn of the event loop and
      // then tearing the host down, which is what closing the dialog does.
      final writes = _RecordingQueues();

      await pumpHost(
        tester,
        (context, ref) => showStepEditor(
          context,
          ref,
          study: study,
          step: boundStep(),
          queues: {'wc-1': queueRow('wc-1', rule: null, capacity: null)},
        ),
        overrides: [
          flowTargetsProvider('study-1').overrideWith(
            (ref) async => (workcenters: [clad], pools: <WorkcenterPool>[]),
          ),
          flowQueuesRepositoryProvider.overrideWithValue(writes),
          studiesRepositoryProvider.overrideWithValue(_SlowSteps()),
        ],
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.enterText(
        find.ancestor(
          of: find.text(l10n.laneCapacity),
          matching: find.byType(TextField),
        ),
        '2',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.actionSave));
      await tester.pump();
      // The host goes while the step write is still in flight, which is the
      // race the dialog closing creates.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      expect(
        writes.saved.single.capacity,
        2,
        reason: 'the queue write must not depend on a widget that has gone',
      );
    });

    testWidgets('changing the queue type writes it', (tester) async {
      // The other half: the rule above must not be so eager that a deliberate
      // edit is dropped too.
      final writes = _RecordingQueues();

      await pumpHost(
        tester,
        (context, ref) => showStepEditor(
          context,
          ref,
          study: study,
          step: boundStep(),
          queues: const {},
        ),
        overrides: [
          flowTargetsProvider('study-1').overrideWith(
            (ref) async => (workcenters: [clad], pools: <WorkcenterPool>[]),
          ),
          flowQueuesRepositoryProvider.overrideWithValue(writes),
          // Save writes the step before it writes the queue, and the step's
          // repository holds a database this test has no use for.
          studiesRepositoryProvider.overrideWithValue(_SilentSteps()),
        ],
      );

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      await tester.ensureVisible(find.text(l10n.queueTypeQueue));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.queueTypeQueue));
      await tester.pumpAndSettle();
      await tester.tap(find.text(dispatchRuleLabel(l10n, DispatchRule.lifo)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.actionSave));
      await tester.pumpAndSettle();

      // A target nobody had described gets a row, because somebody described
      // it — keyed by the target rather than by the step.
      expect(writes.saved, hasLength(1));
      expect(writes.saved.single.targetId, 'wc-1');
      expect(writes.saved.single.rule, DispatchRule.lifo);
    });

    testWidgets('inserting a node offers a step, with no menu in the way', (
      tester,
    ) async {
      await openStep(tester);

      expect(tester.takeException(), isNull);
      // One thing goes on the spine now (§7.3), so the choice dialog went with
      // the inventory node and the step dialog opens directly.
      expect(find.byType(SimpleDialog), findsNothing);
      expect(find.byType(AlertDialog), findsOneWidget);
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
        measuredProcessTime: const Duration(hours: 68),
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
          // The step dialog carries the queue now (§7.3); these tests are about
          // the changeover fields, so the plant has no queue described yet.
          queues: const {},
        ),
        overrides: [
          flowTargetsProvider('study-1').overrideWith(
            (ref) async => (workcenters: [clad], pools: <WorkcenterPool>[]),
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

    testWidgets('clearing an optional changeover is not an error', (
      tester,
    ) async {
      // Reported from the field: *"setup and changeover are optional, but when
      // I delete the value from them the process step input are saying they are
      // required"*. Emptying the box was already fine; **typing `0` was not**,
      // and clearing a number very often lands on a zero rather than on an
      // empty box. A setup of zero is no setup.
      await open(tester, stepView(setupValue: 30, teardownValue: 10));
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      for (final typed in ['', '0', '0.0']) {
        await tester.enterText(
          find.widgetWithText(TextField, '30').hitTestable(),
          typed,
        );
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.validationRequired),
          findsNothing,
          reason: '"$typed" is a way of saying there is no setup',
        );
        expect(
          find.text(l10n.validationNumber),
          findsNothing,
          reason: '"$typed" is a number, or the absence of one',
        );
        final save = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, l10n.actionSave),
        );
        expect(save.onPressed, isNotNull, reason: 'blocked on "$typed"');
        await tester.enterText(
          find.byType(TextField).at(2).hitTestable(),
          '30',
        );
        await tester.pumpAndSettle();
      }
    });

    testWidgets('something that is not a number still says so', (tester) async {
      // The other half: the guard must not be so relaxed that a typo saves.
      await open(tester, stepView(setupValue: 30));
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.enterText(find.widgetWithText(TextField, '30'), 'soon');
      await tester.pumpAndSettle();

      // And it says what is actually wrong, rather than calling an optional
      // field required.
      expect(find.text(l10n.validationNumber), findsOneWidget);
      expect(find.text(l10n.validationRequired), findsNothing);
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

/// Swallows the step write, so a test about the queue does not need a database.
///
/// `noSuchMethod` rather than the twenty-odd members `implements` would demand:
/// what is under test is what happens *after* the step is stored, and every one
/// of those members would be a stub returning nothing.
class _SilentSteps implements StudiesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// Like [_SilentSteps], but the step write takes a turn of the event loop —
/// long enough for the dialog's host to be torn down before the queue write
/// runs, which is the order the app actually does it in.
class _SlowSteps implements StudiesRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<void>.delayed(Duration.zero);
}

/// A stand-in that records what the step dialog asked to be written.
///
/// **No database.** Drift's query streams schedule real timers, which a
/// `testWidgets` fake clock never fires — `pumpAndSettle` then spins until the
/// test times out. What is under test here is whether `saveQueue` is called at
/// all, and that is a question about the dialog rather than about SQLite.
class _RecordingQueues implements FlowQueuesRepository {
  final List<({String targetId, DispatchRule? rule, int? capacity})> saved = [];

  @override
  Future<void> saveQueue({
    required String projectId,
    required String targetId,
    String? name,
    DispatchRule? rule,
    int? capacity,
    InventoryMode? stockMode,
    int? stockQuantity,
    int? stockSeconds,
    DurationUnit? stockUnit,
  }) async {
    saved.add((targetId: targetId, rule: rule, capacity: capacity));
  }

  @override
  Stream<Map<String, ProjectQueue>> watchQueues(String projectId) =>
      const Stream.empty();
}
