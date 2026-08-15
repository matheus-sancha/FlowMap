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

/// A node of a study's flow, as the engine walks it.
sealed class SimNode {
  const SimNode({required this.id, required this.position});

  final String id;
  final int position;
}

/// A process step (§5.1).
class SimStep extends SimNode {
  const SimStep({
    required super.id,
    required super.position,
    required this.title,
    required this.candidates,
    required this.demandKey,
    this.setupValue,
    this.setupUnit,
    this.teardownValue,
    this.teardownUnit,
    this.samePartFraction = 0,
  });

  /// What the process box is labelled.
  final String title;

  /// The workcenters that may run it: one, or a pool's members (§3.1). An
  /// order goes to whichever frees first.
  final List<String> candidates;

  /// The id this step's process times are keyed by — the pool where it targets
  /// one, never a member standing in for it (§9).
  final String demandKey;

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

/// An inventory lane (§5.5).
///
/// **It still carries no time**, and that half of §2.12 stands: a buffer's
/// stored figure — N pieces of stock, or a wait in days — is an *observation* of
/// a current state, and imposing it as a delay made the run a restatement of
/// what was typed into it, charged twice over. What the lane carries instead is
/// **governance**: who goes next, and how many fit.
///
/// So an order does not serve a fixed wait here; it waits exactly as long as the
/// station ahead makes it wait, in this lane, in the order this lane's [rule]
/// says — and when the lane is full, the station behind it cannot unload and
/// stops. That is what the names on a real map mean. `FIFO CEU27` is not a
/// three-day delay, it is a channel with a discipline and a floor space.
class SimBuffer extends SimNode {
  const SimBuffer({
    required super.id,
    required super.position,
    this.name,
    this.rule,
    this.capacity,
  });

  /// `FIFO CEU27` — the node's label. A passenger the engine never reads, like
  /// [SimPart.partNumber]: it rides along so the run can copy it in at save
  /// time, which is the only moment it still describes the flow the run was
  /// made from (§7.10).
  final String? name;

  /// How the station ahead chooses from what is standing here, or null to
  /// follow the run's rule (§7.4).
  ///
  /// **The rule lives on the lane, not on the station**, which reverses §7.4 as
  /// first built. On a physical lane you cannot take from the back, so a
  /// discipline is not a property of the channel — it is how the next station
  /// chooses, and that is something the map can draw. §5.1's spine keeps the
  /// ordering total: a step has at most one lane in front of it, so a queue has
  /// exactly one comparator even when its station also belongs to a pool.
  final DispatchRule? rule;

  /// How many orders fit, or null for unlimited.
  ///
  /// In orders, because the order is the unit of flow here; a piece-level limit
  /// would need a rule for a batch that half fits, which the spine cannot
  /// express. Null is what every lane was before capacity existed.
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

  /// Whose open time [releaseInterval] is measured in. Null puts the slots on
  /// the wall clock, which is right for a takt given in hours and wrong for one
  /// given in days — hence the caller's job, not ours.
  final String? releaseCalendarId;

  final String id;
  final String name;

  /// The spine in order.
  final List<SimNode> nodes;

  /// Keyed by part id.
  final Map<String, SimPart> parts;

  /// In sequence order.
  final List<SimOrder> orders;

  /// Breaks dispatch ties between studies contending for a shared workcenter
  /// (§7.4). Lower runs first.
  final int priority;

  /// CONWIP cap: orders open in the flow at once. Null is unlimited (§7.3).
  final int? wipCap;

  Iterable<SimStep> get steps => nodes.whereType<SimStep>();
}
