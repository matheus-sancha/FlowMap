import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/documents/data/flowmap_document.dart';
import 'package:flutter_test/flutter_test.dart';

/// A document is the unit of work now (#37), so what it can lose is what the
/// user can lose.
///
/// The claims here are about completeness rather than about shape: that every
/// table is accounted for, that a column added to the schema is carried without
/// anyone remembering it, and that a file the app cannot read is refused with a
/// sentence rather than a stack trace.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// The smallest plant that exercises every plant table, plus one project.
  Future<void> seed({String projectId = 'proj-1'}) async {
    const now = 0;
    await db.customStatement('PRAGMA foreign_keys = OFF');
    Future<void> run(String sql) => db.customStatement(sql);

    await run("INSERT INTO plants (id,name,created_at,updated_at) "
        "VALUES ('plant-1','Planta 1',$now,$now)");
    await run("INSERT INTO production_cells (id,plant_id,name,created_at,updated_at) "
        "VALUES ('cell-1','plant-1','Célula 11',$now,$now)");
    await run("INSERT INTO production_lines (id,cell_id,name,created_at,updated_at) "
        "VALUES ('line-1','cell-1','Fluxo 11B',$now,$now)");
    await run("INSERT INTO workcenter_types (id,name,is_built_in,created_at) "
        "VALUES ('type-1','Fixture Type',0,$now)");
    await run("INSERT INTO workcenters (id,plant_id,type_id,name,parallel_capacity,created_at,updated_at) "
        "VALUES ('wc-1','plant-1','type-1','CLAD07',1,$now,$now)");
    await run("INSERT INTO workcenter_lines (workcenter_id,line_id,created_at) "
        "VALUES ('wc-1','line-1',$now)");
    await run("INSERT INTO workcenter_pools (id,plant_id,name,created_at,updated_at) "
        "VALUES ('pool-1','plant-1','CLAD Pool',$now,$now)");
    await run("INSERT INTO workcenter_pool_members (pool_id,workcenter_id,created_at) "
        "VALUES ('pool-1','wc-1',$now)");
    await run("INSERT INTO shift_patterns (id,name,cycle_type,working_weekdays,created_at,updated_at) "
        "VALUES ('sp-1','Fixture Pattern','fixedWeekly',62,$now,$now)");
    await run("INSERT INTO pattern_shifts (id,pattern_id,label,position,start_minute,end_minute,break_seconds) "
        "VALUES ('sh-1','sp-1','A',0,345,913,2400)");

    await run("INSERT INTO projects (id,name,plant_id,shift_pattern_id,float_red_days,"
        "float_green_days,occupation_amber_pct,occupation_red_pct,created_at,updated_at) "
        "VALUES ('$projectId','VSM 2026 Q1','plant-1','sp-1',0,30,85,100,$now,$now)");
    await run("INSERT INTO studies (id,project_id,production_cell_id,production_line_id,name,"
        "include_in_simulation,start_buffer_days,created_at,updated_at) "
        "VALUES ('study-1','$projectId','cell-1','line-1','Célula 11B',1,0,$now,$now)");
    await run("INSERT INTO flow_nodes (id,study_id,position,kind,workcenter_id,changeover_seconds,"
        "inventory_uses_working_time,created_at,updated_at) "
        "VALUES ('node-1','study-1',0,'step','wc-1',1800,0,$now,$now)");
    await run("INSERT INTO demand_parts (id,study_id,part_number,created_at,updated_at) "
        "VALUES ('part-1','study-1','P-100',$now,$now)");
    await run("INSERT INTO part_process_times (part_id,node_id,seconds) "
        "VALUES ('part-1','node-1',3600)");
    await run("INSERT INTO project_queues (project_id,target_id,created_at,updated_at) "
        "VALUES ('$projectId','wc-1',$now,$now)");
    await run("INSERT INTO takt_periods (id,project_id,production_line_id,start_date,end_date,"
        "takt_value,takt_unit,created_at,updated_at) "
        "VALUES ('takt-1','$projectId','line-1',$now,$now,1.0,'days',$now,$now)");
    await run("INSERT INTO workcenter_schedule_periods (id,project_id,workcenter_id,start_date,"
        "end_date,operators_per_shift,availability,rework,created_at,updated_at) "
        "VALUES ('wsp-1','$projectId','wc-1',$now,$now,'1',0.74,0.0,$now,$now)");
  }

  Future<FlowmapDocument> capture() => FlowmapDocument.fromDatabase(
    db,
    projectId: 'proj-1',
    projectName: 'VSM 2026 Q1',
  );

  test('every table in the database is accounted for', () async {
    // **The guard that matters most.** A table added to the schema and to
    // neither list would be silently absent from every document — data the user
    // can lose without a single test going red. So the lists are checked
    // against the database rather than trusted.
    final actual = {for (final t in db.allTables) t.actualTableName};
    final known = FlowmapDocument.knownTables;

    expect(
      actual.difference(known),
      isEmpty,
      reason: 'a table exists that no document list mentions — decide whether '
          'it travels (plantTables/projectTables) or does not (excludedTables)',
    );
    expect(
      known.difference(actual),
      isEmpty,
      reason: 'a document list names a table the database does not have',
    );
  });

  test('a round trip loses no row and no column', () async {
    await seed();
    const encoder = JsonEncoder();
    final before = await capture();
    final after = FlowmapDocument.read(before.write());

    expect(after.rowCount, before.rowCount);
    for (final table in [
      ...FlowmapDocument.plantTables,
      ...FlowmapDocument.projectTables,
    ]) {
      final source = before.plant[table] ?? before.project[table]!;
      final landed = after.plant[table] ?? after.project[table]!;
      expect(landed.length, source.length, reason: '$table lost rows');
      // Column by column, so a value silently dropped in the zip fails here and
      // not in some later feature that happened to read it.
      expect(encoder.convert(landed), encoder.convert(source), reason: table);
    }
  });

  test('a row carries every column the table has', () async {
    await seed();
    final doc = await capture();

    // Not a fixed list: the columns the database reports. A schema that grows a
    // column grows this assertion with it, which is the whole reason rows are
    // read with SELECT * rather than field by field (#30).
    for (final table in db.allTables) {
      final name = table.actualTableName;
      final rows = doc.plant[name] ?? doc.project[name];
      if (rows == null || rows.isEmpty) continue;
      final expected = {for (final c in table.$columns) c.name};
      expect(rows.first.keys.toSet(), expected, reason: name);
    }
  });

  test('the plant travels and the runs do not', () async {
    await seed();
    final doc = await capture();

    // The 135-against-630 and 635× arithmetic of #37, asserted rather than
    // assumed: every plant table is present, and nothing about a run is.
    for (final table in FlowmapDocument.plantTables) {
      expect(doc.plant.containsKey(table), isTrue, reason: table);
    }
    expect(doc.plant['workcenters'], hasLength(1));
    expect(
      {...doc.plant.keys, ...doc.project.keys}
          .where((t) => t.startsWith('simulation_run')),
      isEmpty,
    );
    expect({...doc.plant.keys, ...doc.project.keys}, isNot(contains('app_settings')));
  });

  test('a document holds one project, not the database', () async {
    await seed();
    await db.customStatement(
      "INSERT INTO projects (id,name,plant_id,shift_pattern_id,float_red_days,"
      "float_green_days,occupation_amber_pct,occupation_red_pct,created_at,updated_at) "
      "VALUES ('proj-2','Other','plant-1','sp-1',0,30,85,100,0,0)",
    );
    await db.customStatement(
      "INSERT INTO studies (id,project_id,production_cell_id,production_line_id,name,"
      "include_in_simulation,start_buffer_days,created_at,updated_at) "
      "VALUES ('study-2','proj-2','cell-1','line-1','Elsewhere',0,0,0,0)",
    );

    final doc = await capture();
    expect(doc.project['projects'], hasLength(1));
    expect(doc.project['projects']!.single['id'], 'proj-1');
    expect(doc.project['studies'], hasLength(1));
    expect(doc.project['studies']!.single['name'], 'Célula 11B');
    // The plant is shared, so it is *not* filtered — both projects reference it.
    expect(doc.plant['workcenters'], hasLength(1));
  });

  test('the manifest can be read without touching the payloads', () async {
    await seed();
    final bytes = (await capture()).write();
    final manifest = FlowmapDocument.readManifest(bytes);

    expect(manifest.format, DocumentManifest.currentFormat);
    expect(manifest.projectName, 'VSM 2026 Q1');
    expect(manifest.schemaVersion, db.schemaVersion);
    expect(manifest.counts['workcenters'], 1);
    expect(manifest.isFromNewerFormat, isFalse);
  });

  test('a document from a newer format is recognised, not parsed', () async {
    await seed();
    final doc = await capture();
    final archive = ZipDecoder().decodeBytes(doc.write());
    final rebuilt = Archive();
    for (final file in archive.files) {
      if (file.name == FlowmapDocument.manifestEntry) {
        final json = jsonDecode(utf8.decode(file.content as List<int>))
            as Map<String, dynamic>;
        json['format'] = DocumentManifest.currentFormat + 1;
        final bytes = utf8.encode(jsonEncode(json));
        rebuilt.addFile(ArchiveFile(file.name, bytes.length, bytes));
      } else {
        // Payloads deliberately replaced with rubbish: reading the manifest
        // must not depend on them being parseable.
        final bytes = utf8.encode('not json at all');
        rebuilt.addFile(ArchiveFile(file.name, bytes.length, bytes));
      }
    }

    final manifest = FlowmapDocument.readManifest(
      Uint8List.fromList(ZipEncoder().encode(rebuilt)!),
    );
    expect(manifest.isFromNewerFormat, isTrue);
  });

  test('a file that is not a document is refused with a sentence', () {
    expect(
      () => FlowmapDocument.readManifest(
        Uint8List.fromList(utf8.encode('this is not a zip')),
      ),
      throwsA(anything),
    );

    final empty = Uint8List.fromList(ZipEncoder().encode(Archive())!);
    expect(
      () => FlowmapDocument.readManifest(empty),
      throwsA(
        isA<DocumentFormatException>().having(
          (e) => e.message,
          'message',
          contains('not a FlowMap document'),
        ),
      ),
    );
  });

  test('an incomplete document names what is missing', () async {
    await seed();
    final doc = await capture();
    final archive = ZipDecoder().decodeBytes(doc.write());
    final rebuilt = Archive();
    for (final file in archive.files) {
      if (file.name == FlowmapDocument.plantEntry) continue;
      rebuilt.addFile(file);
    }

    expect(
      () => FlowmapDocument.read(
        Uint8List.fromList(ZipEncoder().encode(rebuilt)!),
      ),
      throwsA(
        isA<DocumentFormatException>().having(
          (e) => e.message,
          'message',
          contains(FlowmapDocument.plantEntry),
        ),
      ),
    );
  });

  test('an empty project is a document, not a failure', () async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement(
      "INSERT INTO plants (id,name,created_at,updated_at) VALUES ('p','P',0,0)",
    );
    await db.customStatement(
      "INSERT INTO shift_patterns (id,name,cycle_type,working_weekdays,created_at,updated_at) "
      "VALUES ('sp','Fixture Pattern','fixedWeekly',62,0,0)",
    );
    await db.customStatement(
      "INSERT INTO projects (id,name,plant_id,shift_pattern_id,float_red_days,"
      "float_green_days,occupation_amber_pct,occupation_red_pct,created_at,updated_at) "
      "VALUES ('proj-1','Empty','p','sp',0,30,85,100,0,0)",
    );

    final doc = await capture();
    final back = FlowmapDocument.read(doc.write());
    expect(back.project['studies'], isEmpty);
    expect(back.project['projects'], hasLength(1));
    expect(back.manifest.projectName, 'VSM 2026 Q1');
  });
}
