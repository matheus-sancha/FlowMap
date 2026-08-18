/// What the simulation engine is given, and nothing else (DESIGN.md §7).
///
/// Plain value types with no Drift and no widgets: a run is assembled from the
/// database once, then handed to a pure engine that can be driven from a test
/// with three lines of setup and — from M4's UI — from a background isolate,
/// which can only be passed things that carry no database handle.
///
/// **A run is one resource model of the plant** (§7.7). Each workcenter exists
/// once here however many studies point at it, which is what makes line A's
/// orders genuinely delay line B's.
library;

import '../../../data/database/enums.dart';
import '../../calendar/application/working_calendar.dart';
import '../../schedules/application/takt_schedule.dart';
import '../../schedules/application/workcenter_schedule.dart';

/// [DispatchRule] moved to the schema's enums when a station gained the right
/// to override the run's rule (§7.4) — a stored column has to name it, and the
/// schema cannot import this file. Re-exported so the engine, the assembly and
/// every caller still take it from here, which is where it reads as belonging.
export '../../../data/database/enums.dart' show DispatchRule;

/// A workcenter the run contends over.
class SimWorkcenter {
  const SimWorkcenter({
    required this.id,
    required this.name,
    required this.calendar,
    required this.schedule,
    this.units = 1,
  });

  final String id;

  /// How many orders it runs at once (§3.1).
  ///
  /// The engine gives the station this many servers, each with its own clock
  /// and its own last-part memory — so two units of one machine pay changeovers
  /// independently, which is what two units are.
  ///
  /// **A pool is the precedent, not the alternative.** Three cladding machines
  /// already reach a run as three candidates on one step, and a two-unit
  /// workcenter is the same arithmetic with one name: the capacity doubles and
  /// the per-machine yardstick does not, which is why §6.1's equivalent still
  /// reads per machine while §8.4's occupation halves.
  final int units;

  /// `CLAD04` — what a result names, so a bottleneck reads as a station rather
  /// than as a uuid.
  final String name;

  final WorkingCalendar calendar;

  /// Availability and rework by date. Held as the schedule rather than as two
  /// numbers because the engine walks real dates and a run may cross 1 July,
  /// where the staffing changes (§4.2).
  final WorkcenterScheduleSpec schedule;

}

/// A process step (§5.1) — and, since the queue re-model, the only kind of node
/// the engine walks.
///
/// The spine used to alternate steps and buffers. A buffer is now the queue in
/// front of a step ([SimQueue]), so what the engine gets is a list of steps,
/// each carrying the queue orders wait in to reach it.
class SimStep {
  const SimStep({
    required this.id,
    required this.position,
    required this.queue,
    required this.title,
    required this.candidates,
    required this.demandKey,
    this.poolId,
    this.poolName,
    this.setupValue,
    this.setupUnit,
    this.teardownValue,
    this.teardownUnit,
    this.samePartFraction = 0,
    this.queueStock = Duration.zero,
    this.balancedProcessTimes = const {},
  });

  final String id;
  final int position;

  /// The queue orders wait in to reach this step, shared with every other step
  /// that targets the same station or pool.
  final SimQueue queue;

  /// What the process box is labelled.
  final String title;

  /// The workcenters that may run it: one, or a pool's members (§3.1). An
  /// order goes to whichever frees first.
  final List<String> candidates;

  /// The id this step's process times are keyed by — the pool where it targets
  /// one, never a member standing in for it (§9).
  final String demandKey;

  /// Part id → the share §7.4's balance gave this step, where it sits in a run
  /// of adjacent like machines. Empty everywhere else.
  ///
  /// **Keyed by part and held on the step**, rather than folded into
  /// [SimPart.processTimes] before the engine sees them. Those are keyed by
  /// *target*, and two steps of one group are two stations only if they name
  /// two — a flow that visits one machine twice in a row would collide on the
  /// key and take one member's share for both.
  ///
  /// Resolved at assembly because the split is against the takt in force
  /// (§7.4), and the run has exactly one (§18.3).
  final Map<String, Duration> balancedProcessTimes;

  /// What one piece of [partId] costs here: the balanced share where this step
  /// is in a group, and the measured time otherwise.
  ///
  /// The one place the choice is made, so the engine and the theoretical walk
  /// cannot disagree about which of the two figures a step is worth.
  Duration? processTimeFor(String partId, SimPart? part) =>
      balancedProcessTimes[partId] ?? part?.timeAt(demandKey);

  /// The pool this step targets, or null where it names a single workcenter
  /// (§3.1). Carried so a finished run can record which pool each of its
  /// stations was dispatched through (§7.10) — [candidates] says *which*
  /// machines, and says nothing about what they were collectively called.
  ///
  /// Not derived from `candidates.length`: a pool with one member is still a
  /// pool, and a reader who typed its name is owed it back.
  final String? poolId;
  final String? poolName;

  /// The two halves of a changeover: [setupValue] rigs the station for an order
  /// and [teardownValue] strips it afterwards (§7.6).
  ///
  /// **Unresolved on purpose.** A step may target a pool, and a pool's members
  /// do not share a working day — so `1 day` of setup is a different duration at
  /// each of three cladding machines. Resolving here would need one of them
  /// nominated to stand for the rest, which is exactly the invention §3.2
  /// rejected when it refused to model a two-unit station as two machines. The
  /// engine resolves against the server it is about to occupy, where the answer
  /// is not a guess.
  final double? setupValue;
  final TaktUnit? setupUnit;
  final double? teardownValue;
  final TaktUnit? teardownUnit;

  /// How much of `setup + teardown` a repeat of the same part still pays, as a
  /// fraction. Zero is what this app did before v17: like-with-like was free.
  final double samePartFraction;

  bool get isPool => candidates.length > 1;

  /// The same step, carrying the shares §7.4's balance gave it.
  ///
  /// A copy rather than a mutable field: a `SimStep` is handed to the engine,
  /// the theoretical walk and the run writer, and a value any of them could
  /// change is a value none of them can trust.
  SimStep withBalance(Map<String, Duration> shares) => SimStep(
    id: id,
    position: position,
    queue: queue,
    title: title,
    candidates: candidates,
    demandKey: demandKey,
    poolId: poolId,
    poolName: poolName,
    setupValue: setupValue,
    setupUnit: setupUnit,
    teardownValue: teardownValue,
    teardownUnit: teardownUnit,
    samePartFraction: samePartFraction,
    queueStock: queueStock,
    balancedProcessTimes: shares,
  );

  /// How long the stock in [queue] represents, resolved for **this study**
  /// (§5.5, §7.9).
  ///
  /// A quantity is `pieces × takt` at this step's own productive day, which is
  /// the same arithmetic the map draws — so a queue's days of stock read alike
  /// on both. Zero where nothing is standing there.
  ///
  /// **The engine does not charge it** and never has: it is an observation of a
  /// current state, and how long an order really waits is the question a run
  /// exists to answer (§5.5). What reads it is the walk that says when an order
  /// must *start*, where the floor space is real and an order has to sit in it.
  final Duration queueStock;

  bool get hasChangeover => setupValue != null || teardownValue != null;

  /// Rigging this station for an order, at a station whose productive day is
  /// [productiveDay] and given whether the part [repeated] from the order
  /// before it.
  Duration setupAt(Duration productiveDay, {required bool repeated}) =>
      _resolve(setupValue, setupUnit, productiveDay, repeated);

  /// Stripping this station after an order.
  ///
  /// **Charged by whoever comes next, not by the order that incurred it** — the
  /// engine holds it on the server until there is an answer to *is a strip-down
  /// even needed*, which depends on the next order and is not knowable when this
  /// one finishes.
  Duration teardownAt(Duration productiveDay, {required bool repeated}) =>
      _resolve(teardownValue, teardownUnit, productiveDay, repeated);

  /// **Each half carries its own step's discount.** Usually the teardown owed
  /// and the setup arriving belong to the same step and this is the same thing
  /// as discounting the pair; they differ only when one station is the target of
  /// two steps, and then each half is governed by the step that specified it
  /// rather than by whichever happened to arrive second.
  Duration _resolve(
    double? value,
    TaktUnit? unit,
    Duration productiveDay,
    bool repeated,
  ) {
    if (value == null) return Duration.zero;
    final full = taktUnitDuration(
      value,
      // A unit is meaningless without a value and is only ever stored beside
      // one, so this fallback is unreachable rather than a default worth
      // reasoning about.
      unit ?? TaktUnit.seconds,
      productiveDay,
    );
    return repeated
        ? Duration(seconds: (full.inSeconds * samePartFraction).round())
        : full;
  }
}

/// The queue in front of one dispatch target (§5.5, §3.1).
///
/// **It belongs to the target, not to a study's flow.** This was `SimBuffer` —
/// a node on one study's spine — so two studies whose flows both reached CLAD07
/// each had their own, and the engine contended over two floor spaces where the
/// plant has one. The field reported it as the Gantt doubling its inventories;
/// the chart was repeating what the model said.
///
/// So a step carries the queue of whatever it targets, and two steps naming one
/// target carry the same one. The engine counts what is waiting **by target**,
/// which is what makes a shared queue actually shared: an order from line B
/// fills a slot that line A can then not have.
///
/// It still carries no time. An order passes straight through and waits, if it
/// waits, in this queue where the engine measures it — §2.12's correction,
/// unchanged by the re-model.
class SimQueue {
  const SimQueue({
    required this.targetId,
    this.name,
    this.rule = DispatchRule.fifo,
    this.capacity,
    this.stockMode,
    this.stockQuantity,
    this.stockSeconds,
  });

  /// What is standing in this queue today, exactly as stored (§5.5).
  ///
  /// **Carried raw, and read by nobody but the assembler.** A quantity is
  /// `pieces × takt`, and a takt belongs to a *study's* line while this queue is
  /// shared across every study that reaches the target — so the resolution
  /// happens per study, into [SimStep.queueStock]. The engine still charges
  /// nothing for it: an order passes straight through and waits, if it waits, in
  /// the queue where the engine measures it.
  final InventoryMode? stockMode;
  final int? stockQuantity;
  final int? stockSeconds;

  /// The workcenter or pool this queue stands in front of. Two steps sharing a
  /// target share this id, and that identity is the whole point.
  final String targetId;

  /// `FIFO CEU27` — a passenger the engine never reads, like
  /// [SimPart.partNumber]: it rides along so the run can copy it in at save
  /// time (§7.10).
  final String? name;

  /// How the station chooses what to take next (§7.4).
  ///
  /// **Not nullable, and no longer deferring to a run-level rule.** The queue
  /// type replaced that rule outright: one place a dispatch decision is made,
  /// and the map draws every one of them. Unset in the project reads as
  /// [DispatchRule.fifo], which is what a shop floor does.
  final DispatchRule rule;

  /// How many orders fit, or null for unlimited.
  ///
  /// In orders, because the order is the unit of flow here; a piece-level limit
  /// would need a rule for a batch that half fits, which the spine cannot
  /// express.
  final int? capacity;
}

/// One part's per-piece process times, keyed by step target (§9).
class SimPart {
  const SimPart({
    required this.id,
    required this.partNumber,
    required this.processTimes,
    this.description,
  });

  final String id;

  /// The engine never reads this or [description] — both ride along so the run
  /// can copy them in at save time (§7.10), which is the only moment they are
  /// still guaranteed to describe the demand the run was made from.
  final String partNumber;

  /// `PWB 10K`, for the Production Plan's own column (§8.5). Identifies
  /// nothing — two parts may share one — and is null when none was typed.
  final String? description;

  /// **Per piece** (§7.6). A part that skips a step is absent here, not zero.
  final Map<String, Duration> processTimes;

  Duration? timeAt(String demandKey) => processTimes[demandKey];
}

/// One order in a study's sequence (§7.2).
class SimOrder {
  const SimOrder({
    required this.id,
    required this.sequence,
    required this.partId,
    required this.needDate,
    this.batchSize = 1,
    this.materialDate,
    this.batchNumber,
    this.customerProject,
  });

  final String id;

  /// Position in the user's sequence. The engine releases from its head and
  /// never reorders it — the sequence is the thing under study (§7.2).
  final int sequence;

  final String partId;
  final DateTime needDate;

  /// Pieces. Process times are per piece, so this multiplies the work.
  final int batchSize;

  /// When material is on hand. Null is unconstrained.
  final DateTime? materialDate;

  /// The planner's own label for this batch (§9.1). A passenger, like
  /// [SimPart.partNumber]: nothing in the engine reads it, and the production
  /// plan cannot be printed without it.
  final String? batchNumber;

  /// The customer's project this order is for (§9.3). A passenger too, and on
  /// the order rather than the part since v14 — two orders of one part may be
  /// for different projects, so the part could not have answered this.
  final String? customerProject;
}

/// One study taking part in a run.
class SimStudy {
  const SimStudy({
    required this.id,
    required this.name,
    required this.nodes,
    required this.parts,
    required this.orders,
    required this.releaseInterval,
    this.releaseCalendarId,
    this.taktValue,
    this.taktUnit,
    this.nextTaktChange,
    this.paceSetterNodeId,
    this.startBuffer = Duration.zero,
    this.priority = 100,
    this.wipCap,
    this.productionCellId,
    this.productionCellName,
    this.productionLineId,
    this.productionLineName,
  });

  /// Where this study sits in the plant, carried through the run so a stored
  /// result can be filtered by cell and by line without joining back to a study
  /// that may since have moved or been deleted (§7.10).
  ///
  /// **The engine never reads any of them** — passengers, exactly as
  /// `SimPart.partNumber` and `SimOrder.batchNumber` are, so what a run reports
  /// is what was *assembled* rather than a second look at the database at save
  /// time (§8.5).
  final String? productionCellId;
  final String? productionCellName;
  final String? productionLineId;
  final String? productionLineName;

  /// The step whose lane gates the releases — the pacemaker (§7.2).
  ///
  /// Lean injects the schedule at the pacemaker, so that is the queue whose
  /// room decides whether a slot can be used. It is a node id rather than a
  /// workcenter id because the gate is a *place in the flow*: the same machine
  /// may appear in two studies, and only one of those appearances is this
  /// study's pacemaker.
  ///
  /// Null leaves the releases ungated by room, which is what every study did
  /// before lanes had capacity.
  final String? paceSetterNodeId;

  /// Margin subtracted from the derived cold start, in wall-clock time (§7.8).
  ///
  /// Calendar days rather than working ones: a start buffer protects against
  /// real-world slippage, and slippage accrues on a wall calendar whether or
  /// not the plant was open. It also composes — the theoretical walk already
  /// returns a wall-clock instant, so the cold start stays one subtraction on
  /// one clock (§17.4).
  final Duration startBuffer;

  /// One takt — the gap between release slots (§7.2).
  ///
  /// Resolved by the caller, not here: a takt in days means productive days of
  /// a particular station (§6.1), and which station is the question §8.2 has
  /// already answered — the bottleneck sets the pace (§18.8). The engine is
  /// handed a duration and a clock to measure it on.
  final Duration releaseInterval;

  /// The takt this study ran at, as it was typed (DESIGN.md §7.7.2).
  ///
  /// **[releaseInterval] is this same takt already resolved** against the pace
  /// setter's productive day; these two are the figure a human typed and reads.
  /// Neither can be recovered from the other once a schedule is edited, which is
  /// why a run stores both (§7.10).
  final double? taktValue;
  final TaktUnit? taktUnit;

  /// When the line's takt next becomes a different figure after this study's
  /// start, or null if it never does (§7.7.3).
  ///
  /// **A caveat, not a mechanism.** §18.3 is settled: a run keeps one cadence
  /// throughout, so a change falling inside a run's span is something the run
  /// has to *say* rather than something the engine acts on.
  final DateTime? nextTaktChange;

  /// Whose open time [releaseInterval] is measured in. Null puts the slots on
  /// the wall clock, which is right for a takt given in hours and wrong for one
  /// given in days — hence the caller's job, not ours.
  final String? releaseCalendarId;

  final String id;
  final String name;

  /// The spine in order.
  final List<SimStep> nodes;

  /// Keyed by part id.
  final Map<String, SimPart> parts;

  /// In sequence order.
  final List<SimOrder> orders;

  /// Breaks dispatch ties between studies contending for a shared workcenter
  /// (§7.4). Lower runs first.
  final int priority;

  /// CONWIP cap: orders open in the flow at once. Null is unlimited (§7.3).
  final int? wipCap;

  Iterable<SimStep> get steps => nodes;
}

/// The pool a run's station belonged to, as far as the run can tell
/// (DESIGN.md §3.1, §7.10).
///
/// [id] null means **ungrouped**, never "every pool" — the same rule §12.1
/// wrote for a pre-v17 run's cell. [name] is still worth having when [id] is
/// null: it says which pools the station served, which is the reason it is
/// standing on its own.
///
/// Resolved by `stationPools` in `sim_assembly.dart`, stored on the run, and
/// read back beside the station it describes so the grouping cannot drift when
/// the plant is re-pooled.
class StationPool {
  const StationPool({required this.id, required this.name});

  final String? id;
  final String name;
}
