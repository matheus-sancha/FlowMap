import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/help_icon.dart';
import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../resources/application/resources_providers.dart';
import '../../schedules/presentation/exceptions_view.dart';
import '../application/projects_providers.dart';

/// Everything about a project that is not one of its studies (DESIGN.md §12.1).
///
/// **A destination, where these were a dialog, a row menu and nothing at all.**
/// §10.1 said a project's fields were *"edited in a dialog launched from the
/// Projects list"*; reading the code first — which this file's own header asks
/// for twice — says less than that and worse. The dialog is **create-only**.
/// The one edit path is `Rename` on the Projects row menu, which calls
/// `promptForName` and passes the shift pattern and the notes straight back
/// unchanged. So **the shift pattern and the notes were stored, written by
/// `updateProject`, and reachable from no screen in the app** — the same shape
/// as §17.5's `wipCap` and `priority`, which Study Settings closed for the same
/// reason — and `priority` then went altogether in v28 (#6), reachability
/// having shown it was a lever nobody wanted.
///
/// So this is not only a move. It is the first time two stored fields can be
/// set at all.
///
/// **It mirrors Study Settings one level up**, deliberately: the same cards,
/// the same commit-on-blur bargain, the same read-only treatment for the one
/// field that must not change. There is no Save button and no draft to lose —
/// a destination that saves as you leave a field cannot hold a half-typed
/// state that disagrees with what is stored (§12.6).
///
/// **Calendar Exceptions is a section here rather than a destination of its
/// own**, which is where §12.1's argument lands once there is a project-level
/// place at all. Its reason for not being a dialog is untouched — a calendar is
/// browsed, not filled in and dismissed — and it is browsed here.
class ProjectSettingsScreen extends ConsumerWidget {
  const ProjectSettingsScreen({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final plants = ref.watch(plantsProvider).value;
    // **Watched here rather than read inside the field.** A `ref.read` of a
    // lazily-initialised `StreamProvider` nobody is listening to returns
    // `AsyncLoading`, so the duplicate guard saw an empty list and let the
    // write through to the unique constraint — where it throws inside an async
    // callback and the user sees nothing happen. Caught by the test that
    // exists for exactly that failure.
    final others = <String>{
      for (final other
          in ref.watch(projectsListProvider).value ?? const <Project>[])
        if (other.id != project.id) other.name.toLowerCase(),
    };
    final patterns = ref.watch(shiftPatternsProvider).value;
    final shifts = ref
        .watch(patternShiftsProvider(project.shiftPatternId))
        .value;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(l10n.projectSettingsIdentity, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NameField(project: project, takenNames: others),
                const SizedBox(height: 16),
                // **Read-only, and the reason is stronger than the study
                // line's.** Every study, schedule, flow node and process time
                // in the project points at this plant's workcenters, so
                // changing it would not repoint them — it would orphan them.
                // The create dialog already says so in its own help text; this
                // says the same thing where somebody would try it.
                _ReadOnly(
                  label: l10n.plant,
                  value: _plantName(plants),
                  help: l10n.projectPlantHelp,
                ),
                const SizedBox(height: 16),
                if (patterns == null)
                  const Center(child: CircularProgressIndicator())
                else
                  _PatternField(project: project, patterns: patterns),
                const SizedBox(height: 16),
                _NotesField(project: project),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(l10n.projectSettingsFloat, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          l10n.projectSettingsFloatHelp,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _FloatField(project: project, red: true)),
                    const SizedBox(width: 16),
                    Expanded(child: _FloatField(project: project, red: false)),
                  ],
                ),
                const SizedBox(height: 16),
                // **The Occupation grid's bands, on the same card** (#9, v29).
                // Two thresholds of the same shape, read by the surface next
                // door — and putting them anywhere else would make a reader
                // hunt for the second of two settings that do the same job.
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.occupationBands,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _OccupationField(project: project, amber: true),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _OccupationField(project: project, amber: false),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(l10n.calendarExceptions, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          l10n.exceptionsScope,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 16),
        // The shift labels come from the project's own pattern, so switching it
        // above re-labels the columns here without a reload — which is also the
        // cheapest demonstration that the two belong on one screen.
        if (shifts == null)
          const Center(child: CircularProgressIndicator())
        else
          CalendarExceptionsView(
            project: project,
            shiftLabels: [for (final shift in shifts) shift.label],
          ),
      ],
    );
  }

  String _plantName(List<Plant>? plants) =>
      plants?.where((p) => p.id == project.plantId).firstOrNull?.name ?? '—';
}

/// A label and a value that cannot be edited here, drawn like the fields around
/// it so the panel reads as one thing.
class _ReadOnly extends StatelessWidget {
  const _ReadOnly({required this.label, required this.value, this.help});

  final String label;
  final String value;
  final String? help;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      suffixIcon: helpIcon(context, help),
      enabled: false,
    ),
    child: Text(value),
  );
}

class _NameField extends ConsumerStatefulWidget {
  const _NameField({required this.project, required this.takenNames});

  final Project project;

  /// Every *other* project's name, lower-cased. Passed in rather than read on
  /// commit, so the guard cannot fire against a list that has not loaded.
  final Set<String> takenNames;

  @override
  ConsumerState<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends ConsumerState<_NameField> {
  late final _controller = TextEditingController(text: widget.project.name);
  late final FocusNode _focus = FocusNode()
    ..addListener(() {
      if (!_focus.hasFocus) _commit();
    });

  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// **Refused rather than stored, twice over.** An emptied name leaves a
  /// project that cannot be told from another in the list; a duplicate hits the
  /// unique constraint and throws inside an async callback, where the user sees
  /// nothing happen at all. That second case is why the Projects row menu
  /// validates before writing, and the same guard has to be here.
  void _commit() {
    final name = _controller.text.trim();
    if (name.isEmpty || widget.takenNames.contains(name.toLowerCase())) {
      setState(() {
        _error = name.isEmpty
            ? null
            : AppLocalizations.of(context).validationNameTaken;
        _controller.text = widget.project.name;
      });
      return;
    }
    if (_error != null) setState(() => _error = null);
    if (name == widget.project.name) return;
    _write(ref, widget.project, name: name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      key: const Key('projectName'),
      controller: _controller,
      focusNode: _focus,
      decoration: InputDecoration(
        labelText: l10n.fieldName,
        errorText: _error,
      ),
      onSubmitted: (_) => _commit(),
    );
  }
}

/// The pattern every workcenter in the project reads its open hours from.
///
/// **Editable, and it was not reachable before.** Changing it re-times every
/// station in the project, which is exactly the experiment a planner runs — and
/// until now the only way to run it was to create a second project.
class _PatternField extends ConsumerWidget {
  const _PatternField({required this.project, required this.patterns});

  final Project project;
  final List<ShiftPattern> patterns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // A pattern archived since the project was created still names the
    // project's own row, so it is offered rather than dropped — the list would
    // otherwise open on somebody else's pattern and write it on the first
    // touch.
    final options = {
      for (final pattern in patterns) pattern.id: pattern,
    };
    return DropdownButtonFormField<String>(
      initialValue: options.containsKey(project.shiftPatternId)
          ? project.shiftPatternId
          : null,
      decoration: InputDecoration(
        labelText: l10n.shiftPattern,
        suffixIcon: helpIcon(context, l10n.projectPatternHelp),
      ),
      items: [
        for (final pattern in options.values)
          DropdownMenuItem(value: pattern.id, child: Text(pattern.name)),
      ],
      onChanged: (id) =>
          id == null ? null : _write(ref, project, shiftPatternId: id),
    );
  }
}

class _NotesField extends ConsumerStatefulWidget {
  const _NotesField({required this.project});

  final Project project;

  @override
  ConsumerState<_NotesField> createState() => _NotesFieldState();
}

class _NotesFieldState extends ConsumerState<_NotesField> {
  late final _controller = TextEditingController(
    text: widget.project.notes ?? '',
  );
  late final FocusNode _focus = FocusNode()
    ..addListener(() {
      if (!_focus.hasFocus) _commit();
    });

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// **Emptied means null, not an empty string.** Nothing else in the app
  /// stores `''` for an absent note, and two spellings of "no note" is how a
  /// filter comes to miss half of them.
  void _commit() {
    final text = _controller.text.trim();
    final notes = text.isEmpty ? null : text;
    if (notes == widget.project.notes) return;
    _write(ref, widget.project, notes: notes, notesGiven: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      key: const Key('projectNotes'),
      controller: _controller,
      focusNode: _focus,
      minLines: 2,
      maxLines: 5,
      decoration: InputDecoration(
        labelText: l10n.fieldNotes,
        alignLabelWithHint: true,
      ),
    );
  }
}

/// One of §10.4's two thresholds, in days.
///
/// **Committed on blur like every other field here**, and refused rather than
/// stored where it is not a number or would cross its partner: a red threshold
/// above the green one leaves nothing amber and every cell in two bands at once,
/// which is a state the matrix cannot draw and the reader cannot see they asked
/// for.

/// The Occupation grid's two thresholds (#9, v29).
///
/// **`_FloatField`'s shape, deliberately not `_FloatField` with a flag.** The
/// two pairs share a card and a commit-on-blur bargain and nothing else: float
/// is in days and red is the *lower* bound, occupation is per cent and red is
/// the *higher* one, so a shared widget would be two bodies behind one
/// signature. The rejection is the same one #10 made about merging `DataGrid`
/// and `resultTable`.
class _OccupationField extends ConsumerStatefulWidget {
  const _OccupationField({required this.project, required this.amber});

  final Project project;
  final bool amber;

  @override
  ConsumerState<_OccupationField> createState() => _OccupationFieldState();
}

class _OccupationFieldState extends ConsumerState<_OccupationField> {
  late final _controller = TextEditingController(text: '$_stored');
  late final FocusNode _focus = FocusNode()
    ..addListener(() {
      if (!_focus.hasFocus) _commit();
    });

  int get _stored => widget.amber
      ? widget.project.occupationAmberPct
      : widget.project.occupationRedPct;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final typed = int.tryParse(_controller.text.trim());
    final other = widget.amber
        ? widget.project.occupationRedPct
        : widget.project.occupationAmberPct;
    // **Amber below red, and the reverse of the float pair.** Here a higher
    // number is worse, so amber has to sit under red — the opposite ordering to
    // the float thresholds on the row above, which is exactly why these are two
    // widgets rather than one.
    final crosses =
        typed != null && (widget.amber ? typed > other : typed < other);

    // A threshold at or below zero would band every cell red, which is a
    // setting that reads as a broken grid rather than as a choice.
    if (typed == null || typed <= 0 || crosses) {
      setState(() => _controller.text = '$_stored');
      return;
    }
    if (typed == _stored) return;
    _write(
      ref,
      widget.project,
      occupationAmberPct: widget.amber ? typed : null,
      occupationRedPct: widget.amber ? null : typed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      key: Key(widget.amber ? 'occupationAmber' : 'occupationRed'),
      controller: _controller,
      focusNode: _focus,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: widget.amber
            ? l10n.occupationAmberAbove
            : l10n.occupationRedAbove,
        suffixText: '%',
      ),
      onSubmitted: (_) => _commit(),
    );
  }
}

class _FloatField extends ConsumerStatefulWidget {
  const _FloatField({required this.project, required this.red});

  final Project project;
  final bool red;

  @override
  ConsumerState<_FloatField> createState() => _FloatFieldState();
}

class _FloatFieldState extends ConsumerState<_FloatField> {
  late final _controller = TextEditingController(text: '$_stored');
  late final FocusNode _focus = FocusNode()
    ..addListener(() {
      if (!_focus.hasFocus) _commit();
    });

  int get _stored =>
      widget.red ? widget.project.floatRedDays : widget.project.floatGreenDays;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    final typed = int.tryParse(_controller.text.trim());
    final other = widget.red
        ? widget.project.floatGreenDays
        : widget.project.floatRedDays;
    final crosses = typed != null && (widget.red ? typed > other : typed < other);

    if (typed == null || crosses) {
      setState(() => _controller.text = '$_stored');
      return;
    }
    if (typed == _stored) return;
    _write(
      ref,
      widget.project,
      floatRedDays: widget.red ? typed : null,
      floatGreenDays: widget.red ? null : typed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      key: Key(widget.red ? 'floatRed' : 'floatGreen'),
      controller: _controller,
      focusNode: _focus,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: widget.red ? l10n.projectFloatRed : l10n.projectFloatGreen,
        suffixIcon: helpIcon(
          context,
          widget.red ? l10n.projectFloatRedHelp : l10n.projectFloatGreenHelp,
        ),
      ),
      onSubmitted: (_) => _commit(),
    );
  }
}

/// One write path into `projects`, so two fields cannot disagree about the
/// third — the argument `station_cards.dart` already makes about the dialog
/// §6.3 deleted.
///
/// `updateProject` takes the whole row, so every caller has to pass what it is
/// not changing. Null is a real answer for the notes, so absence is said
/// separately rather than being spelled the same way as *clear it*.
void _write(
  WidgetRef ref,
  Project project, {
  String? name,
  String? shiftPatternId,
  String? notes,
  bool notesGiven = false,
  int? floatRedDays,
  int? floatGreenDays,
  int? occupationAmberPct,
  int? occupationRedPct,
}) => ref
    .read(projectsRepositoryProvider)
    .updateProject(
      project.id,
      name: name ?? project.name,
      shiftPatternId: shiftPatternId ?? project.shiftPatternId,
      notes: notesGiven ? notes : project.notes,
      floatRedDays: floatRedDays ?? project.floatRedDays,
      floatGreenDays: floatGreenDays ?? project.floatGreenDays,
      occupationAmberPct: occupationAmberPct ?? project.occupationAmberPct,
      occupationRedPct: occupationRedPct ?? project.occupationRedPct,
    );
