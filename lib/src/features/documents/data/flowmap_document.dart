import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';

import '../../../app/build_info.dart';

/// The `.flowmap` document: a zip holding a manifest and two JSON payloads
/// (DESIGN.md §2, #24, #37).
///
/// ```
/// Celula-11.flowmap
///   manifest.json   format, build, schema, counts — readable alone
///   plant.json      the Resources this document carries
///   project.json    the one project it is
/// ```
///
/// **The manifest is read first and by itself**, which is what lets a file from
/// a newer build be refused with a sentence instead of a crash: nothing else is
/// parsed until it has been agreed to.
///
/// **A document carries its plant and not its runs** (#37). Resources are 135
/// rows against 630 of project data, so the plant travels and a document opened
/// anywhere produces the same numbers; runs are 488,849 rows against those 630
/// — a factor of 635 — so they stay on the machine that made them and a reader
/// re-runs rather than receives (§4.4 makes that exact).
///
/// **Rows are written column by column, never field by field.** The tables are
/// read with `SELECT *` and written back by the column names that come out, so
/// a column added to the schema is carried without anyone remembering to add
/// it. That is deliberate and it is the one guard this file has: §2.6b caught
/// `duplicateStudy` silently dropping a column *twice*, and a hand-written list
/// is exactly what failed both times (#30).
class FlowmapDocument {
  const FlowmapDocument({
    required this.manifest,
    required this.plant,
    required this.project,
  });

  final DocumentManifest manifest;

  /// Resources, keyed by SQL table name. The whole plant, unfiltered.
  final Map<String, List<Map<String, Object?>>> plant;

  /// The one project this document is, keyed by SQL table name.
  final Map<String, List<Map<String, Object?>>> project;

  static const manifestEntry = 'manifest.json';
  static const plantEntry = 'plant.json';
  static const projectEntry = 'project.json';

  /// The tables whose rows are the plant a document carries.
  ///
  /// **Order matters on the way in**: a workcenter needs its type and plant to
  /// exist, a pool member needs its pool. Written in dependency order so a load
  /// can insert straight down the list.
  static const plantTables = <String>[
    'plants',
    'production_cells',
    'production_lines',
    'workcenter_types',
    'workcenters',
    'workcenter_lines',
    'workcenter_pools',
    'workcenter_pool_members',
    'shift_patterns',
    'pattern_shifts',
  ];

  /// The tables whose rows belong to one project, in dependency order.
  ///
  /// `workcenter_schedule_periods` and `takt_periods` are **here and not in the
  /// plant**, because they are keyed by project: the plant's *hours* have
  /// always been per-project, and only its *structure* was ever shared. That
  /// asymmetry is half of why #37 could put the plant in the document at all.
  static const projectTables = <String>[
    'projects',
    'studies',
    'flow_nodes',
    'flow_annotations',
    'demand_parts',
    'demand_orders',
    'part_process_times',
    'project_queues',
    'takt_periods',
    'workcenter_schedule_periods',
    'calendar_exceptions',
  ];

  /// Tables a document never carries, named so the set can be checked against
  /// the database rather than trusted.
  ///
  /// The eight `simulation_run*` tables are the 635× (#37); `app_settings` is
  /// the machine's, not the document's.
  static const excludedTables = <String>[
    'app_settings',
    'simulation_runs',
    'simulation_run_studies',
    'simulation_run_orders',
    'simulation_run_steps',
    'simulation_run_empty_slots',
    'simulation_run_workcenters',
    'simulation_run_lanes',
    'simulation_run_lane_visits',
    'simulation_run_workcenter_months',
  ];

  /// Every table this document format knows about.
  static Set<String> get knownTables =>
      {...plantTables, ...projectTables, ...excludedTables};

  int get rowCount =>
      plant.values.fold(0, (n, rows) => n + rows.length) +
      project.values.fold(0, (n, rows) => n + rows.length);

  /// Packs the document into the bytes of a `.flowmap` file.
  Uint8List write() {
    final archive = Archive();
    void add(String name, Object? content) {
      final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(content));
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    add(manifestEntry, manifest.toJson());
    add(plantEntry, plant);
    add(projectEntry, project);
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  /// Reads the manifest **alone**, without parsing the payloads.
  ///
  /// This is the whole reason the manifest is its own entry: a file from a
  /// build that writes a format this one does not understand is answered with a
  /// sentence, and a corrupt or enormous payload is never touched to find out.
  static DocumentManifest readManifest(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.findFile(manifestEntry);
    if (entry == null) {
      throw const DocumentFormatException(
        'This file is not a FlowMap document: it has no manifest.',
      );
    }
    try {
      final json = jsonDecode(utf8.decode(entry.content as List<int>));
      return DocumentManifest.fromJson(json as Map<String, dynamic>);
    } on DocumentFormatException {
      rethrow;
    } catch (_) {
      throw const DocumentFormatException(
        'This file is a FlowMap document, but its manifest could not be read.',
      );
    }
  }

  /// Reads a whole document, manifest first.
  static FlowmapDocument read(Uint8List bytes) {
    final manifest = readManifest(bytes);
    final archive = ZipDecoder().decodeBytes(bytes);

    Map<String, List<Map<String, Object?>>> payload(String name) {
      final entry = archive.findFile(name);
      if (entry == null) {
        throw DocumentFormatException(
          'This FlowMap document is incomplete: $name is missing.',
        );
      }
      final decoded = jsonDecode(utf8.decode(entry.content as List<int>));
      return {
        for (final table in (decoded as Map<String, dynamic>).entries)
          table.key: [
            for (final row in table.value as List)
              (row as Map<String, dynamic>).cast<String, Object?>(),
          ],
      };
    }

    return FlowmapDocument(
      manifest: manifest,
      plant: payload(plantEntry),
      project: payload(projectEntry),
    );
  }

  /// Reads one project, and the whole plant, out of an open database.
  ///
  /// Rows come back as the columns the database has, so a schema that grows a
  /// column grows the document with it.
  static Future<FlowmapDocument> fromDatabase(
    GeneratedDatabase db, {
    required String projectId,
    required String projectName,
  }) async {
    Future<List<Map<String, Object?>>> rows(String table, {String? where}) async {
      final result = await db
          .customSelect('SELECT * FROM "$table"${where == null ? '' : ' WHERE $where'}')
          .get();
      return [for (final row in result) Map<String, Object?>.from(row.data)];
    }

    final plant = <String, List<Map<String, Object?>>>{
      for (final table in plantTables) table: await rows(table),
    };

    // Everything under one project. `projects` is keyed by `id`; every other
    // table reaches it through `project_id`, except the ones that hang off a
    // study or a node and are filtered through theirs.
    final project = <String, List<Map<String, Object?>>>{
      'projects': await rows('projects', where: "id = '$projectId'"),
      'studies': await rows('studies', where: "project_id = '$projectId'"),
      'flow_nodes': await rows(
        'flow_nodes',
        where: "study_id IN (SELECT id FROM studies WHERE project_id = '$projectId')",
      ),
      'flow_annotations': await rows(
        'flow_annotations',
        where: "study_id IN (SELECT id FROM studies WHERE project_id = '$projectId')",
      ),
      'demand_parts': await rows(
        'demand_parts',
        where: "study_id IN (SELECT id FROM studies WHERE project_id = '$projectId')",
      ),
      'demand_orders': await rows(
        'demand_orders',
        where: "study_id IN (SELECT id FROM studies WHERE project_id = '$projectId')",
      ),
      'part_process_times': await rows(
        'part_process_times',
        where: "part_id IN (SELECT id FROM demand_parts WHERE study_id IN "
            "(SELECT id FROM studies WHERE project_id = '$projectId'))",
      ),
      'project_queues': await rows('project_queues', where: "project_id = '$projectId'"),
      'takt_periods': await rows('takt_periods', where: "project_id = '$projectId'"),
      'workcenter_schedule_periods':
          await rows('workcenter_schedule_periods', where: "project_id = '$projectId'"),
      'calendar_exceptions':
          await rows('calendar_exceptions', where: "project_id = '$projectId'"),
    };

    return FlowmapDocument(
      manifest: DocumentManifest(
        format: DocumentManifest.currentFormat,
        appVersion: kBuildLabel,
        schemaVersion: db.schemaVersion,
        projectId: projectId,
        projectName: projectName,
        written: DateTime.now(),
        counts: {
          for (final entry in {...plant, ...project}.entries)
            if (entry.value.isNotEmpty) entry.key: entry.value.length,
        },
      ),
      plant: plant,
      project: project,
    );
  }
}

/// What a document says about itself before any of it is trusted.
class DocumentManifest {
  const DocumentManifest({
    required this.format,
    required this.appVersion,
    required this.schemaVersion,
    required this.projectId,
    required this.projectName,
    required this.written,
    required this.counts,
  });

  /// The document format's own version, which moves **independently of the
  /// schema** — that separation is why #24 chose JSON over a SQLite file, and
  /// it is what lets a v28 document still open on a v31 build.
  static const int currentFormat = 1;

  final int format;
  final String appVersion;
  final int schemaVersion;
  final String projectId;
  final String projectName;
  final DateTime written;
  final Map<String, int> counts;

  bool get isFromNewerFormat => format > currentFormat;

  Map<String, dynamic> toJson() => {
    'format': format,
    'app_version': appVersion,
    'schema': schemaVersion,
    'project': {'id': projectId, 'name': projectName},
    'written': written.toIso8601String(),
    'counts': counts,
  };

  factory DocumentManifest.fromJson(Map<String, dynamic> json) {
    final project = json['project'];
    if (json['format'] is! int || project is! Map) {
      throw const DocumentFormatException(
        'This file is not a FlowMap document.',
      );
    }
    return DocumentManifest(
      format: json['format'] as int,
      appVersion: json['app_version'] as String? ?? 'unknown',
      schemaVersion: json['schema'] as int? ?? 0,
      projectId: project['id'] as String,
      projectName: project['name'] as String? ?? 'Untitled',
      written: DateTime.tryParse(json['written'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      counts: {
        for (final entry in (json['counts'] as Map? ?? {}).entries)
          entry.key as String: entry.value as int,
      },
    );
  }
}

/// A document that cannot be opened, with a sentence saying why.
///
/// **The message is the point.** These are the first errors in this app's
/// history that will be read by someone who cannot ask the author what they
/// mean, so each one says what the file is and what to do rather than naming
/// the code that gave up.
class DocumentFormatException implements Exception {
  const DocumentFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}
