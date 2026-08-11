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
    this.dispatch,
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

  /// This station's own queue discipline, or null to follow the run's (§7.4).
  ///
  /// **Resolved onto the server, not left on the step's target.** The rule is
  /// stored against a workcenter *or a pool* (§3.1), but the engine picks when
  /// a single machine frees, and one machine can be a candidate for two steps —
  /// its own and a pool's. If the rule travelled with the step, two orders
  /// waiting at one machine could be governed by different comparators, and
  /// "which runs first" would have no answer. The assembly flattens pool
  /// membership down to the member before the engine ever sees it, so each
  /// server has exactly one rule and the ordering stays a total one.
  final DispatchRule? dispatch;
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
    this.changeover = Duration.zero,
  });

  /// What the process box is labelled.
  final String title;

  /// The workcenters that may run it: one, or a pool's members (§3.1). An
  /// order goes to whichever frees first.
  final List<String> candidates;

  /// The id this step's process times are keyed by — the pool where it targets
  /// one, never a member standing in for it (§9).
  final String demandKey;

  /// Charged only when the previous order on that workcenter was a different
  /// part (§7.6).
  final Duration changeover;

  bool get isPool => candidates.length > 1;
}

/// An inventory buffer (§5.5).
///
/// **It carries no time.** A buffer's figure — N pieces of stock, or a wait in
/// days — is an *observation* of a current state, and what a simulation is for
/// is working out how long an order actually waits. Imposing the observed
/// figure as a delay makes the run partly a restatement of what was typed into
/// it, and does it twice over: the order serves the fixed wait and *then*
/// queues at the station anyway.
///
/// So an order passes through instantly and waits, if it waits, in the queue at
/// the next station — where the engine measures it. The figure keeps its two
/// real jobs, neither of which is here: the lead-time ladder on the map (§5.5),
/// which is read off the flow rather than off a run, and the days-of-stock a
/// current-state VSM exists to state.
///
/// Kept as a node rather than dropped from the model, so the engine's view of a
/// flow stays a faithful image of the map's — same nodes, same positions.
class SimBuffer extends SimNode {
  const SimBuffer({required super.id, required super.position});
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
    this.priority = 100,
    this.wipCap,
  });

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
