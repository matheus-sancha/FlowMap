import 'dart:io';

import 'flowmap_document.dart';

/// Writes the open document somewhere new, as a genuinely separate project.
///
/// **The copy gets a fresh project id.** A document's identity *is* its project
/// id, and stored runs are keyed by it (v32) — so a byte-for-byte copy would
/// leave two files pooling one history, and opening the copy would show runs
/// made from the original, of a plant you may since have changed.
///
/// That is also what makes *open a reference and save a copy* produce **your**
/// plant rather than a second window onto someone else's. It is the answer to
/// how a new project gets a plant at all, since a new document starts empty by
/// design.
class SaveAs {
  const SaveAs._();

  /// Returns [document] rewritten for a new file: a fresh project id, and the
  /// name the file implies.
  ///
  /// **Only the project half is remapped.** The plant travels unchanged —
  /// workcenters, types, cells, lines and patterns keep their ids, because they
  /// are the same physical plant and nothing outside the document refers to
  /// them.
  static FlowmapDocument rename(
    FlowmapDocument document, {
    required String newProjectId,
    required String newProjectName,
    required String appVersion,
  }) {
    final oldId = document.manifest.projectId;

    // Every occurrence of the id, wherever it appears. A uuid cannot collide
    // with anything else in the payload by accident, so this reaches
    // `projects.id`, `studies.project_id`, `project_queues.project_id`,
    // `takt_periods.project_id`, `workcenter_schedule_periods.project_id` and
    // `calendar_exceptions.project_id` without naming any of them — which is
    // the same reason the format never writes a column list by hand (#30).
    final project = <String, List<Map<String, Object?>>>{
      for (final table in document.project.entries)
        table.key: [
          for (final row in table.value)
            {
              for (final column in row.entries)
                column.key: column.value == oldId ? newProjectId : column.value,
            },
        ],
    };

    // The name is the project's, not the file's copy of it: the row is what the
    // app reads, and the manifest only reports.
    for (final row in project['projects'] ?? const []) {
      if (row['id'] == newProjectId) row['name'] = newProjectName;
    }

    return FlowmapDocument(
      manifest: DocumentManifest(
        format: document.manifest.format,
        appVersion: appVersion,
        schemaVersion: document.manifest.schemaVersion,
        projectId: newProjectId,
        projectName: newProjectName,
        written: DateTime.now(),
        counts: document.manifest.counts,
      ),
      plant: document.plant,
      project: project,
    );
  }

  /// The project name a chosen file name implies.
  static String projectNameFor(String path) {
    var stem = path.split(Platform.pathSeparator).last;
    if (stem.toLowerCase().endsWith('.flowmap')) {
      stem = stem.substring(0, stem.length - '.flowmap'.length);
    }
    stem = stem.trim();
    return stem.isEmpty ? 'Project' : stem;
  }
}
