import 'package:drift/drift.dart';

import '../../../data/database/database.dart';
import '../../../data/database/enums.dart';
import '../../demand/data/demand_repository.dart';

/// A study and its flow, together.
///
/// The flow spine is not a separate repository because it has no life outside
/// its study: every read is scoped to one, and the structural edits — insert,
/// reorder, delete — have to renumber siblings in the same transaction that
/// changes one row.
class StudiesRepository {
  /// The demand repository is built here rather than injected through a
  /// provider: demand depends on the flow view for its columns, and a provider
  /// dependency the other way would close a cycle. Both wrap the same database
  /// and hold no state, so a second instance costs nothing.
  StudiesRepository(AppDatabase db)
    : _db = db,
      _demand = DemandRepository(db);

  final AppDatabase _db;
  final DemandRepository _demand;

  // --- Studies ------------------------------------------------------------

  Stream<List<Study>> watchStudies(String projectId) =>
      (_db.select(_db.studies)
            ..where((s) => s.projectId.equals(projectId))
            ..orderBy([(s) => OrderingTerm(expression: s.name)]))
          .watch();

  Stream<Study?> watchStudy(String id) => (_db.select(
    _db.studies,
  )..where((s) => s.id.equals(id))).watchSingleOrNull();

  /// The studies flagged to take part in the next run (DESIGN.md §10.1).
  ///
  /// At most one per line, which [setIncludedInSimulation] enforces at the
  /// moment of the edit rather than the run checking for it — so the user
  /// always sees which study is selected instead of finding out when they
  /// press Simulate.
  Stream<List<Study>> watchFlaggedStudies(String projectId) =>
      _flaggedQuery(projectId).watch();

  Future<List<Study>> loadFlaggedStudies(String projectId) =>
      _flaggedQuery(projectId).get();

  SimpleSelectStatement<$StudiesTable, Study> _flaggedQuery(String projectId) =>
      _db.select(_db.studies)
        ..where(
          (s) =>
              s.projectId.equals(projectId) &
              s.includeInSimulation.equals(true),
        )
        ..orderBy([(s) => OrderingTerm(expression: s.name)]);

  Future<Study?> loadStudy(String id) => (_db.select(
    _db.studies,
  )..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<String> createStudy({
    required String projectId,
    required String productionCellId,
    required String productionLineId,
    required String name,
  }) async {
    final id = newId();
    final now = DateTime.now();
    await _db
        .into(_db.studies)
        .insert(
          StudiesCompanion.insert(
            id: id,
            projectId: projectId,
            productionCellId: productionCellId,
            productionLineId: productionLineId,
            name: name,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> updateStudy(
    String id, {
    required String name,
    String? supplierName,
    String? customerName,
    int? wipCap,
    int? startBufferDays,
    String? paceSetterTargetId,
    bool paceSetterGiven = false,
    String? notes,
    // **The end stock is deliberately not here** (§7.3). This method writes
    // every field it is given unconditionally, so each caller has to read the
    // whole study back and pass it through — six call sites that a seventh
    // field would each have to learn about, and one of them already carries a
    // comment about the bug that shape caused. [setFlowEnd] writes those two
    // columns instead.
  }) => (_db.update(_db.studies)..where((s) => s.id.equals(id))).write(
    StudiesCompanion(
      name: Value(name),
      supplierName: Value(supplierName),
      customerName: Value(customerName),
      wipCap: Value(wipCap),
      startBufferDays: startBufferDays == null
          ? const Value.absent()
          : Value(startBufferDays),
      // Null is a real value here — "derive it" — so absence has to be said
      // separately, or every caller that is not editing the pacemaker would
      // silently clear it. The same shape `lineIds` uses on a workcenter.
      paceSetterTargetId: paceSetterGiven
          ? Value(paceSetterTargetId)
          : const Value.absent(),
      notes: Value(notes),
      updatedAt: Value(DateTime.now()),
    ),
  );

  /// Names one end of the flow and records the stock standing there (§7.3).
  ///
  /// **Its own method rather than four more arguments on [updateStudy]**, and
  /// the reason is that method's own history: it writes every field it is
  /// given unconditionally, so each of its six callers has to read the whole
  /// study back and pass it through, and `flow_tab.dart` carries a comment
  /// about the bug that shape already caused once. An endpoint edit touches
  /// exactly two columns at one end, and this says so — the other end and every
  /// other field are absent, so nothing else can be clobbered by a caller that
  /// forgot to mention it.
  ///
  /// A null [name] restores the default label; a null [stock] means *nobody has
  /// counted*, which is not the same as a counted zero (§7.3).
  Future<void> setFlowEnd(
    String studyId, {
    required bool inbound,
    required String? name,
    required int? stock,
  }) => (_db.update(_db.studies)..where((s) => s.id.equals(studyId))).write(
    StudiesCompanion(
      supplierName: inbound ? Value(name) : const Value.absent(),
      inboundStock: inbound ? Value(stock) : const Value.absent(),
      customerName: inbound ? const Value.absent() : Value(name),
      outboundStock: inbound ? const Value.absent() : Value(stock),
      updatedAt: Value(DateTime.now()),
    ),
  );

  /// Flags a study for the next simulation run, clearing any sibling on the
  /// same production line.
  ///
  /// The "at most one per line" rule is enforced here rather than checked
  /// before a run: doing it at the moment of the edit means the user always
  /// sees which study is actually selected, instead of finding out when they
  /// press Simulate.
  Future<void> setIncludedInSimulation(String studyId, bool included) =>
      _db.transaction(() async {
        final study = await loadStudy(studyId);
        if (study == null) return;
        if (included) {
          await (_db.update(_db.studies)..where(
                (s) =>
                    s.projectId.equals(study.projectId) &
                    s.productionLineId.equals(study.productionLineId) &
                    s.id.equals(studyId).not(),
              ))
              .write(const StudiesCompanion(includeInSimulation: Value(false)));
        }
        await (_db.update(
          _db.studies,
        )..where((s) => s.id.equals(studyId))).write(
          StudiesCompanion(
            includeInSimulation: Value(included),
            updatedAt: Value(DateTime.now()),
          ),
        );
      });

  Future<void> deleteStudy(String id) =>
      (_db.delete(_db.studies)..where((s) => s.id.equals(id))).go();

  /// Deep-copies a study inside its project — the scenario operation
  /// (DESIGN.md §10.1).
  ///
  /// Ids are regenerated but every reference is kept: a duplicate targets the
  /// same workcenters, which is the point. The copy is never included in a
  /// simulation, because two flagged studies on one line is exactly the state
  /// the rule above forbids.
  Future<String> duplicateStudy(String id, {required String newName}) =>
      _db.transaction(() async {
        final source = await loadStudy(id);
        if (source == null) throw StateError('No study $id to duplicate');

        final copyId = newId();
        final now = DateTime.now();
        await _db
            .into(_db.studies)
            .insert(
              StudiesCompanion.insert(
                id: copyId,
                projectId: source.projectId,
                productionCellId: source.productionCellId,
                productionLineId: source.productionLineId,
                name: newName,
                includeInSimulation: const Value(false),
                wipCap: Value(source.wipCap),
                supplierName: Value(source.supplierName),
                customerName: Value(source.customerName),
                // §2.6b found this method silently dropping a column that had
                // been added without it, and the same test shape asks after
                // each of these.
                inboundStock: Value(source.inboundStock),
                outboundStock: Value(source.outboundStock),
                notes: Value(source.notes),
                createdAt: now,
                updatedAt: now,
              ),
            );

        final nodes = await loadNodes(id);
        // **Kept rather than generated inline**, because §9 keys a process
        // time by its node: the demand copy below needs to know which new node
        // each old one became, and a copy that reused the source's ids would
        // hang every time off the original study's steps.
        final nodeIds = {for (final node in nodes) node.id: newId()};

        await _db.batch((b) {
          for (final node in nodes) {
            b.insert(
              _db.flowNodes,
              FlowNodesCompanion.insert(
                id: nodeIds[node.id]!,
                studyId: copyId,
                position: node.position,
                kind: node.kind,
                workcenterId: Value(node.workcenterId),
                poolId: Value(node.poolId),
                changeoverSeconds: Value(node.changeoverSeconds),
                // §2.6b found this method silently dropping `batch_number` and
                // it had been doing so since the column arrived. Every field a
                // node carries is copied, and the test asks after each.
                setupValue: Value(node.setupValue),
                setupUnit: Value(node.setupUnit),
                teardownValue: Value(node.teardownValue),
                teardownUnit: Value(node.teardownUnit),
                samePartPercent: Value(node.samePartPercent),
                balanceDisabled: Value(node.balanceDisabled),
                equivalentValue: Value(node.equivalentValue),
                equivalentUnit: Value(node.equivalentUnit),
                inventoryMode: Value(node.inventoryMode),
                inventoryQuantity: Value(node.inventoryQuantity),
                inventorySeconds: Value(node.inventorySeconds),
                inventoryUnit: Value(node.inventoryUnit),
                inventoryUsesWorkingTime: Value(node.inventoryUsesWorkingTime),
                notes: Value(node.notes),
                createdAt: now,
                updatedAt: now,
              ),
            );
          }
        });

        final annotations = await (_db.select(
          _db.flowAnnotations,
        )..where((a) => a.studyId.equals(id))).get();
        await _db.batch((b) {
          for (final annotation in annotations) {
            b.insert(
              _db.flowAnnotations,
              FlowAnnotationsCompanion.insert(
                id: newId(),
                studyId: copyId,
                symbol: annotation.symbol,
                x: annotation.x,
                y: annotation.y,
                caption: Value(annotation.caption),
                createdAt: now,
                updatedAt: now,
              ),
            );
          }
        });

        // The demand goes with the scenario. A duplicate exists to be
        // re-sequenced against the same orders (§6.3, §10.1); one that arrived
        // empty would have to be re-imported before it could be compared with
        // the study it came from.
        await _demand.copyDemandInto(
          fromStudyId: id,
          toStudyId: copyId,
          nodeIds: nodeIds,
        );

        return copyId;
      });

  // --- The flow spine -----------------------------------------------------

  Stream<List<FlowNode>> watchNodes(String studyId) =>
      (_db.select(_db.flowNodes)
            ..where((n) => n.studyId.equals(studyId))
            ..orderBy([(n) => OrderingTerm(expression: n.position)]))
          .watch();

  Future<List<FlowNode>> loadNodes(String studyId) =>
      (_db.select(_db.flowNodes)
            ..where((n) => n.studyId.equals(studyId))
            ..orderBy([(n) => OrderingTerm(expression: n.position)]))
          .get();

  /// Inserts a process step at [atPosition], pushing everything after it along.
  ///
  /// `atPosition` equal to the current length appends. Positions stay dense and
  /// zero-based after every structural edit, which is what lets the layout be
  /// derived from them without a sort key.
  Future<String> insertStep({
    required String studyId,
    required int atPosition,
    String? workcenterId,
    String? poolId,
    double? setupValue,
    TaktUnit? setupUnit,
    double? teardownValue,
    TaktUnit? teardownUnit,
    double? samePartPercent,
    bool? balanceDisabled,
    double? equivalentValue,
    TaktUnit? equivalentUnit,
    String? notes,
  }) => _insertNode(
    studyId: studyId,
    atPosition: atPosition,
    build: (id, position, now) => FlowNodesCompanion.insert(
      id: id,
      studyId: studyId,
      position: position,
      kind: FlowNodeKind.step,
      workcenterId: Value(workcenterId),
      poolId: Value(poolId),
      setupValue: Value(setupValue),
      setupUnit: Value(setupUnit),
      teardownValue: Value(teardownValue),
      teardownUnit: Value(teardownUnit),
      samePartPercent: Value(samePartPercent),
      balanceDisabled: Value(balanceDisabled),
      equivalentValue: Value(equivalentValue),
      equivalentUnit: Value(equivalentUnit),
      notes: Value(notes),
      createdAt: now,
      updatedAt: now,
    ),
  );

  // **Nothing constructs an inventory node** (§7.3). It used to be the second
  // kind on the spine, with its own name, discipline and capacity — and two
  // studies through one machine therefore had two of them. The queue belongs to
  // what a step targets now (`FlowQueuesRepository`), and the v19 fold folded
  // every node onto its target. The rows stay as the recovery path for a name
  // the fold discarded, so `FlowNodeKind.inventory` stays parseable; the writers
  // went, because a repository that can still make one is how the old model
  // comes back (§17.5).

  Future<String> _insertNode({
    required String studyId,
    required int atPosition,
    required FlowNodesCompanion Function(String id, int position, DateTime now)
    build,
  }) => _db.transaction(() async {
    final nodes = await loadNodes(studyId);
    final position = atPosition.clamp(0, nodes.length);
    final now = DateTime.now();

    // Shifted from the back so no intermediate state collides with the
    // (study, position) uniqueness constraint.
    for (var i = nodes.length - 1; i >= position; i--) {
      await (_db.update(_db.flowNodes)..where((n) => n.id.equals(nodes[i].id)))
          .write(FlowNodesCompanion(position: Value(i + 1)));
    }

    final id = newId();
    await _db.into(_db.flowNodes).insert(build(id, position, now));
    await _touchStudy(studyId);
    return id;
  });

  Future<void> updateStep(
    String nodeId, {
    String? workcenterId,
    String? poolId,
    double? setupValue,
    TaktUnit? setupUnit,
    double? teardownValue,
    TaktUnit? teardownUnit,
    double? samePartPercent,
    bool? balanceDisabled,
    double? equivalentValue,
    TaktUnit? equivalentUnit,
    String? notes,
  }) async {
    await (_db.update(_db.flowNodes)..where((n) => n.id.equals(nodeId))).write(
      FlowNodesCompanion(
        workcenterId: Value(workcenterId),
        poolId: Value(poolId),
        setupValue: Value(setupValue),
        setupUnit: Value(setupUnit),
        teardownValue: Value(teardownValue),
        teardownUnit: Value(teardownUnit),
        samePartPercent: Value(samePartPercent),
        balanceDisabled: Value(balanceDisabled),
        equivalentValue: Value(equivalentValue),
        equivalentUnit: Value(equivalentUnit),
        notes: Value(notes),
        updatedAt: Value(DateTime.now()),
      ),
    );
    await _touchStudyOfNode(nodeId);
  }

  /// Removes a node and closes the gap, so positions stay dense.
  Future<void> deleteNode(String studyId, String nodeId) => _db.transaction(
    () async {
      await (_db.delete(_db.flowNodes)..where((n) => n.id.equals(nodeId))).go();
      await _renumber(studyId);
      await _touchStudy(studyId);
    },
  );

  /// Moves the node at [from] to [to], keeping every other node's relative
  /// order — the drag gesture on the canvas.
  Future<void> moveNode(String studyId, int from, int to) =>
      _db.transaction(() async {
        final nodes = await loadNodes(studyId);
        if (from < 0 || from >= nodes.length) return;
        final target = to.clamp(0, nodes.length - 1);
        if (from == target) return;

        final reordered = [...nodes];
        reordered.insert(target, reordered.removeAt(from));

        // Parked out of range first: positions are unique per study, so a
        // straight rewrite would collide part-way through.
        for (var i = 0; i < reordered.length; i++) {
          await (_db.update(_db.flowNodes)
                ..where((n) => n.id.equals(reordered[i].id)))
              .write(FlowNodesCompanion(position: Value(-1 - i)));
        }
        for (var i = 0; i < reordered.length; i++) {
          await (_db.update(_db.flowNodes)
                ..where((n) => n.id.equals(reordered[i].id)))
              .write(FlowNodesCompanion(position: Value(i)));
        }
        await _touchStudy(studyId);
      });

  Future<void> _renumber(String studyId) async {
    final nodes = await loadNodes(studyId);
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i].position == i) continue;
      await (_db.update(_db.flowNodes)..where((n) => n.id.equals(nodes[i].id)))
          .write(FlowNodesCompanion(position: Value(i)));
    }
  }

  // --- The decorative layer -----------------------------------------------

  Stream<List<FlowAnnotation>> watchAnnotations(String studyId) => (_db.select(
    _db.flowAnnotations,
  )..where((a) => a.studyId.equals(studyId))).watch();

  Future<String> addAnnotation({
    required String studyId,
    required AnnotationSymbol symbol,
    required double x,
    required double y,
    String? caption,
  }) async {
    final id = newId();
    final now = DateTime.now();
    await _db
        .into(_db.flowAnnotations)
        .insert(
          FlowAnnotationsCompanion.insert(
            id: id,
            studyId: studyId,
            symbol: symbol,
            x: x,
            y: y,
            caption: Value(caption),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> moveAnnotation(String id, double x, double y) =>
      (_db.update(_db.flowAnnotations)..where((a) => a.id.equals(id))).write(
        FlowAnnotationsCompanion(
          x: Value(x),
          y: Value(y),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> updateAnnotationCaption(String id, String? caption) =>
      (_db.update(_db.flowAnnotations)..where((a) => a.id.equals(id))).write(
        FlowAnnotationsCompanion(
          caption: Value(caption),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> deleteAnnotation(String id) =>
      (_db.delete(_db.flowAnnotations)..where((a) => a.id.equals(id))).go();

  // --- Housekeeping -------------------------------------------------------

  Future<void> _touchStudy(String studyId) =>
      (_db.update(_db.studies)..where((s) => s.id.equals(studyId))).write(
        StudiesCompanion(updatedAt: Value(DateTime.now())),
      );

  Future<void> _touchStudyOfNode(String nodeId) async {
    final node = await (_db.select(
      _db.flowNodes,
    )..where((n) => n.id.equals(nodeId))).getSingleOrNull();
    if (node != null) await _touchStudy(node.studyId);
  }
}
