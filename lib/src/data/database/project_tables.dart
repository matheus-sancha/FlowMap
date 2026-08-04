import 'package:drift/drift.dart';

import 'enums.dart';
import 'tables.dart';

// Project-scoped data (DESIGN.md §3). Resources hold identity; everything that
// varies by project or by period lives here.
//
// Two storage conventions carried over from the resource tables:
//   * durations in integer SECONDS, times of day in integer MINUTES;
//   * dates as DateTime at local midnight — a schedule period boundary is a
//     calendar date, not an instant.

/// One project = one plant + one shift pattern, per the spec.
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 200)();

  /// Restricted rather than cascading: deleting a plant out from under a
  /// project would silently destroy months of study work. Archiving is the
  /// intended route (DESIGN.md §3), and the readiness panel reports a project
  /// whose plant is archived.
  TextColumn get plantId =>
      text().references(Plants, #id, onDelete: KeyAction.restrict)();

  /// The shift split every workcenter in this project's plant is staffed
  /// against (DESIGN.md §4.1).
  TextColumn get shiftPatternId =>
      text().references(ShiftPatterns, #id, onDelete: KeyAction.restrict)();

  TextColumn get notes => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {name},
  ];
}

/// Holidays, shutdowns and extra hours (DESIGN.md §4.3).
///
/// [scopeId] points at a production line or a workcenter depending on [scope].
/// It carries no foreign key on purpose: one column cannot reference two
/// different tables, and the alternative — a column per scope — makes "exactly
/// one is set" a rule the schema still could not express. The repository
/// resolves it, and a scope pointing at something deleted simply stops
/// matching.
class CalendarExceptions extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();

  /// Local date at midnight. Ranges are stored as one row per day: the editor
  /// expands them on entry, so every downstream lookup is a map hit rather
  /// than an interval search.
  DateTimeColumn get date => dateTime()();

  TextColumn get kind => textEnum<CalendarExceptionKind>()();
  TextColumn get scope => textEnum<CalendarExceptionScope>()();

  /// The line or workcenter this applies to, or `''` for the whole plant.
  ///
  /// **Empty string rather than null, deliberately.** SQLite treats NULLs as
  /// distinct in a UNIQUE constraint, so a nullable column would let two
  /// plant-wide exceptions exist for the same day — the exact duplicate the
  /// key below is there to prevent. The repository maps `null` to `''` at the
  /// boundary so callers never see the sentinel.
  TextColumn get scopeId => text().withDefault(const Constant(''))();

  /// Operators per shift for an extra-working day, in the compact `1/1/1` form
  /// the shop floor writes (see `parseOperatorsPerShift`). Null means "staffed
  /// as an ordinary working day".
  TextColumn get operatorsPerShift => text().nullable()();

  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    // One exception per day per scope. A second one at the same scope is a
    // data error the readiness panel would otherwise have to report
    // (DESIGN.md §11); the schema refuses it instead.
    {projectId, date, scope, scopeId},
  ];
}

/// The rhythm of a production line over a date range (DESIGN.md §6.1).
class TaktPeriods extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get productionLineId =>
      text().references(ProductionLines, #id, onDelete: KeyAction.cascade)();

  /// Inclusive local dates at midnight.
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();

  /// The takt as a number in [taktUnit] — `3` for a 3-day takt.
  ///
  /// **Stored with its unit rather than as canonical seconds**, because "3
  /// days" cannot be reduced to a duration without knowing whose working day is
  /// meant, and the answer differs per workcenter: a 1-shift station and a
  /// 3-shift station have very different days. The flow equivalent resolves it
  /// per workcenter at calculation time (DESIGN.md §6.1) — one takt of *that*
  /// workcenter's capacity. Hours, minutes and seconds are literal and resolve
  /// the same everywhere.
  RealColumn get taktValue => real()();

  TextColumn get taktUnit => textEnum<TaktUnit>()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {projectId, productionLineId, startDate},
  ];
}

/// A workcenter's staffing and losses over a date range (DESIGN.md §4.2, §4.4).
class WorkcenterSchedulePeriods extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get workcenterId =>
      text().references(Workcenters, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();

  /// Operators on each shift of the project's pattern, in the `1/1/1` form the
  /// spec writes. Zero means the workcenter is closed for that shift, and the
  /// displayed "Shifts: 3" is derived by counting the non-zero entries.
  ///
  /// A compact column rather than a child table: the list is short, fixed to
  /// the pattern's shift count, always read whole, and read on the hot path of
  /// every calendar walk.
  TextColumn get operatorsPerShift => text()();

  /// Fraction of open time the workcenter can actually run, 0 < a ≤ 1.
  RealColumn get availability => real().withDefault(const Constant(1.0))();

  /// Fraction of work that has to be redone, ≥ 0.
  RealColumn get rework => real().withDefault(const Constant(0.0))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {projectId, workcenterId, startDate},
  ];
}

/// One production flow under study (DESIGN.md §10.1).
///
/// Scoped to one (cell, line) pair; a project may hold several per line as
/// scenarios, at most one of which is flagged for a simulation run.
class Studies extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get productionCellId =>
      text().references(ProductionCells, #id, onDelete: KeyAction.cascade)();
  TextColumn get productionLineId =>
      text().references(ProductionLines, #id, onDelete: KeyAction.cascade)();

  TextColumn get name => text().withLength(min: 1, max: 200)();

  /// Whether this study takes part in the next simulation run. The project
  /// enforces at most one flagged study per line before a run.
  BoolColumn get includeInSimulation =>
      boolean().withDefault(const Constant(false))();

  /// Breaks dispatch ties between studies contending for a shared workcenter
  /// (DESIGN.md §7.4). Lower runs first.
  IntColumn get priority => integer().withDefault(const Constant(100))();

  /// CONWIP cap: maximum orders open in the flow at once. Null is unlimited,
  /// the default, so a first run shows raw demand-vs-capacity behaviour
  /// (DESIGN.md §7.3).
  IntColumn get wipCap => integer().nullable()();

  /// Endpoint labels on the map. Stored on the study rather than as nodes:
  /// they carry no data and take part in no calculation, so a row for each
  /// would be a row that can only ever be renamed.
  TextColumn get supplierName => text().nullable()();
  TextColumn get customerName => text().nullable()();

  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {projectId, name},
  ];
}

/// A node on the flow spine — a process step or an inventory buffer
/// (DESIGN.md §5.1, §5.5).
///
/// Supplier and Customer are drawn from the study's own fields, not stored
/// here: the spine is the part that carries data.
class FlowNodes extends Table {
  TextColumn get id => text()();
  TextColumn get studyId =>
      text().references(Studies, #id, onDelete: KeyAction.cascade)();

  /// Order along the spine, renumbered densely on every structural edit. This
  /// is the single source of truth for sequence — the layout is derived from
  /// it, so the drawing can never disagree with the routing.
  IntColumn get position => integer()();

  TextColumn get kind => textEnum<FlowNodeKind>()();

  // --- step ---------------------------------------------------------------

  /// Exactly one of these is set on a step, and both are null on an inventory
  /// node. Enforced by the repository and reported by the readiness panel; two
  /// nullable references cannot express "exactly one" in SQLite.
  TextColumn get workcenterId => text().nullable().references(
    Workcenters,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get poolId => text().nullable().references(
    WorkcenterPools,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Setup charged when the previous order on this workcenter was a different
  /// part number (DESIGN.md §7.6).
  IntColumn get changeoverSeconds => integer().withDefault(const Constant(0))();

  /// The flow equivalent's process time at this step, overriding one takt
  /// (DESIGN.md §6.1).
  ///
  /// A property of the **yardstick**, not of the station: an inspection that
  /// genuinely takes a fraction of a takt would otherwise drag every real
  /// part's equivalence at that step toward zero and skew the balance measure.
  /// Null follows the line's takt, which is the usual case.
  ///
  /// Stored as a value plus a [TaktUnit] — not a canonical duration — for the
  /// same reason takt is: `days` here means productive days of *this* station.
  RealColumn get equivalentValue => real().nullable()();
  TextColumn get equivalentUnit => textEnum<TaktUnit>().nullable()();

  // --- inventory ----------------------------------------------------------

  TextColumn get inventoryMode => textEnum<InventoryMode>().nullable()();

  /// Pieces waiting, for [InventoryMode.quantity]. Displayed as days through
  /// the takt of the period being viewed.
  IntColumn get inventoryQuantity => integer().nullable()();

  /// Fixed wait, for [InventoryMode.duration]. Canonical seconds.
  IntColumn get inventorySeconds => integer().nullable()();

  /// The unit that wait was typed in, so `2 days` reads back as `2 days` rather
  /// than `48 h`. Display only — every calculation uses [inventorySeconds],
  /// because unlike a takt this unit needs no workcenter to resolve.
  TextColumn get inventoryUnit => textEnum<DurationUnit>().nullable()();

  /// Whether a duration buffer is consumed in working time or on the wall
  /// clock. A cooling rack does not stop for the weekend; a manual inspection
  /// queue does.
  BoolColumn get inventoryUsesWorkingTime =>
      boolean().withDefault(const Constant(false))();

  TextColumn get label => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {studyId, position},
  ];
}

/// A part number in a study's demand (DESIGN.md §5.1, §9).
///
/// **Study-scoped, not project-scoped.** A part's data here is entirely about
/// one flow — its process times are keyed by that flow's own step targets — and
/// §10.2 leaves demand out of a template by default. Two studies of the same
/// line are scenarios of one reality, so duplicating a study deep-copies its
/// parts and lets the copy be re-sequenced without disturbing the original.
class DemandParts extends Table {
  TextColumn get id => text()();
  TextColumn get studyId =>
      text().references(Studies, #id, onDelete: KeyAction.cascade)();

  /// `PN2` — what the sequence, the MM3 chart and every report call it.
  TextColumn get partNumber => text().withLength(min: 1, max: 100)();

  /// The **customer's** project this part belongs to — their programme or
  /// contract, not the FlowMap project this study sits in.
  ///
  /// **Part of the part's identity**, not a label on it: a part number is the
  /// id of a part or a piece of equipment, and different clients' projects
  /// legitimately order the same one. `PN2 on Wing 7` and `PN2 on Wing 9` are
  /// two rows of demand with their own process times and their own place in the
  /// sequence.
  ///
  /// **Empty string rather than null**, for the reason
  /// [CalendarExceptions.scopeId] is: SQLite treats NULLs as distinct in a
  /// UNIQUE constraint, so a nullable column would let two unprojected `PN2`s
  /// exist side by side — the exact duplicate the key below exists to prevent.
  TextColumn get customerProject =>
      text().withDefault(const Constant(''))();

  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    // Project **and** number, because that pair is what identifies a part to
    // the planner and what an imported row has to match on (§9).
    {studyId, customerProject, partNumber},
  ];
}

/// One part's process time at one step target — a cell of the demand grid
/// (DESIGN.md §9).
///
/// **Keyed by the target, not by the flow node.** Adding a step to the flow
/// adds an empty column, and removing one hides its values rather than
/// destroying them, so a step deleted by mistake costs nothing to restore.
/// Keying by node id would take the column's data down with the node.
///
/// [targetId] is a workcenter id or a pool id, whichever the step targets. It
/// carries no foreign key for the reason [CalendarExceptions.scopeId] does not:
/// one column cannot reference two tables, and a column per kind makes "exactly
/// one is set" a rule the schema still could not express.
///
/// **A part that skips a step simply has no row here** (§5.1). That is what
/// keeps a blank cell and a zero different things — a zero that should have
/// been a number is the one bug this app cannot afford (§11).
class PartProcessTimes extends Table {
  TextColumn get partId =>
      text().references(DemandParts, #id, onDelete: KeyAction.cascade)();

  /// The workcenter or pool the step targets.
  TextColumn get targetId => text()();

  /// **Per piece**, in canonical seconds (§7.6, §12.4). An order of batch 10
  /// occupies its workcenter for ten times this, which is what makes batch size
  /// a real lever rather than metadata.
  IntColumn get seconds => integer()();

  @override
  Set<Column<Object>> get primaryKey => {partId, targetId};
}

/// One order in the sequence under study (DESIGN.md §7.2, §7.6).
class DemandOrders extends Table {
  TextColumn get id => text()();
  TextColumn get studyId =>
      text().references(Studies, #id, onDelete: KeyAction.cascade)();
  TextColumn get partId =>
      text().references(DemandParts, #id, onDelete: KeyAction.cascade)();

  /// Position in the release sequence — dense and zero-based, renumbered on
  /// every structural edit, the same convention the flow spine uses.
  ///
  /// The sequence is the thing under study: the engine releases from its head
  /// and never reorders it (§7.2), and MM3 measures how smooth it is (§6.3).
  IntColumn get sequence => integer()();

  /// Pieces in the order. Process times are per piece, so this multiplies the
  /// work at every step (§7.6).
  IntColumn get batchSize => integer().withDefault(const Constant(1))();

  DateTimeColumn get needDate => dateTime()();

  /// When material is on hand. Null means unconstrained — the order may take
  /// the first release slot it is offered (§7.2).
  DateTimeColumn get materialDate => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {studyId, sequence},
  ];
}

/// The decorative layer (DESIGN.md §5.2): standard VSM symbols that document
/// intent but take part in no calculation, freely placed at stored coordinates.
class FlowAnnotations extends Table {
  TextColumn get id => text()();
  TextColumn get studyId =>
      text().references(Studies, #id, onDelete: KeyAction.cascade)();

  TextColumn get symbol => textEnum<AnnotationSymbol>()();

  /// Canvas coordinates in logical pixels, relative to the spine's origin so
  /// an annotation stays beside the step it comments on when the map is zoomed
  /// or exported.
  RealColumn get x => real()();
  RealColumn get y => real()();

  /// The words on a note or a kaizen burst. Named `caption` rather than `text`
  /// because `Table.text()` is Drift's column builder.
  TextColumn get caption => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
