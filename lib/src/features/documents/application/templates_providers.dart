import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/database/database_providers.dart';
import '../data/document_store.dart';
import '../data/documents_directory.dart';
import '../data/flow_template.dart';
import '../data/flowmap_document.dart';
import '../data/template_binding.dart';
import 'documents_providers.dart';

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
Future<List<TemplateOnDisk>> templates(Ref ref) async {
  final dir = await templatesDirectory();
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

/// Saves one study from the open document as a template.
@riverpod
Future<File> saveStudyAsTemplate(
  Ref ref, {
  required String studyId,
  required bool includeDemand,
}) async {
  final template = await FlowTemplate.fromDatabase(
    ref.read(appDatabaseProvider),
    studyId: studyId,
    includeDemand: includeDemand,
  );

  final dir = await templatesDirectory();
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
  ref.invalidate(templatesProvider);
  return file;
}

/// Applies a template to the project that is open.
///
/// Throws when nothing is open: a template has nowhere to land without a plant
/// to bind against, which is why the screen disables Apply rather than letting
/// it fail here.
@riverpod
Future<BindingResult> applyTemplate(Ref ref, {required File file}) async {
  final session = ref.read(openDocumentProvider);
  if (session == null) {
    throw StateError('no document is open, so a template has nothing to bind to');
  }

  final db = ref.read(appDatabaseProvider);
  final plant = await db
      .customSelect('SELECT id FROM plants ORDER BY rowid LIMIT 1')
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
    projectId: session.projectId,
    plantId: plant.data['id']! as String,
  );
}
