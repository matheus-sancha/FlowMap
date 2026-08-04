import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/database.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../diagnostics/application/diagnostics.dart';
import '../application/demand_import.dart';
import '../application/demand_providers.dart';
import '../application/demand_table.dart';
import '../data/import_reader.dart';

/// Importing a spreadsheet into one of the demand grids (DESIGN.md §9).
///
/// Three steps in one dialog — pick, map, preview — because they are one
/// decision: the mapping is only judgeable against what it produces, and a
/// preview with no way back to the mapping is a dead end. **Nothing is written
/// until Import is pressed.**
Future<void> showDemandImport(
  BuildContext context,
  WidgetRef ref, {
  required Study study,
  required DemandTable table,
  required ImportTarget target,
}) async {
  final l10n = AppLocalizations.of(context);

  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Spreadsheet',
        extensions: ['xlsx', 'csv', 'txt'],
      ),
    ],
  );
  if (file == null) return;

  final List<ImportSheet> sheets;
  try {
    sheets = readImportFile(file.name, await file.readAsBytes());
  } on Object catch (error, stack) {
    Diag.error('demand.import', error, stack);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.importUnreadable('$error'))));
    }
    return;
  }

  final usable = sheets.where((sheet) => sheet.rows.length >= 2).toList();
  if (usable.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.importEmpty)));
    }
    return;
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => DemandImportDialog(
      study: study,
      table: table,
      target: target,
      sheets: usable,
      fileName: file.name,
    ),
  );
}

/// The mapping-and-preview dialog, public so it can be mounted in a test
/// without a file picker (DESIGN.md §16.4 — every UI failure this project has
/// had was a mount-time one).
class DemandImportDialog extends ConsumerStatefulWidget {
  const DemandImportDialog({
    super.key,
    required this.study,
    required this.table,
    required this.target,
    required this.sheets,
    required this.fileName,
  });

  final Study study;
  final DemandTable table;
  final ImportTarget target;
  final List<ImportSheet> sheets;
  final String fileName;

  @override
  ConsumerState<DemandImportDialog> createState() => _DemandImportDialogState();
}

class _DemandImportDialogState extends ConsumerState<DemandImportDialog> {
  late ImportSheet _sheet = widget.sheets.first;
  late List<ImportColumn> _columns;
  late Map<int, int?> _mapping;
  var _importing = false;
  var _guessed = false;

  /// Not `initState`: the destination columns are named from
  /// [AppLocalizations], and reading an inherited widget before `initState`
  /// completes is an assertion failure — a blank grey dialog in a release
  /// build, which is how the last two of these were found (§16.4).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _columns = _destinationColumns(AppLocalizations.of(context));
    // Once only: a locale or theme change must not throw away a mapping the
    // user has corrected by hand.
    if (!_guessed) {
      _guessed = true;
      _remap();
    }
  }

  List<ImportColumn> _destinationColumns(AppLocalizations l10n) =>
      switch (widget.target) {
        ImportTarget.parts => partsImportColumns(
          widget.table,
          partNumberTitle: l10n.demandPartNumber,
          descriptionTitle: l10n.demandDescription,
        ),
        ImportTarget.sequence => sequenceImportColumns(
          orderTitle: l10n.demandOrderNumber,
          partNumberTitle: l10n.demandPartNumber,
          batchTitle: l10n.demandBatchSize,
          needDateTitle: l10n.demandNeedDate,
          materialDateTitle: l10n.demandMaterialDate,
        ),
      };

  void _remap() =>
      _mapping = guessMapping(headers: _headers, columns: _columns);

  List<String> get _headers => _sheet.rows.first;

  List<List<String>> get _dataRows => _sheet.rows.skip(1).toList();

  List<ImportRow> _validate(String locale) {
    final mapped = applyMapping(dataRows: _dataRows, mapping: _mapping);
    // The header is line 1, so the first data row is line 2 — the number the
    // user will see in their own spreadsheet.
    return switch (widget.target) {
      ImportTarget.parts => validatePartsImport(
        rows: mapped,
        table: widget.table,
        firstSourceRow: 2,
      ),
      ImportTarget.sequence => validateSequenceImport(
        rows: mapped,
        table: widget.table,
        locale: locale,
        firstSourceRow: 2,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();

    final rows = _validate(locale);
    final blocked = rows.where((r) => r.isBlocked).length;
    final warned = rows.where((r) => !r.isBlocked && r.hasWarnings).length;
    final importable = rows.length - blocked;

    final unmapped = _columns
        .where((c) => _mapping[c.gridColumn] == null)
        .toList();
    final missingRequired = unmapped.where((c) => c.required).toList();

    return AlertDialog(
      title: Text(l10n.importTitle(widget.fileName)),
      content: SizedBox(
        width: 760,
        // Scrolls because a wide flow has a mapping row per step, and the
        // dialog must not outgrow a short window (§16.4).
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.sheets.length > 1) ...[
                DropdownButtonFormField<String>(
                  initialValue: _sheet.name,
                  decoration: InputDecoration(labelText: l10n.importSheet),
                  items: [
                    for (final sheet in widget.sheets)
                      DropdownMenuItem(
                        value: sheet.name,
                        child: Text(sheet.name),
                      ),
                  ],
                  onChanged: (name) => setState(() {
                    _sheet = widget.sheets.firstWhere((s) => s.name == name);
                    // A new sheet has new headings, so the guess is redone
                    // rather than carried across by column position.
                    _remap();
                  }),
                ),
                const SizedBox(height: 16),
              ],
              Text(l10n.importMapping, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final column in _columns)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 220,
                        child: Text(
                          column.required
                              ? '${column.title} *'
                              : column.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _mapping[column.gridColumn],
                          isDense: true,
                          decoration: InputDecoration(
                            isDense: true,
                            errorText:
                                column.required &&
                                    _mapping[column.gridColumn] == null
                                ? l10n.validationRequired
                                : null,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(l10n.importNotMapped),
                            ),
                            for (var i = 0; i < _headers.length; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text(
                                  _headers[i].trim().isEmpty
                                      ? l10n.importColumnNumber('${i + 1}')
                                      : _headers[i],
                                ),
                              ),
                          ],
                          onChanged: (source) => setState(() {
                            _mapping[column.gridColumn] = source;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              if (unmapped.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  // §9: unmatched columns are listed rather than left to be
                  // discovered as missing data later.
                  l10n.importUnmapped(
                    unmapped.map((c) => c.title).join(', '),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
              const Divider(height: 32),
              Text(l10n.importPreview, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              _Counts(
                importable: importable,
                blocked: blocked,
                warned: warned,
              ),
              const SizedBox(height: 8),
              if (missingRequired.isEmpty)
                _Preview(rows: rows, columns: _columns),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _importing ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          onPressed: missingRequired.isNotEmpty || importable == 0 || _importing
              ? null
              : () => _import(rows, locale),
          child: Text(l10n.importAccept('$importable')),
        ),
      ],
    );
  }

  Future<void> _import(List<ImportRow> rows, String locale) async {
    setState(() => _importing = true);
    final repository = ref.read(demandRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      switch (widget.target) {
        case ImportTarget.parts:
          await repository.applyPartsPlan(
            widget.study.id,
            planPartsImport(rows: rows, table: widget.table),
          );
        case ImportTarget.sequence:
          await repository.applySequenceWrites(
            widget.study.id,
            planSequenceImport(
              rows: rows,
              table: widget.table,
              locale: locale,
            ),
          );
      }
      final imported = rows.where((r) => !r.isBlocked).length;
      Diag.event('demand.import', '${widget.target.name} $imported rows');
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.importDone('$imported'))),
      );
    } on Object catch (error, stack) {
      Diag.error('demand.import', error, stack);
      if (!mounted) return;
      setState(() => _importing = false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.importFailed('$error'))),
      );
    }
  }
}

class _Counts extends StatelessWidget {
  const _Counts({
    required this.importable,
    required this.blocked,
    required this.warned,
  });

  final int importable;
  final int blocked;
  final int warned;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Wrap(
      spacing: 16,
      children: [
        Text(l10n.importCountOk('$importable')),
        if (blocked > 0)
          Text(
            l10n.importCountSkipped('$blocked'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        if (warned > 0)
          Text(
            l10n.importCountWarned('$warned'),
            style: TextStyle(color: theme.colorScheme.tertiary),
          ),
      ],
    );
  }
}

/// Row by row, worst first: a preview whose problems are on page four is a
/// preview nobody reads.
class _Preview extends StatelessWidget {
  const _Preview({required this.rows, required this.columns});

  final List<ImportRow> rows;
  final List<ImportColumn> columns;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final ordered = [...rows]..sort((a, b) {
      final rank = _rank(a).compareTo(_rank(b));
      return rank != 0 ? rank : a.sourceRow.compareTo(b.sourceRow);
    });
    final shown = ordered.take(50).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 220,
          child: ListView.builder(
            itemCount: shown.length,
            itemBuilder: (context, index) {
              final row = shown[index];
              final colour = row.isBlocked
                  ? theme.colorScheme.error
                  : row.hasWarnings
                  ? theme.colorScheme.tertiary
                  : null;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        '${row.sourceRow}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        columns
                            .map((c) => row.cell(c.gridColumn))
                            .whereType<String>()
                            .join(' · '),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: Text(
                        row.issues.map((i) => _issueText(l10n, i)).join('; '),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colour,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (ordered.length > shown.length)
          Text(
            l10n.importPreviewTruncated('${ordered.length - shown.length}'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
      ],
    );
  }

  static int _rank(ImportRow row) =>
      row.isBlocked ? 0 : (row.hasWarnings ? 1 : 2);
}

String _issueText(AppLocalizations l10n, ImportIssue issue) =>
    switch (issue.kind) {
      ImportIssueKind.missingPartNumber => l10n.importIssueMissingPart,
      ImportIssueKind.unknownPart => l10n.validationUnknownPart,
      ImportIssueKind.duplicatePartNumber => l10n.importIssueDuplicatePart,
      ImportIssueKind.badDate => l10n.validationNotADate,
      ImportIssueKind.badTime => l10n.validationNotADuration,
      ImportIssueKind.badBatchSize => l10n.validationPositiveWhole,
      ImportIssueKind.needBeforeMaterial => l10n.importIssueNeedBeforeMaterial,
      ImportIssueKind.missingRequired => l10n.validationRequired,
    };
