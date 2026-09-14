import 'package:drift/native.dart';
import 'package:flowmap/src/data/database/database.dart';
import 'package:flowmap/src/features/documents/data/document_store.dart';
import 'package:flowmap/src/features/documents/data/flowmap_document.dart';
import 'package:flowmap/src/features/documents/data/save_as.dart';
import 'package:flutter_test/flutter_test.dart';

/// Save As is how a new project gets a plant, since a new document starts
/// empty — so the thing to get right is that the copy is genuinely *yours*
/// rather than a second window onto somebody else's project.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<FlowmapDocument> reference() async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    Future<void> run(String sql) => db.customStatement(sql);
    await run("INSERT INTO plants (id,name,created_at,updated_at) "
        "VALUES ('plant-1','Planta',0,0)");
    await run("INSERT INTO production_cells (id,plant_id,name,created_at,updated_at) "
        "VALUES ('cell-1','plant-1','Célula 11',0,0)");
    await run("INSERT INTO production_lines (id,cell_id,name,created_at,updated_at) "
        "VALUES ('line-1','cell-1','Fluxo 11B',0,0)");
    await run("INSERT INTO workcenter_types (id,name,is_built_in,created_at) "
        "VALUES ('type-1','Fixture Type',0,0)");
    await run("INSERT INTO workcenters (id,plant_id,type_id,name,parallel_capacity,"
        "created_at,updated_at) VALUES ('wc-1','plant-1','type-1','CLAD07',1,0,0)");
    await run("INSERT INTO shift_patterns (id,name,cycle_type,working_weekdays,"
        "created_at,updated_at) VALUES ('sp-1','Fixture','fixedWeekly',62,0,0)");
    await run("INSERT INTO projects (id,name,plant_id,shift_pattern_id,float_red_days,"
        "float_green_days,occupation_amber_pct,occupation_red_pct,created_at,updated_at) "
        "VALUES ('proj-A','Reference','plant-1','sp-1',0,30,85,100,0,0)");
    await run("INSERT INTO studies (id,project_id,production_cell_id,production_line_id,"
        "name,include_in_simulation,start_buffer_days,created_at,updated_at) "
        "VALUES ('study-1','proj-A','cell-1','line-1','Célula 11B',1,0,0,0)");
    await run("INSERT INTO project_queues (project_id,target_id,created_at,updated_at) "
        "VALUES ('proj-A','wc-1',0,0)");
    await run("INSERT INTO takt_periods (id,project_id,production_line_id,start_date,"
        "end_date,takt_value,takt_unit,created_at,updated_at) "
        "VALUES ('takt-1','proj-A','line-1',0,0,1.0,'days',0,0)");
    await run("INSERT INTO workcenter_schedule_periods (id,project_id,workcenter_id,"
        "start_date,end_date,operators_per_shift,availability,rework,created_at,updated_at) "
        "VALUES ('wsp-1','proj-A','wc-1',0,0,'1',0.74,0.0,0,0)");
    await db.customStatement('PRAGMA foreign_keys = ON');

    return DocumentStore(db).capture(
      projectId: 'proj-A',
      projectName: 'Reference',
    );
  }

  FlowmapDocument copyOf(FlowmapDocument doc) => SaveAs.rename(
    doc,
    newProjectId: 'proj-B',
    newProjectName: 'Célula 12',
    appVersion: 'test',
  );

  test('the copy is a different project', () async {
    final copy = copyOf(await reference());

    expect(copy.manifest.projectId, 'proj-B');
    expect(copy.manifest.projectName, 'Célula 12');
    expect(copy.project['projects']!.single['id'], 'proj-B');
    expect(copy.project['projects']!.single['name'], 'Célula 12');
  });

  test('every reference to the old project follows it', () async {
    // The remap is by value rather than by naming each column, so a table added
    // later that keys on the project is carried without anyone remembering.
    final copy = copyOf(await reference());

    expect(copy.project['studies']!.single['project_id'], 'proj-B');
    expect(copy.project['project_queues']!.single['project_id'], 'proj-B');
    expect(copy.project['takt_periods']!.single['project_id'], 'proj-B');
    expect(
      copy.project['workcenter_schedule_periods']!.single['project_id'],
      'proj-B',
    );

    // And nothing anywhere still points at the original.
    final everything = copy.project.values
        .expand((rows) => rows)
        .expand((row) => row.values)
        .toList();
    expect(everything, isNot(contains('proj-A')));
  });

  test('the plant travels unchanged', () async {
    // Same physical plant, same ids: workcenters, types, cells, lines and
    // patterns are not the project and nothing outside the document names them.
    final original = await reference();
    final copy = copyOf(original);

    expect(copy.plant, original.plant);
    expect(copy.plant['workcenters']!.single['id'], 'wc-1');
    expect(copy.plant['workcenters']!.single['name'], 'CLAD07');
  });

  test('the original is untouched', () async {
    final original = await reference();
    final before = original.project['projects']!.single['id'];

    copyOf(original);

    expect(original.project['projects']!.single['id'], before);
    expect(original.manifest.projectId, 'proj-A');
  });

  test('the copy loads, and leaves nothing dangling', () async {
    // The real test of the remap: every foreign key inside it still resolves.
    final copy = copyOf(await reference());
    final store = DocumentStore(db);

    await store.load(copy);

    expect(await store.checkIntegrity(), isEmpty);
    final projects = await db.select(db.projects).get();
    expect(projects.single.id, 'proj-B');
    final studies = await db.select(db.studies).get();
    expect(studies.single.projectId, 'proj-B');
  });

  test('a round trip through the file keeps the new identity', () async {
    final copy = copyOf(await reference());
    final reread = FlowmapDocument.read(copy.write());

    expect(reread.manifest.projectId, 'proj-B');
    expect(reread.project['studies']!.single['project_id'], 'proj-B');
  });

  test('the file name suggests the project name', () {
    expect(SaveAs.projectNameFor('Célula 12.flowmap'), 'Célula 12');
    expect(SaveAs.projectNameFor('.flowmap'), 'Project');
  });
}
