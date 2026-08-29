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

  /// The last date every schedule this run used was actually defined for
  /// (§11.1), or null when the run never went past one.
  ///
  /// **Stored, because the warning has to survive being reopened.** How far the
  /// takt and workcenter periods reach is a fact about the plant, and §7.10
  /// forbids joining back to it — so a run that could not say this would drop
  /// its own caveat the moment the reader came back to it, which is exactly
  /// when they are most likely to quote the figures.
  ///
  /// **The date and not the count.** How many orders finished past it is
  /// derivable from `simulation_run_orders`, and storing both would let the two
  /// disagree — §1.5's lesson, from the direction of duplication rather than of
  /// omission.
  DateTimeColumn get scheduleHorizon => dateTime().nullable()();

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

  /// The takt this study ran at, as it was typed — `4` and `days`
  /// (DESIGN.md §7.7.2).
  ///
  /// **The run's identity, and until v20 it did not carry one.** §18.3 is
  /// settled: a run keeps one cadence throughout, so the takt is the parameter
  /// the whole experiment turns on — and a stored run could not say what it
  /// was. §7.10 forbids joining back to `takt_periods`, so editing the schedule
  /// silently rewrote what every past run claimed to have done.
  ///
  /// **Beside [releaseSeconds] rather than instead of it.** That is the same
  /// takt already resolved against the pace setter's productive day, which is
  /// what the engine spaced slots by; this is the figure a human typed and
  /// reads. One cannot be recovered from the other once a schedule moves.
  ///
  /// **Per study, because takt is keyed by production line** — a run carrying
  /// two lines ran at two takts, and a column on the run could only hold one.
  ///
  /// Null on every run made before v20, which means *made before a run said
  /// this* — the meaning a blank has had on these tables since v12.
  RealColumn get taktValue => real().nullable()();

  /// [taktValue]'s unit by name. Plain text rather than `textEnum` for §16.10's
  /// reason: a run written by a later build must not stop an older one opening
  /// the list.
  TextColumn get taktUnit => text().nullable()();

  /// When the takt next changes inside this run's span, or null if it does not
  /// (DESIGN.md §7.7.3).
  ///
  /// **Stored rather than derived, for §11.1's stated reason**: a run that
  /// could not say this would drop its own caveat the moment the reader came
  /// back to it, which is exactly when they are most likely to quote the
  /// figures. Célula 11D's takt goes 4 d → 5 d on 1 April 2026, and a run
  /// spanning that date ran entirely at one of them.
  DateTimeColumn get nextTaktChange => dateTime().nullable()();

  /// When this study's cadence ran out, or null where it did not (§7.9.2, v22).
  ///
  /// A line with no takt period covering an instant has no cadence, so it opens
  /// nothing there — and a study whose takt table stops before its sequence
  /// does leaves the rest of it unreleased. **Stored because the alternative is
  /// reporting the symptom and hiding the cause**: orders that never opened
  /// look exactly like a jammed plant, and a missing schedule row and a jam
  /// want opposite responses.
  ///
  /// §11.1's warning cannot stand in for it — that compares the run's *end*
  /// against the schedule horizon, and a run that stops releasing early may
  /// well end before the horizon with the warning silent.
  DateTimeColumn get cadenceEndedAt => dateTime().nullable()();

  IntColumn get priority => integer()();
  IntColumn get wipCap => integer().nullable()();

  /// The margin that was added ahead of the derived cold start (§7.8), in
  /// calendar days. Copied in so a run can say why it began where it did after
  /// the study's buffer is changed.
  IntColumn get startBufferDays =>
      integer().withDefault(const Constant(0))();

  /// Where this study sat in the plant, copied in so a stored run can be
  /// filtered by cell and by production line (§7.10).
  ///
  /// **The id and the name both**, for the reason every other copied-in label
  /// carries both: the id survives a rename and the name survives a deletion,
  /// and a filter has to keep working after either. §7.10 forbids joining back
  /// to `studies`, which is the only other place this could be read.
  ///
  /// **A cell or line filter is a study filter one level up.** Workcenters
  /// belong to a plant rather than to a cell, so stations are never filtered
  /// this way — the studies narrow, and their stations follow.
  ///
  /// Null on every run made before v17.
  TextColumn get productionCellId => text().nullable()();
  TextColumn get productionCellName => text().nullable()();
  TextColumn get productionLineId => text().nullable()();
  TextColumn get productionLineName => text().nullable()();

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

  /// The five below are what the Production Plan reads and the engine does not
  /// (DESIGN.md §8.5). Copied in for this file's own reason: the plan has to
  /// keep saying what it said after the demand beneath it is re-sequenced,
  /// re-batched or deleted outright.
  ///
  /// **Nullable, and never backfilled.** Runs stored before v12 — or before v13
  /// for [partDescription] — have no answer, and a blank saying so is true.
  /// Filling them from the demand as it stands today would make one run a
  /// hybrid of two moments, the exact thing the copy-in rule at the top of this
  /// file exists to prevent.
  TextColumn get customerProject => text().nullable()();
  TextColumn get batchNumber => text().nullable()();
  IntColumn get batchSize => integer().nullable()();
  DateTimeColumn get materialDate => dateTime().nullable()();

  /// `PWB 10K` — the part's own description, v13.
  ///
  /// Copied rather than joined to `demand_parts` for the reason [partNumber]
  /// is: a part re-described or deleted since would silently change what a
  /// finished run says. It identifies nothing — two parts legitimately share
  /// one description — so it is a label on the row, not a key.
  TextColumn get partDescription => text().nullable()();

  DateTimeColumn get needDate => dateTime()();

  /// When it entered the flow. Null means it never did — the sequence ran out
  /// of slots before the guard stopped the run.
  DateTimeColumn get released => dateTime().nullable()();

  /// When it finished its last semantic step (§18.1). Null if it never did.
  DateTimeColumn get delivered => dateTime().nullable()();

  /// The takt this order **opened** under, as it was typed (§7.9, v22).
  ///
  /// **The cause, stored beside the effects.** An order's work at each step is
  /// the balance's split against this figure, so two orders of one part
  /// legitimately carry different work — and v21's `process_seconds` records
  /// that difference while saying nothing about where it came from. Recording
  /// an effect and leaving its cause to be re-derived from a schedule the plant
  /// may have retuned is the drift §7.10 exists to prevent, one level up.
  ///
  /// Kept as the pair a human reads rather than the resolved interval: the
  /// seconds only ever mattered for reproducing the cadence, and the study row
  /// still carries those for its first release.
  ///
  /// Null on every run made before v22 — *made before a run said this* — and on
  /// an order that never opened, which had no takt to take.
  RealColumn get taktValue => real().nullable()();

  /// [TaktUnit.name], the unit [taktValue] is in.
  ///
  /// Stored as a plain name rather than `textEnum` for §16.10's reason: a value
  /// a later build knows and this one does not must not stop the run opening.
  TextColumn get taktUnit => text().nullable()();

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
  ///
  /// **Derived from [changeoverSeconds] since v17**, and kept because every run
  /// made before that column existed can still answer this and nothing else.
  BoolColumn get changeoverIncurred =>
      boolean().withDefault(const Constant(false))();

  /// What the changeover actually cost this step, in seconds of the station's
  /// open time (§7.6).
  ///
  /// A bool could say *whether* a changeover was paid and that was enough while
  /// the answer was all-or-nothing. Since v17 a repeat may be charged at a
  /// percentage, so "incurred" stopped being a yes/no about a figure the reader
  /// cannot see — and §8.6's hover card was the only place the new setup rule
  /// could be checked against what it actually did.
  ///
  /// Null means made before this column existed, which is what a blank has meant
  /// on these tables since v12 — not "no changeover", which is zero.
  IntColumn get changeoverSeconds => integer().nullable()();

  /// What the **work** cost at this step, in seconds of the station's open
  /// clock — `per-piece × batch × (1 + rework) ÷ availability`, changeover
  /// excluded (§7.4, §7.6).
  ///
  /// **The only place a run says what a step was actually worth.**
  /// [processStart] and [processEnd] bracket the work on the *calendar*, so
  /// their difference is an elapsed span that swallows nights, weekends and
  /// shutdowns — a 76-hour operation reads as 148 hours across a normal week.
  /// That is the right figure for drawing a bar and the wrong one for checking
  /// what a station was asked to do, and until this column there was no second
  /// figure to check it against: §7.4's balance moves work *between* stations,
  /// and a reader could not see the split it produced anywhere in the run.
  ///
  /// Recomputing it on read is not open to us — it needs the batch, the
  /// availability and the rework as they stood, and §7.10 forbids joining back
  /// to a plant that may have been retuned since. So it is copied in like every
  /// other figure a run has to keep saying.
  ///
  /// Null on every run made before v21, which means *made before a run said
  /// this* — not "no work", which is zero and is what a step the part does not
  /// route through legitimately records.
  IntColumn get processSeconds => integer().nullable()();

  /// The lane the order waited in before this step, or null when the step had
  /// none and it queued at the station itself (§5.5).
  ///
  /// With it, [queueStart] and [processStart] become the two ends of a stay in
  /// a named lane — which is what makes `simulation_run_lane_visits` derivable
  /// rather than a second record of the same event. Null on every run made
  /// before lanes governed anything.
  TextColumn get laneNodeId => text().nullable()();

  /// How long the station stood holding this order after finishing it, because
  /// the lane ahead was full (§5.5).
  ///
  /// Blocking is after service — a station cannot know in advance whether there
  /// will be room, so it finishes and then waits — which means [processEnd] is
  /// when the work stopped and `processEnd + this` is when the station was free
  /// again. Kept apart from the work for the reason it is kept out of
  /// `busySeconds` on the station: a jammed machine is occupied and not
  /// producing, and folding the two would make utilization report the jam as
  /// output.
  ///
  /// Zero on every run made before lanes had capacity, which is true of them.
  IntColumn get blockedSeconds =>
      integer().withDefault(const Constant(0))();

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

/// What one station did across the run — utilization's two halves (§8.3).
///
/// Busy and open are recorded rather than derived from the step rows: open time
/// is a property of the station's calendar, not of anything an order did, and
/// it is exactly what makes utilization different from occupation.
class SimulationRunWorkcenters extends Table {
  TextColumn get runId =>
      text().references(SimulationRuns, #id, onDelete: KeyAction.cascade)();

  TextColumn get workcenterId => text()();

  /// `CLAD04` — copied in, so a bottleneck still reads as a station after the
  /// workcenter is renamed or removed from the plant.
  TextColumn get name => text()();

  /// Open time the station spent running (§8.3's utilization numerator).
  IntColumn get busySeconds => integer()();

  /// Open time it had available across the run — the denominator.
  ///
  /// Already multiplied by [units]: a station with two of them has twice the
  /// time to be busy in, and utilization is meaningless if the numerator counts
  /// two servers and the denominator one.
  IntColumn get openSeconds => integer()();

  /// Open time it spent holding a finished order with nowhere to put it (§5.5).
  ///
  /// **Not part of [busySeconds].** A blocked station is occupied and producing
  /// nothing, so counting it as busy would report a jam as output — and on a
  /// line whose constraint already sits at 86 % utilization that is not a
  /// rounding error. Reported as its own column, which is what §5.5 meant by
  /// "needs blocking-time metrics to be interpretable".
  IntColumn get blockedSeconds =>
      integer().withDefault(const Constant(0))();

  /// How many orders it could run at once when the run was made (§3.1).
  ///
  /// Copied in like [name], for the same reason: a station re-rated from one
  /// unit to two afterwards must not silently rewrite what a finished run's
  /// utilization meant.
  IntColumn get units => integer().withDefault(const Constant(1))();

  /// The pool this station was dispatched through in this run (§3.1), copied in
  /// like [name] and for the same reason: moving CLAD07 to another pool
  /// afterwards must not regroup a finished run's stations.
  ///
  /// **Null means ungrouped, never "every pool".** A workcenter may belong to
  /// several pools — `WorkcenterPoolMembers`' key is `{poolId, workcenterId}` —
  /// so with two studies in one run, line A can reach CLAD07 through `CAL`
  /// while line B reaches it through `All Lathes`. Resolved at write time by
  /// `stationPools`: **exactly one pool is stored, none or several store null**
  /// and the station reads ungrouped. Treating a blank as a wildcard is the
  /// mistake §12.1 already wrote a rule against for the pre-v17 cell.
  ///
  /// Null on every run made before v18, which therefore group nothing.
  TextColumn get poolId => text().nullable()();

  /// `CAL Pool` — the pool's name at run time, for the same copy-in reason as
  /// [name].
  ///
  /// **Set even when [poolId] is null and several pools were involved**, as
  /// `CAL Pool · All Lathes`: the station is not grouped, and a reader still
  /// deserves to see why it is standing on its own. Null only when no step
  /// reached it through a pool at all.
  TextColumn get poolName => text().nullable()();

  /// The queue this station dispatched by when the run was made (§7.4, §12.6).
  ///
  /// Copied in for §7.10's reason and no other: the queue lives on the project
  /// and can be retuned tomorrow, and a run that read it back would silently
  /// change what it claims to have done. It is also what lets a comparison say
  /// *which* queues differed rather than only that something did.
  ///
  /// Null on a run made before v19, whose rule is on [SimulationRuns.dispatch]
  /// instead — the one column this replaced.
  ///
  /// **Plain text, not `textEnum`**, for the reason [SimulationRuns.dispatch]
  /// gives at the top of this file: `textEnum` throws on a name it has never
  /// heard of, so a queue type added by a later build would make an older one
  /// fail to open the whole run list rather than show the one run it cannot
  /// read. The repository parses, and falls back.
  TextColumn get queueType => text().nullable()();
  IntColumn get queueCapacity => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {runId, workcenterId};
}

/// A lane as it stood when the run was made (§5.5, §7.10).
///
/// The snapshot beside [SimulationRunLaneVisits], and the same copy-in rule as
/// [SimulationRunWorkcenters]: a lane renamed, re-disciplined or re-sized after
/// the run must not change what the run says happened in it.
///
/// It also carries the geometry the Gantt needs. §7.10 joins to nothing and the
/// flow may have been edited since, so without [position] there is no way to
/// place a lane row between the two station rows it connects.
class SimulationRunLanes extends Table {
  TextColumn get runId =>
      text().references(SimulationRuns, #id, onDelete: KeyAction.cascade)();

  TextColumn get studyId => text()();

  /// The `flow_nodes` row it was, whether or not it still exists.
  TextColumn get nodeId => text()();

  /// `FIFO CEU27` — the node's label, copied in. Null when it was never
  /// labelled, which is what an unnamed buffer on the map looks like.
  TextColumn get name => text().nullable()();

  /// Its place on the spine, so a lane row can be drawn between the stations it
  /// sits between.
  IntColumn get position => integer()();

  /// The discipline in force, by name. Null means the run's own rule was used.
  ///
  /// Plain text rather than `textEnum` for the reason [SimulationRuns.dispatch]
  /// gives: a run written by a later build must not stop an older one opening
  /// the list of runs.
  TextColumn get rule => text().nullable()();

  /// Orders it could hold, or null for unlimited.
  IntColumn get capacity => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {runId, nodeId};
}

/// One order's stay in one lane (§5.5, §7.10).
///
/// Keyed by (run, order, node) like [SimulationRunSteps], and for the same
/// reason: §5.1's spine is linear, so an order passes each lane exactly once.
///
/// **This is what makes the lane rows on the Gantt drawable.** Steps leave a
/// trace in the run and buffers did not, so before this a lane could be neither
/// placed nor populated without joining back to a flow that may have changed.
class SimulationRunLaneVisits extends Table {
  TextColumn get runId =>
      text().references(SimulationRuns, #id, onDelete: KeyAction.cascade)();

  TextColumn get studyId => text()();
  TextColumn get orderId => text()();

  /// The **workcenter or pool** whose queue this is (§7.3, §8.6).
  ///
  /// **Renamed from `node_id` at v23, which is what it never was.** §7.3 moved
  /// the queue off the flow and onto the station — `engine.dart` writes
  /// `waiting.lane.targetId` here — and the column name stayed behind. A name
  /// that says node while holding a workcenter is what made §8.6 invisible:
  /// the key built on it read as "one order queues once per step" and meant
  /// "one order queues once per station".
  TextColumn get targetId => text()();

  /// The flow node this stay was waiting *for* (§8.6).
  ///
  /// **This is what makes a visit unique, and [targetId] is not.** A part may
  /// go back to a machine for a second operation — ordinary routing, which the
  /// engine has always modelled — and both stays are then in one station's
  /// queue. Keyed by the station, the second stay collided with the first and
  /// the run was computed and then thrown away with a UNIQUE constraint the
  /// screen reported only as "could not be completed".
  ///
  /// Keyed by the step, the two stays are two rows, which is what
  /// [SimulationRunSteps] has always done with the identical key shape. That
  /// table survived because it is keyed by *where in the flow*; this one is
  /// the odd one out being brought into line.
  ///
  /// **On rows migrated from v22 it may hold a [targetId] instead.** A stay
  /// that produced no step — an order the guard caught still queueing — has no
  /// step to name, and the old key already guaranteed at most one such row per
  /// order per station, so nothing collides and nothing is lost. It means a
  /// pre-v23 run cannot say which step a stay belonged to, which is true.
  TextColumn get stepNodeId => text()();

  /// When the order took a place in the lane.
  DateTimeColumn get enteredAt => dateTime()();

  /// When the station ahead pulled it out. Null means it was still in the lane
  /// when the run ended, which is the honest reading of an order the guard
  /// caught mid-flight.
  DateTimeColumn get leftAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {runId, orderId, stepNodeId};
}
