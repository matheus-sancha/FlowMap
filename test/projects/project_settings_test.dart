import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/data/database/enums.dart';
import 'package:flowmap/src/features/projects/data/projects_repository.dart';
import 'package:flowmap/src/features/projects/application/projects_providers.dart';
import 'package:flowmap/src/features/projects/presentation/project_settings_screen.dart';
import 'package:flowmap/src/features/resources/application/resources_providers.dart';
import 'package:flowmap/src/features/schedules/application/schedules_providers.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Project Settings (DESIGN.md §12.1, `TODO.md` §10.1).
///
/// **Two of the fields here had no screen at all before this round.** The
/// create dialog never offered them for editing and the Projects row menu only
/// renames, passing the shift pattern and the notes straight back unchanged —
/// so *"can this be set"* is the first thing worth a test, not the last.
///
/// Providers are overridden rather than fed by Drift, for the reason
/// `demand_tab_test.dart` gives: a Drift stream inside the test binding leaves
/// timers pending, and what reaches the table is `projects_repository`'s
/// question rather than this screen's.
void main() {
  final now = DateTime(2026, 8, 1);

  Project project({String name = 'Fábrica 11', String? notes}) => Project(
    id: 'project-1',
    name: name,
    plantId: 'plant-1',
    shiftPatternId: 'pattern-abc',
    notes: notes,
    createdAt: now,
    updatedAt: now,
      floatRedDays: 0,
      floatGreenDays: 30,
    );

  final plants = [
    Plant(id: 'plant-1', name: 'Taubaté', createdAt: now, updatedAt: now),
    Plant(id: 'plant-2', name: 'Elsewhere', createdAt: now, updatedAt: now),
  ];

  final patterns = [
    ShiftPattern(
      id: 'pattern-abc',
      name: 'ABC',
      cycleType: ShiftCycleType.fixedWeekly,
      workingWeekdays: 31,
      createdAt: now,
      updatedAt: now,
    ),
    ShiftPattern(
      id: 'pattern-abcd',
      name: 'ABCD',
      cycleType: ShiftCycleType.rotating,
      workingWeekdays: 127,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  /// The one call the screen makes into the repository, recorded rather than
  /// executed — every field writes through `_write`, so a single spy says
  /// which of them wrote and with what.
  final writes =
      <({String name, String patternId, String? notes, int? red, int? green})>[];

  Future<void> pump(
    WidgetTester tester, {
    Project? existing,
    List<Project> others = const [],
  }) async {
    writes.clear();
    final subject = existing ?? project();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plantsProvider.overrideWith((ref) => Stream.value(plants)),
          shiftPatternsProvider.overrideWith((ref) => Stream.value(patterns)),
          patternShiftsProvider('pattern-abc').overrideWith(
            (ref) => Stream.value(const <PatternShift>[]),
          ),
          patternShiftsProvider('pattern-abcd').overrideWith(
            (ref) => Stream.value(const <PatternShift>[]),
          ),
          projectsListProvider.overrideWith(
            (ref) => Stream.value([subject, ...others]),
          ),
          calendarExceptionsProvider('project-1').overrideWith(
            (ref) => Stream.value(const <CalendarException>[]),
          ),
          projectsRepositoryProvider.overrideWith(
            (ref) => _SpyProjectsRepository(writes),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ProjectSettingsScreen(project: subject)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('it mounts, with the calendar as a section of it', (
    tester,
  ) async {
    await pump(tester);

    expect(tester.takeException(), isNull);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // The identity fields and the calendar on one screen, which is the whole
    // of §10.1: the exceptions destination is a section here now.
    expect(find.text(l10n.projectSettingsIdentity), findsOne);
    // §10.4's thresholds sit between them, which is what pushed the calendar
    // below the fold — so it is scrolled to rather than assumed on screen. A
    // `ListView` builds lazily and "not built yet" is not "not there".
    expect(find.text(l10n.projectSettingsFloat), findsOne);
    await tester.scrollUntilVisible(
      find.text(l10n.exceptionsScope),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(l10n.calendarExceptions), findsOne);
    expect(find.text(l10n.exceptionsScope), findsOne);
  });

  testWidgets('the plant is shown and cannot be changed', (tester) async {
    // Stronger than the study line's read-only rule, which is about a figure
    // being repointed: every study, schedule, flow node and process time in
    // the project points at this plant's workcenters, so changing it would
    // orphan them rather than move them.
    await pump(tester);

    expect(find.text('Taubaté'), findsOne);
    expect(find.text('Elsewhere'), findsNothing);
  });

  testWidgets('the shift pattern can be set, which it never could before', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('ABC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ABCD').last);
    await tester.pumpAndSettle();

    expect(writes, hasLength(1));
    expect(writes.single.patternId, 'pattern-abcd');
    // And it carried the other two fields through untouched, which is what
    // one write path into a whole-row update has to do.
    expect(writes.single.name, 'Fábrica 11');
    expect(writes.single.notes, isNull);
  });

  testWidgets('notes commit on leaving the field, and empty means null', (
    tester,
  ) async {
    await pump(tester, existing: project(notes: 'Two shifts from April'));

    await tester.enterText(find.byKey(const Key('projectNotes')), '   ');
    // Commit is on blur, not on every keystroke: there is no Save button and
    // no draft to lose (§12.6). Tapping the other field is what blurs this
    // one — nothing here has a Save to press.
    await tester.tap(find.byKey(const Key('projectName')));
    await tester.pumpAndSettle();

    expect(writes, hasLength(1));
    // **Null rather than an empty string.** Two spellings of "no note" is how
    // a filter comes to miss half of them.
    expect(writes.single.notes, isNull);
  });

  testWidgets('a name taken by another project is refused, not written', (
    tester,
  ) async {
    // Project names are unique, so the write would hit the constraint and
    // throw inside an async callback — where the user sees nothing happen at
    // all. The Projects row menu validates for this reason and so must this.
    await pump(
      tester,
      others: [
        Project(
          id: 'project-2',
          name: 'Fábrica 12',
          plantId: 'plant-1',
          shiftPatternId: 'pattern-abc',
          createdAt: now,
          updatedAt: now,
      floatRedDays: 0,
      floatGreenDays: 30,
    ),
      ],
    );

    await tester.enterText(
      find.byKey(const Key('projectName')),
      'fábrica 12',
    );
    await tester.tap(find.byKey(const Key('projectNotes')));
    await tester.pumpAndSettle();

    expect(writes, isEmpty);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.validationNameTaken), findsOne);
    // And the field is put back rather than left disagreeing with what is
    // stored.
    expect(_nameText(tester), 'Fábrica 11');
  });

  testWidgets('a float threshold is written, and read back in days', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(find.byKey(const Key('floatGreen')), '45');
    await tester.tap(find.byKey(const Key('floatRed')));
    await tester.pumpAndSettle();

    expect(writes, hasLength(1));
    expect(writes.single.green, 45);
    // And it carried the other threshold through untouched, which is what one
    // write path into a whole-row update has to do.
    expect(writes.single.red, 0);
  });

  testWidgets('a red threshold above the green one is refused', (tester) async {
    // A crossed pair leaves nothing amber and puts every cell in two bands at
    // once — a state the matrix cannot draw and the reader cannot see they
    // asked for.
    await pump(tester);

    await tester.enterText(find.byKey(const Key('floatRed')), '99');
    await tester.tap(find.byKey(const Key('floatGreen')));
    await tester.pumpAndSettle();

    expect(writes, isEmpty);
    // Put back rather than left disagreeing with what is stored.
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('floatRed')))
          .controller!
          .text,
      '0',
    );
  });

  testWidgets('something that is not a number is refused too', (tester) async {
    await pump(tester);

    await tester.enterText(find.byKey(const Key('floatGreen')), 'soon');
    await tester.tap(find.byKey(const Key('floatRed')));
    await tester.pumpAndSettle();

    expect(writes, isEmpty);
  });

  testWidgets('an emptied name is refused too', (tester) async {
    await pump(tester);

    await tester.enterText(find.byKey(const Key('projectName')), '  ');
    await tester.tap(find.byKey(const Key('projectNotes')));
    await tester.pumpAndSettle();

    expect(writes, isEmpty);
    expect(_nameText(tester), 'Fábrica 11');
  });
}

/// What the name field currently holds — read off its controller, because a
/// `TextField`'s content is an `EditableText` and never a `Text` the finders
/// can see.
String _nameText(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(const Key('projectName'))).controller!.text;

/// Records what the screen asked for instead of writing it.
class _SpyProjectsRepository implements ProjectsRepository {
  _SpyProjectsRepository(this.writes);

  final List<({String name, String patternId, String? notes, int? red, int? green})>
  writes;

  @override
  Future<void> updateProject(
    String id, {
    required String name,
    required String shiftPatternId,
    String? notes,
    int? floatRedDays,
    int? floatGreenDays,
  }) async => writes.add((
    name: name,
    patternId: shiftPatternId,
    notes: notes,
    red: floatRedDays,
    green: floatGreenDays,
  ));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} is not used here');
}
