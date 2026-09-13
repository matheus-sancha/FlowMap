import 'dart:io';

import 'package:drift/drift.dart' show GeneratedDatabase, Variable;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/document_store.dart';
import '../data/documents_directory.dart';
import '../data/flow_template.dart';
import '../data/flowmap_document.dart';
import '../data/template_binding.dart';

part 'templates_providers.g.dart';

/// One template on the shelf, and what its manifest says without opening it.
class TemplateOnDisk {
  const TemplateOnDisk({required this.file, required this.manifest});

  final File file;
  final TemplateManifest manifest;
}

/// The templates folder, read from disk rather than from a table.
///
/// **Nothing records what is on the shelf.** A template is a file; dropping one
/// into the folder installs it and deleting it removes it, with no list to keep
/// in step. That is the same reason the recent-documents list is a convenience
/// and never a record.
@riverpod
Future<List<TemplateOnDisk>> templates(Ref ref) async =>
    readTemplateShelf(await templatesDirectory());

/// Every readable template in [dir], by study name.
Future<List<TemplateOnDisk>> readTemplateShelf(Directory dir) async {
  if (!dir.existsSync()) return const [];

  final found = <TemplateOnDisk>[];
  for (final entry in dir.listSync().whereType<File>()) {
    if (!entry.path.toLowerCase().endsWith('.${FlowTemplate.extension}')) {
      continue;
    }
    try {
      // The manifest is its own entry, so the shelf is listed without parsing
      // a single study — and one unreadable file does not empty the screen.
      found.add(
        TemplateOnDisk(
          file: entry,
          manifest: FlowTemplate.read(entry.readAsBytesSync()).manifest,
        ),
      );
    } catch (_) {
      continue;
    }
  }
  found.sort(
    (a, b) => a.manifest.studyName.toLowerCase().compareTo(
      b.manifest.studyName.toLowerCase(),
    ),
  );
  return found;
}

/// Saves one study from the open document as a template in [dir].
///
/// **A function, not a provider** (field report, 2026-09-13). It was an
/// auto-disposing `FutureProvider` read once for its side effect, so by the
/// time the file was written nothing was listening and the provider had been
/// disposed: refreshing the shelf through its `ref` threw, the Templates screen
/// kept the list it already had, and the saved template never appeared. The
/// caller refreshes the shelf instead — see [refreshTemplateShelf].
Future<File> saveStudyAsTemplate(
  GeneratedDatabase db,
  Directory dir, {
  required String studyId,
  required bool includeDemand,
}) async {
  final template = await FlowTemplate.fromDatabase(
    db,
    studyId: studyId,
    includeDemand: includeDemand,
  );

  await dir.create(recursive: true);

  // Named for the study, and never over something already there — the same
  // rule the one-time conversion uses for documents.
  var stem = template.manifest.studyName
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (!RegExp(r'[a-zA-Z0-9]').hasMatch(stem)) stem = 'Template';
  var name = '$stem.${FlowTemplate.extension}';
  var n = 2;
  while (File('${dir.path}${Platform.pathSeparator}$name').existsSync()) {
    name = '$stem ($n).${FlowTemplate.extension}';
    n++;
  }

  final file = File('${dir.path}${Platform.pathSeparator}$name');
  await DocumentStore.writeAtomically(file, template.write());
  return file;
}

/// Tells the Templates screen to read its folder again.
///
/// Through the container rather than a widget's `ref`, which is gone if the
/// widget that started a save has left the screen by the time it finishes.
void refreshTemplateShelf(ProviderContainer container) =>
    container.invalidate(templatesProvider);

/// Applies the template in [file] to the project [projectId] in [db].
///
/// **A function, not a provider**, for the reason [saveStudyAsTemplate] gives —
/// and one more: a provider keyed by the file hands back its cached result, so
/// applying the same template twice could quietly apply it once.
Future<BindingResult> applyTemplate(
  GeneratedDatabase db, {
  required String projectId,
  required File file,
}) async {
  // **The project's plant, not the document's first one.** A document may
  // hold several plants (phase 8), and a template lands on the one the
  // project simulates.
  final plant = await db
      .customSelect(
        'SELECT plant_id AS id FROM projects WHERE id = ?',
        variables: [Variable<String>(projectId)],
      )
      .getSingleOrNull();
  if (plant == null) {
    throw StateError('the open document has no plant to bind against');
  }

  final template = FlowTemplate.read(file.readAsBytesSync());
  if (template.manifest.isFromNewerFormat) {
    throw const DocumentFormatException(
      'This template was written by a newer version of FlowMap. '
      'Update FlowMap to use it.',
    );
  }

  return TemplateBinding(db).apply(
    template,
    projectId: projectId,
    plantId: plant.data['id']! as String,
  );
}
