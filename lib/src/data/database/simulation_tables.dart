import 'package:drift/drift.dart';

import 'project_tables.dart';

// What a run stores (DESIGN.md §7.10): a header, the frozen input snapshot,
// one row per order-step, the per-order outcomes, the slots that went out
// empty, and each station's busy and open time.
//
// **Nothing here points at a study, a part or a workcenter with a foreign
// key**, and the names are copied in rather than joined to. That is the whole
// point of a stored run: it has to stay readable after the resources beneath it
// change or go away (§3). A cascade from `studies` would delete the evidence
// exactly when someone re-scoped a study to find out why last month's run said
// what it said. The one cascade that is right is from the project, which owns
// the run outright.
//
// Durations are integer SECONDS and dates are `DateTime`, the two conventions
// the rest of the schema uses.

/// One completed run (DESIGN.md §7.10).
class SimulationRuns extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();

  /// §7.4's rule, by name.
  ///
  /// **A plain text column rather than `textEnum`**, and likewise every other
  /// enum stored here. Two reasons, and the second is the one that decided it:
  /// `DispatchRule` belongs to the engine, and reaching it from this file would
  /// drag the whole calendar feature into the schema definition; and `textEnum`
  /// *throws* on a name it does not know, so a run written by a later build
  /// would make an older one fail to open a list of runs rather than show the
  /// one it cannot read. The repository parses, and falls back.
  TextColumn get dispatch => text()();

  /// Cold start — the plant is empty here (§7.8).
  DateTimeColumn get runStart => dateTime()();

  /// The last event processed.
  DateTimeColumn get runEnd => dateTime()();

  /// Where the run would have been abandoned (§7.8).
  DateTimeColumn get guard => dateTime()();

  /// Why it stopped early, by name. Null means it completed.
  TextColumn get abortReason => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One study's inputs as they stood when the run was made (§7.10).
///
/// The snapshot, not a reference: a run that named "Current state" keeps naming
/// it after the study is renamed, and keeps its release cadence after the takt
/// schedule beneath it is edited. Without this, every stored run silently
/// re-describes itself every time the plant is touched.
class SimulationRunStudies extends Table {
  TextColumn get runId =>
      text().references(SimulationRuns, #id, onDelete: KeyAction.cascade)();

  /// The study this was, whether or not it still exists.
  TextColumn get studyId => text()();

  TextColumn get name => text()();

  /// The gap between release slots, as resolved at the run's start (§7.2).
  IntColumn get releaseSeconds => integer()();

  /// Whose open time that interval was measured in — the pace setter.
  TextColumn get releaseCalendarId => text().nullable()();

  IntColumn get priority => integer()();
  IntColumn get wipCap => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {runId, studyId};
}

/// How one order fared (§7.10).
class SimulationRunOrders extends Table {
  TextColumn get runId =>
      text().references(SimulationRuns, #id, onDelete: KeyAction.cascade)();

  TextColumn get studyId => text()();
  TextColumn get orderId => text()();
  IntColumn get sequence => integer()();

  TextColumn get partId => text()();

  /// `PN2` — copied in, so a part deleted from the demand table does not turn
  /// every row of a finished run's per-part table into a uuid.
  TextColumn get partNumber => text()();

  /// The four below are what the Production Plan reads and the engine does not
  /// (DESIGN.md §8.4). Copied in for this file's own reason: the plan has to
  /// keep saying what it said after the demand beneath it is re-sequenced,
  /// re-batched or deleted outright.
  ///
  /// **Nullable, and never backfilled.** Runs stored before v12 have no answer,
  /// and a blank saying so is true. Filling them from the demand as it stands
  /// today would make one run a hybrid of two moments — the exact thing the
  /// copy-in rule at the top of this file exists to prevent.
  TextColumn get customerProject => text().nullable()();
  TextColumn get batchNumber => text().nullable()();
  IntColumn get batchSize => integer().nullable()();
  DateTimeColumn get materialDate => dateTime().nullable()();

  DateTimeColumn get needDate => dateTime()();

  /// When it entered the flow. Null means it never did — the sequence ran out
  /// of slots before the guard stopped the run.
  DateTimeColumn get released => dateTime().nullable()();

  /// When it finished its last semantic step (§18.1). Null if it never did.
  DateTimeColumn get delivered => dateTime().nullable()();

  /// §7.9's queue-free figure, walked from **this order's own release**.
  ///
  /// Stored rather than recomputed on read, because the walk needs the plant
  /// the run happened in — availability, staffing, the shift pattern — and the
  /// point of a stored run is that it survives all three being edited. Null
  /// when the order never completed and there was nothing to compare.
  IntColumn get theoreticalSeconds => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {runId, orderId};
}

/// One order's visit to one step (§7.10).
///
/// Keyed by (run, order, node): the spine is linear (§5.1), so an order visits
/// each node exactly once, and a second row for one would be a bug in the
/// engine rather than a case to store.
class SimulationRunSteps extends Table {
  TextColumn get runId =>
      text().references(SimulationRuns, #id, onDelete: KeyAction.cascade)();

  TextColumn get studyId => text()();
  TextColumn get orderId => text()();
  TextColumn get nodeId => text()();

  /// The workcenter that **actually** ran it, which for a pool step is only
  /// known once the run has happened (§3.1).
  TextColumn get workcenterId => text()();

  /// When the order reached this step and started waiting.
  DateTimeColumn get queueStart => dateTime()();

  DateTimeColumn get processStart => dateTime()();
  DateTimeColumn get processEnd => dateTime()();

  /// Whether the order before this one on that workcenter was a different part
  /// (§7.6).
  BoolColumn get changeoverIncurred =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {runId, orderId, nodeId};
}

/// A release slot that went out empty (§7.2).
///
/// One slot per instant per study — the sequence has one head — so the instant
/// keys the row.
class SimulationRunEmptySlots extends Table {
  TextColumn get runId =>
      text().references(SimulationRuns, #id, onDelete: KeyAction.cascade)();

  TextColumn get studyId => text()();
  DateTimeColumn get slotAt => dateTime()();

  /// `awaitingMaterial` or `wipCap`, by name.
  TextColumn get reason => text()();

  @override
  Set<Column<Object>> get primaryKey => {runId, studyId, slotAt};
}

/// A station that ran on something other than the run's rule (§7.4).
///
/// One row per **override**, not per station: a run of forty workcenters that
/// changed two writes two rows, and a run that changed nothing writes none.
/// Without this, [SimulationRuns.dispatch] would report `FIFO` for a run in
/// which three stations dispatched by due date — and M5's comparison could not
/// tell you that the dispatch is what differed between two runs.
class SimulationRunDispatch extends Table {
  TextColumn get runId =>
      text().references(SimulationRuns, #id, onDelete: KeyAction.cascade)();

  /// The workcenter or pool, whether or not it still exists.
  TextColumn get targetId => text()();

  /// `CLAD04` — copied in, as everything else in this file is, so an override
  /// still reads as a station after the workcenter is renamed or removed.
  TextColumn get name => text()();

  /// The rule that station actually used, by name. Plain text and parsed on
  /// read, for the reason [SimulationRuns.dispatch] is.
  TextColumn get rule => text()();

  @override
  Set<Column<Object>> get primaryKey => {runId, targetId};
}

/// What one station did across the run — utilisation's two halves (§8.3).
///
/// Busy and open are recorded rather than derived from the step rows: open time
/// is a property of the station's calendar, not of anything an order did, and
/// it is exactly what makes utilisation different from occupation.
class SimulationRunWorkcenters extends Table {
  TextColumn get runId =>
      text().references(SimulationRuns, #id, onDelete: KeyAction.cascade)();

  TextColumn get workcenterId => text()();

  /// `CLAD04` — copied in, so a bottleneck still reads as a station after the
  /// workcenter is renamed or removed from the plant.
  TextColumn get name => text()();

  /// Open time the station spent running (§8.3's utilisation numerator).
  IntColumn get busySeconds => integer()();

  /// Open time it had available across the run — the denominator.
  IntColumn get openSeconds => integer()();

  @override
  Set<Column<Object>> get primaryKey => {runId, workcenterId};
}
