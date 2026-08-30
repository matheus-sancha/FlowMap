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

  /// Where the float matrix turns red and where it turns green, in **days**
  /// (§10.4).
  ///
  /// At or below [floatRedDays] is red, at or above [floatGreenDays] is green,
  /// and between them is amber. Defaults `0` and `30`: zero because an order
  /// delivered on its need date has no slack left and is the thing a planner is
  /// scanning for, and thirty because §7.8's start buffer is thirty days on this
  /// plant and a month of room is what "comfortable" has meant in every
  /// conversation about it.
  ///
  /// **Per project rather than global**, because what counts as comfortable is a
  /// property of the business a project models — and because §10.1 gave a
  /// project a screen to hold them, which is the whole reason that entry came
  /// first.
  ///
  /// Stored as plain integers with defaults rather than nullable: there is no
  /// meaningful *unset* here — a matrix has to colour every cell somehow, and a
  /// null would only be a second spelling of the default.
  IntColumn get floatRedDays => integer().withDefault(const Constant(0))();
  IntColumn get floatGreenDays => integer().withDefault(const Constant(30))();

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

  /// Safety margin ahead of the derived cold start, in **calendar days**
  /// (DESIGN.md §7.8).
  ///
  /// `order start = need date − theoretical lead time − this`. §7.8 derives the
  /// first half and it is correct; this is the deliberate margin on top, which
  /// nothing expressed before.
  ///
  /// **Calendar days, and every surface that shows it says so.** A start buffer
  /// protects against real-world slippage and slippage accrues on a wall
  /// calendar — a week late is a week late whether or not the plant was open.
  /// It also composes: the theoretical walk already returns a wall-clock
  /// instant, so the cold start stays one subtraction on one clock. §17.4 is
  /// why the unit is stated rather than assumed.
  ///
  /// Zero is no buffer, which is what every study did before this column.
  IntColumn get startBufferDays =>
      integer().withDefault(const Constant(0))();

  /// The workcenter or pool whose clock paces the releases, or null to derive
  /// it (DESIGN.md §7.2, §18.8).
  ///
  /// Derived by work content across the demand when null, which is what
  /// `_paceSetter` has always done. It is selectable now because the pacemaker
  /// gained a second job: §7.2 gates a release on whether the lane in front of
  /// it has room, so a station chosen silently by summing batch sizes would be
  /// a gate that moves when the demand is edited and tells nobody.
  ///
  /// A target id — workcenter or pool — the convention `part_process_times`
  /// and `workcenter_dispatch` already use, and unreferenced for the same
  /// reason they are: no one foreign key can point at two tables.
  TextColumn get paceSetterTargetId => text().nullable()();

  /// Endpoint labels on the map. Stored on the study rather than as nodes:
  /// they carry no data and take part in no calculation, so a row for each
  /// would be a row that can only ever be renamed.
  TextColumn get supplierName => text().nullable()();
  TextColumn get customerName => text().nullable()();

  /// Stock standing at the two ends of the flow (DESIGN.md §5.5, §12.6).
  ///
  /// **Observations, not queues.** Every step has a queue in front of it
  /// ([ProjectQueues]) and the ends have no step to belong to — so these are
  /// the raw material waiting before the first box and the finished goods
  /// waiting after the last, drawn as triangles against the endpoints. Nothing
  /// dispatches out of them: §7.2 releases orders on a takt rather than pulling
  /// from a rack, and inventing a pull here would be a mechanism the engine
  /// does not have.
  ///
  /// In pieces, like [FlowNodes.inventoryQuantity], so the map can show them as
  /// days through the takt of the period being viewed.
  IntColumn get inboundStock => integer().nullable()();
  IntColumn get outboundStock => integer().nullable()();

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

  /// Superseded by [setupValue] in v17, and kept rather than dropped.
  ///
  /// Its values were carried onto the setup columns by the migration and
  /// nothing reads it now. Dropping a column means a [TableMigration], which
  /// rebuilds from the *current* Dart definition — the trap this file has hit
  /// three times (§16.13, §16.15, §16.16) and the one thing §16.11's
  /// half-finished upgrade says not to risk for tidiness. It is also the only
  /// place a pre-v17 setup can be recovered by hand.
  IntColumn get changeoverSeconds => integer().withDefault(const Constant(0))();

  /// A changeover, in two halves: [setupValue] rigs the station for the order
  /// and [teardownValue] strips it afterwards (DESIGN.md §7.6).
  ///
  /// **Stored as a value plus a [TaktUnit], never as canonical seconds**, for
  /// the same reason takt and [equivalentValue] are: `days` here means
  /// productive days of *this* station, and cannot be reduced to a duration
  /// without saying whose day is meant (§6.1). One kind of day per dialog is
  /// §17.4's rule, and the field two below this one already uses that one.
  ///
  /// Null is no setup, which is what every node had before v17.
  RealColumn get setupValue => real().nullable()();
  TextColumn get setupUnit => textEnum<TaktUnit>().nullable()();

  /// The teardown, charged **with the next order's setup rather than at the end
  /// of this one** — the station remembers what it owes, because whether a
  /// strip-down is needed depends on what comes next and the engine has not
  /// picked it yet (DESIGN.md §7.6).
  ///
  /// Named teardown and not breakdown: in a plant "breakdown" means the machine
  /// failed, and §4.4's Availability — the actual breakdown figure — is drawn on
  /// the same process box.
  RealColumn get teardownValue => real().nullable()();
  TextColumn get teardownUnit => textEnum<TaktUnit>().nullable()();

  /// How much of `setup + teardown` is still charged when the previous order at
  /// this station was the **same part**, as a percentage.
  ///
  /// Null is 0 %, which is exactly what this app did before v17: like-with-like
  /// was free. 100 % makes batching buy nothing. It governs the pair rather than
  /// the setup alone, because the two are one changeover split in half and a
  /// second percentage would only ever move with the first.
  RealColumn get samePartPercent => real().nullable()();

  /// Pins this step out of §6.2.1's takt rebalancing (DESIGN.md §7.7.4).
  ///
  /// **Per step, not per workcenter**, for §7.6's reason — it is this line's
  /// use of the station, and a duplicated study must be re-tunable without
  /// disturbing the original. Célula 11B, 11C and 11D share four stations
  /// between them, so a flag on the machine would change three studies from a
  /// screen showing one.
  ///
  /// **Null is off, so rebalancing is on.** A disable flag rather than an
  /// enable one, so every step already in the tree keeps today's behaviour with
  /// no backfill — the same call §7.6 made for the same-part percentage.
  ///
  /// A pinned station is **transparent** to its group rather than a wall: it is
  /// the same operation, so the members either side of it still balance with
  /// each other (§6.2.1).
  BoolColumn get balanceDisabled => boolean().nullable()();

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

  /// The queue discipline of the lane, or null to follow the run's rule
  /// (DESIGN.md §5.5, §7.4).
  ///
  /// **The rule lives here rather than on the station**, which reverses §7.4 as
  /// it was first built. On a physical FIFO lane you cannot take from the back,
  /// so a discipline is not a property of the channel — it is how the next
  /// station *chooses* from what is standing in front of it, and that is a
  /// thing the map draws. Stored on the station it was invisible; stored here
  /// it sits on the node the reader is already looking at.
  ///
  /// §5.1's spine is what makes this a total order: a step has at most one lane
  /// in front of it, so there is exactly one comparator per queue. That is the
  /// ambiguity a station-level rule could not avoid — one machine can be a
  /// candidate for its own step and for a pool's.
  TextColumn get laneRule => textEnum<DispatchRule>().nullable()();

  /// How many orders the lane holds, or null for unlimited.
  ///
  /// **In orders, and its own column rather than [inventoryQuantity].** That
  /// figure means *N pieces standing here today* — an observation of a current
  /// state — and §5.5's whole correction is that an observation must not be
  /// read as a rule. They would share a unit and mean opposite things.
  ///
  /// Counted in orders because the order is the engine's unit of flow; a
  /// piece-level limit would need a rule for a batch that half fits, which the
  /// spine has no way to express. Null keeps a lane unbounded, which is what
  /// every node did before this column existed.
  IntColumn get laneCapacity => integer().nullable()();

  // **`label` went in v27** (#5). It overrode the target's name on the process
  // box, the demand grid's column headings and the Gantt's step title — so a
  // box could be captioned something its station was not called. Only 2 of the
  // live database's 25 steps carried one, and both were the *same* step in two
  // studies spelling one pool two ways (`Clad Pool`, `CLAD Pool`): it was not
  // naming a visit, it was working around a target name too long for the box.
  // A box is its station. See `flowStepTitle`.
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

  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    // The number alone, since v14. It used to be project **and** number, on the
    // argument that different customers' projects legitimately order the same
    // part number and those are two parts with their own process times. The
    // field disagreed: a part is a part, and the project is something the
    // *order* is for — so it moved to [DemandOrders.customerProject] and a part
    // number now means one part inside a study (§9.3, §16.15).
    {studyId, partNumber},
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

  /// The **flow node** whose step this time belongs to (§9).
  ///
  /// **Keyed by the step since v24, not by the station it points at.** It was
  /// the target, and two steps aiming at one workcenter were then two columns
  /// over one stored value — editing either edited both, and the engine charged
  /// the same work on each pass. That was written down as right: *"the station
  /// takes the same time per piece on both passes."* Driving §8.6 overturned
  /// it. A routing goes back to a machine because the second pass is a
  /// *different operation* — rough then finish, tack then final weld — and the
  /// model could not say so.
  ///
  /// **A pool still shares, and the rule §3.1 cared about is untouched.** A
  /// step targeting a pool is one step, so its members go on drawing one time:
  /// *"a part has one process time at `CNC Lathes`, not four."*
  TextColumn get nodeId =>
      text().references(FlowNodes, #id, onDelete: KeyAction.cascade)();

  /// **Per piece**, in canonical seconds (§7.6, §12.4). An order of batch 10
  /// occupies its workcenter for ten times this, which is what makes batch size
  /// a real lever rather than metadata.
  IntColumn get seconds => integer()();

  @override
  Set<Column<Object>> get primaryKey => {partId, nodeId};
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

  /// The planner's own identifier for this batch of this part number — `B-0012`,
  /// `LOT7`, whatever their system calls it.
  ///
  /// **A label, not identity**, which is what makes it nullable and unkeyed.
  /// The order it names already has an identity — its place in the sequence,
  /// which is what the engine releases from and what the Production Plan's
  /// `Order` column shows. So two orders may carry the same batch number, or
  /// none, and nothing downstream matches on it.
  ///
  /// It is the same argument that removed `order_number` in v9, reaching the
  /// opposite answer for a different reason: nobody needed a works order number
  /// the simulation identified by row anyway, but a planner reading a printed
  /// plan does need the number their paperwork is filed under.
  TextColumn get batchNumber => text().nullable()();

  /// The **customer's** project this order is for — their programme or
  /// contract, not the FlowMap project the study sits in (§3).
  ///
  /// **On the order since v14, and a label like [batchNumber].** It sat on the
  /// part until then, as half of what identified one, on the argument that
  /// `PN2 on Wing 7` and `PN2 on Wing 9` were two parts with their own process
  /// times. In the field a part number means one part: the times are the
  /// part's, and the project is what a given batch of it is *for*. So it is
  /// nullable and unkeyed — two orders may name the same project or none, and
  /// nothing matches a part on it any more (§9.3, §16.15).
  TextColumn get customerProject => text().nullable()();

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

/// One station's queue discipline, where it differs from the run's
/// (DESIGN.md §7.4).
///
/// **Keyed by target, exactly as [PartProcessTimes] is.** A pool's members are
/// interchangeable (§3.1), so the queue forms at the pool and the rule belongs
/// to the pool — not to whichever member happens to stand for it on the map.
/// [targetId] is therefore a workcenter id or a pool id and carries no foreign
/// key, for the reason [CalendarExceptions.scopeId] does not: one column cannot
/// reference two tables.
///
/// **Project-scoped, not study-scoped.** A run builds one resource model of the
/// plant and a station exists in it once however many studies point at it
/// (§7.7) — so a study-scoped rule would let two studies demand different
/// disciplines of one machine, with nothing able to choose between them. The
/// step editor writes it from inside a study and says so.
///
/// **A missing row means "use the run's rule."** Storing the default instead
/// would make a station that was never touched indistinguishable from one
/// deliberately set back to FIFO, and would freeze the run's own setting out of

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

/// The queue in front of one dispatch target, for one project
/// (DESIGN.md §5.5, §3.1, §12.6).
///
/// **A queue belongs to what a step targets, not to a study's flow.** It used
/// to be a node on one study's spine, so two studies whose flows both reached
/// CLAD07 each had their own — with their own name, discipline and capacity —
/// and the engine simulated two floor spaces where the plant has one. The field
/// reported it as the Gantt doubling its inventories; the drawing was only
/// repeating what the model said.
///
/// So the key is `{projectId, targetId}` and every step feeding that target
/// reads this one row. `targetId` is a workcenter **or a pool**: §3.1 dispatches
/// a pool's order to whichever member frees first, which only means anything if
/// the orders wait in one line, so a pool has one queue and its members pull
/// from it.
///
/// **Project-scoped, like [WorkcenterSchedulePeriods].** §3's seam puts identity
/// in Resources and period-scoped numbers in the Project — and capping a lane is
/// an *experiment*, which is exactly what §0's confounder run did to
/// `FIFO CEU27`. Putting it in Resources would make that experiment edit every
/// project at once.
///
/// Unreferenced by foreign key for the reason `part_process_times` is: no one
/// key can point at two tables.
class ProjectQueues extends Table {
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();

  /// The workcenter or pool the queue sits in front of.
  ///
  /// **It is also the whole of the queue's identity.** A queue is an aspect of
  /// a dispatch target, not a thing: it cannot exist without one, its primary
  /// key *is* one, and the only thing that ever made it look like an entity was
  /// a nullable `name` nobody wanted to type. That column went in v27 (#5) and
  /// the caption is derived — see `flowQueueCaption`. The live database's 15
  /// names were all `FIFO ` plus a mangled target name, which is the evidence
  /// the name was never identity.
  ///
  /// The invariant, so it stops being rediscovered: **one queue per dispatch
  /// target, not per workcenter.** A target is a workcenter *or* a pool, so a
  /// machine reached directly by one study and through a pool by another
  /// genuinely has two lines in front of it, and that is correct.
  TextColumn get targetId => text()();

  /// How the next order is chosen (§7.4).
  ///
  /// **This replaced the run's dispatch rule.** One place a dispatch decision is
  /// made and the map shows every one of them, which is what a value stream map
  /// is for. Null is [DispatchRule.fifo] — what a shop floor does, and what
  /// every lane was before it could say otherwise.
  TextColumn get rule => textEnum<DispatchRule>().nullable()();

  /// How many orders fit, in orders. Null is unlimited.
  ///
  /// **Its own figure, not [stockQuantity].** One is a rule about the future
  /// and the other an observation of today; they share a unit and mean opposite
  /// things (§16.16), and §5.5's correction was precisely that an observation
  /// must not be read as a rule.
  IntColumn get capacity => integer().nullable()();

  /// What is standing here now — the days-of-stock a current-state VSM exists to
  /// state, and a rung on the lead-time ladder (§5.5).
  ///
  /// Carries no time in a run: an order passes straight through and waits, if it
  /// waits, in this queue where the engine measures it. That is §2.12's
  /// correction and it is unchanged by the re-model.
  TextColumn get stockMode => textEnum<InventoryMode>().nullable()();
  IntColumn get stockQuantity => integer().nullable()();
  IntColumn get stockSeconds => integer().nullable()();
  TextColumn get stockUnit => textEnum<DurationUnit>().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {projectId, targetId};
}
