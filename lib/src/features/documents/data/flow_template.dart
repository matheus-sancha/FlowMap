import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';

import '../../../app/build_info.dart';
import 'flowmap_document.dart';

/// A study's flow, saved so it can be applied to a plant that is not its own.
///
/// **A different file from a document, deliberately.** A `.flowmap` carries a
/// whole project and the plant it runs on (#37); a `.flowtemplate` carries one
/// study and **references** to the plant it came from, by name and type. Two
/// things sharing one extension and differing by an order of magnitude is the
/// trap #24 named when it refused to let runs ride inside documents.
///
/// **This is the one thing Save As cannot do.** Saving a copy starts a new
/// project from an existing one; a template takes one flow *into* a project you
/// already have, which is what §10.2 promised and what "save studies as
/// templates" asked for.
///
/// **What it does not carry:** queue settings. They are project-scoped rows and
/// **6 of 15 are shared between studies** on the live plant, so a template that
/// carried them would rewrite discipline for studies nobody applied anything to
/// ([#23](https://github.com/matheus-sancha/FlowMap/issues/23)).
class FlowTemplate {
  const FlowTemplate({
    required this.manifest,
    required this.study,
    required this.targets,
  });

  final TemplateManifest manifest;

  /// The study itself, keyed by SQL table name: its row, its flow, its process
  /// times, and its demand when it was included.
  final Map<String, List<Map<String, Object?>>> study;

  /// What the flow points at, described so another plant can be searched for
  /// it: names and types rather than ids.
  final TemplateTargets targets;

  static const extension = 'flowtemplate';
  static const manifestEntry = 'manifest.json';
  static const studyEntry = 'study.json';
  static const targetsEntry = 'targets.json';

  /// The tables a template carries, in dependency order.
  static const studyTables = <String>[
    'studies',
    'flow_nodes',
    'flow_annotations',
    'demand_parts',
    'demand_orders',
    'part_process_times',
  ];

  /// The tables carried only when demand was included at save time (§10.2).
  static const demandTables = <String>['demand_parts', 'demand_orders'];

  Uint8List write() {
    final archive = Archive();
    void add(String name, Object? content) {
      final bytes = utf8.encode(
        const JsonEncoder.withIndent('  ').convert(content),
      );
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    add(manifestEntry, manifest.toJson());
    add(studyEntry, study);
    add(targetsEntry, targets.toJson());
    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  static FlowTemplate read(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    Map<String, dynamic> entry(String name) {
      final file = archive.findFile(name);
      if (file == null) {
        throw DocumentFormatException(
          'This file is not a FlowMap template: $name is missing.',
        );
      }
      return jsonDecode(utf8.decode(file.content as List<int>))
          as Map<String, dynamic>;
    }

    final manifest = TemplateManifest.fromJson(entry(manifestEntry));
    final rawStudy = entry(studyEntry);
    return FlowTemplate(
      manifest: manifest,
      study: {
        for (final table in rawStudy.entries)
          table.key: [
            for (final row in table.value as List)
              (row as Map<String, dynamic>).cast<String, Object?>(),
          ],
      },
      targets: TemplateTargets.fromJson(entry(targetsEntry)),
    );
  }

  /// Reads one study out of an open database, with everything it points at
  /// described by name.
  static Future<FlowTemplate> fromDatabase(
    GeneratedDatabase db, {
    required String studyId,
    required bool includeDemand,
  }) async {
    Future<List<Map<String, Object?>>> rows(String sql) async => [
      for (final row in await db.customSelect(sql).get())
        Map<String, Object?>.from(row.data),
    ];

    final study = <String, List<Map<String, Object?>>>{
      'studies': await rows("SELECT * FROM studies WHERE id = '$studyId'"),
      'flow_nodes': await rows(
        "SELECT * FROM flow_nodes WHERE study_id = '$studyId'",
      ),
      'flow_annotations': await rows(
        "SELECT * FROM flow_annotations WHERE study_id = '$studyId'",
      ),
      'demand_parts': includeDemand
          ? await rows("SELECT * FROM demand_parts WHERE study_id = '$studyId'")
          : const [],
      'demand_orders': includeDemand
          ? await rows("SELECT * FROM demand_orders WHERE study_id = '$studyId'")
          : const [],
      // Process times are keyed by node since v24, so they belong to the flow
      // rather than to the demand — but a time is *per part*, so without the
      // parts there is nothing for them to hang off.
      'part_process_times': includeDemand
          ? await rows(
              'SELECT * FROM part_process_times WHERE part_id IN '
              "(SELECT id FROM demand_parts WHERE study_id = '$studyId')",
            )
          : const [],
    };

    final targets = await TemplateTargets.describe(db, study['flow_nodes']!,
        studyRow: study['studies']!.single);

    return FlowTemplate(
      manifest: TemplateManifest(
        format: TemplateManifest.currentFormat,
        appVersion: kBuildLabel,
        schemaVersion: db.schemaVersion,
        studyName: study['studies']!.single['name']! as String,
        cellName: targets.cellName,
        lineName: targets.lineName,
        includesDemand: includeDemand,
        written: DateTime.now(),
        counts: {
          for (final entry in study.entries)
            if (entry.value.isNotEmpty) entry.key: entry.value.length,
        },
      ),
      study: study,
      targets: targets,
    );
  }
}

/// What a template's flow points at, by name.
///
/// **A dispatch target is a workcenter xor a pool** (#23), so both kinds are
/// described here and both are matched the same way on arrival: by name, and
/// created when missing — types before workcenters, workcenters before the
/// pools that hold them.
class TemplateTargets {
  const TemplateTargets({
    required this.workcenters,
    required this.pools,
    required this.cellName,
    required this.lineName,
  });

  /// Workcenter id as it was → what to look for on the far side.
  final Map<String, TargetRef> workcenters;

  /// Pool id as it was → its name and the names of its members.
  final Map<String, PoolRef> pools;

  /// The cell and line the study sat on. A study is written `name (cell · line)`
  /// and is neither ([#29](https://github.com/matheus-sancha/FlowMap/issues/29)),
  /// so both have to travel or the applied study cannot say where it is.
  final String? cellName;
  final String? lineName;

  static Future<TemplateTargets> describe(
    GeneratedDatabase db,
    List<Map<String, Object?>> flowNodes, {
    required Map<String, Object?> studyRow,
  }) async {
    final workcenterIds = <String>{
      for (final node in flowNodes)
        if (node['workcenter_id'] case final String id) id,
      // The pace setter is a dispatch target too, and is on the study's own row
      // rather than on a step — a third binding site #23 did not name.
      if (studyRow['pace_setter_target_id'] case final String id) id,
    };
    final poolIds = <String>{
      for (final node in flowNodes)
        if (node['pool_id'] case final String id) id,
    };

    Future<List<Map<String, Object?>>> q(String sql) async => [
      for (final row in await db.customSelect(sql).get())
        Map<String, Object?>.from(row.data),
    ];

    final workcenters = <String, TargetRef>{};
    for (final id in workcenterIds) {
      final rows = await q(
        'SELECT w.id, w.name, t.name AS type_name FROM workcenters w '
        "LEFT JOIN workcenter_types t ON t.id = w.type_id WHERE w.id = '$id'",
      );
      if (rows.isEmpty) continue;
      workcenters[id] = TargetRef(
        name: rows.single['name']! as String,
        typeName: rows.single['type_name'] as String?,
      );
    }

    final pools = <String, PoolRef>{};
    for (final id in poolIds) {
      final rows = await q(
        "SELECT name FROM workcenter_pools WHERE id = '$id'",
      );
      if (rows.isEmpty) continue;
      final members = await q(
        'SELECT w.name FROM workcenter_pool_members m '
        'JOIN workcenters w ON w.id = m.workcenter_id '
        "WHERE m.pool_id = '$id'",
      );
      pools[id] = PoolRef(
        name: rows.single['name']! as String,
        memberNames: [for (final m in members) m['name']! as String],
      );
    }

    final cell = studyRow['production_cell_id'];
    final line = studyRow['production_line_id'];
    final cellRows = cell is String
        ? await q("SELECT name FROM production_cells WHERE id = '$cell'")
        : const <Map<String, Object?>>[];
    final lineRows = line is String
        ? await q("SELECT name FROM production_lines WHERE id = '$line'")
        : const <Map<String, Object?>>[];

    return TemplateTargets(
      workcenters: workcenters,
      pools: pools,
      cellName: cellRows.isEmpty ? null : cellRows.single['name'] as String?,
      lineName: lineRows.isEmpty ? null : lineRows.single['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'workcenters': {
      for (final entry in workcenters.entries) entry.key: entry.value.toJson(),
    },
    'pools': {
      for (final entry in pools.entries) entry.key: entry.value.toJson(),
    },
    'cell': cellName,
    'line': lineName,
  };

  static TemplateTargets fromJson(Map<String, dynamic> json) => TemplateTargets(
    workcenters: {
      for (final entry in (json['workcenters'] as Map? ?? {}).entries)
        entry.key as String:
            TargetRef.fromJson((entry.value as Map).cast<String, dynamic>()),
    },
    pools: {
      for (final entry in (json['pools'] as Map? ?? {}).entries)
        entry.key as String:
            PoolRef.fromJson((entry.value as Map).cast<String, dynamic>()),
    },
    cellName: json['cell'] as String?,
    lineName: json['line'] as String?,
  );
}

/// A workcenter to look for on the far side.
class TargetRef {
  const TargetRef({required this.name, required this.typeName});

  final String name;

  /// **The type does not disambiguate** — on the live plant 42 workcenters have
  /// 42 distinct names *and* 42 distinct name+type pairs (#23). It travels so a
  /// workcenter that has to be **created** arrives with the right type, and so
  /// the picker can filter when a human is asked.
  final String? typeName;

  Map<String, dynamic> toJson() => {'name': name, 'type': typeName};
  static TargetRef fromJson(Map<String, dynamic> json) =>
      TargetRef(name: json['name'] as String, typeName: json['type'] as String?);
}

/// A pool to look for, and what it holds.
class PoolRef {
  const PoolRef({required this.name, required this.memberNames});

  final String name;

  /// **Members are resolved before the pool** (#23): a pool created over a
  /// subset would land a pool of three as a pool of one and change dispatch
  /// without saying so.
  final List<String> memberNames;

  Map<String, dynamic> toJson() => {'name': name, 'members': memberNames};
  static PoolRef fromJson(Map<String, dynamic> json) => PoolRef(
    name: json['name'] as String,
    memberNames: [for (final m in json['members'] as List? ?? []) m as String],
  );
}

/// What a template says about itself.
class TemplateManifest {
  const TemplateManifest({
    required this.format,
    required this.appVersion,
    required this.schemaVersion,
    required this.studyName,
    required this.cellName,
    required this.lineName,
    required this.includesDemand,
    required this.written,
    required this.counts,
  });

  static const int currentFormat = 1;

  final int format;
  final String appVersion;
  final int schemaVersion;
  final String studyName;
  final String? cellName;
  final String? lineName;
  final bool includesDemand;
  final DateTime written;
  final Map<String, int> counts;

  bool get isFromNewerFormat => format > currentFormat;

  /// How a study is written wherever it stands beside a cell or a line (#29).
  String get describe => cellName == null && lineName == null
      ? studyName
      : '$studyName (${[cellName, lineName].whereType<String>().join(' · ')})';

  Map<String, dynamic> toJson() => {
    'format': format,
    'kind': 'template',
    'app_version': appVersion,
    'schema': schemaVersion,
    'study': {'name': studyName, 'cell': cellName, 'line': lineName},
    'includes_demand': includesDemand,
    'written': written.toIso8601String(),
    'counts': counts,
  };

  static TemplateManifest fromJson(Map<String, dynamic> json) {
    final study = json['study'];
    if (json['format'] is! int || study is! Map) {
      throw const DocumentFormatException(
        'This file is not a FlowMap template.',
      );
    }
    return TemplateManifest(
      format: json['format'] as int,
      appVersion: json['app_version'] as String? ?? 'unknown',
      schemaVersion: json['schema'] as int? ?? 0,
      studyName: study['name'] as String? ?? 'Untitled',
      cellName: study['cell'] as String?,
      lineName: study['line'] as String?,
      includesDemand: json['includes_demand'] as bool? ?? false,
      written:
          DateTime.tryParse(json['written'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      counts: {
        for (final entry in (json['counts'] as Map? ?? {}).entries)
          entry.key as String: entry.value as int,
      },
    );
  }
}
