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

import '../../calendar/application/working_calendar.dart';
import '../../schedules/application/workcenter_schedule.dart';

/// A workcenter the run contends over.
class SimWorkcenter {
  const SimWorkcenter({
    required this.id,
    required this.name,
    required this.calendar,
    required this.schedule,
  });

  final String id;

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
/// The wait is **resolved before the run**: a quantity buffer is
/// `pieces × takt`, and which takt depends on the period, which is a question
/// the map already answers. The engine is given a duration and does not ask
/// where it came from.
class SimBuffer extends SimNode {
  const SimBuffer({
    required super.id,
    required super.position,
    required this.wait,
    required this.usesWorkingTime,
  });

  final Duration wait;

  /// Whether it is consumed in working time or on the wall clock. A cooling
  /// rack does not stop for the weekend; a manual inspection queue does.
  final bool usesWorkingTime;
}

/// One part's per-piece process times, keyed by step target (§9).
class SimPart {
  const SimPart({
    required this.id,
    required this.partNumber,
    required this.processTimes,
  });

  final String id;
  final String partNumber;

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
    this.orderNumber,
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

  final String? orderNumber;
}

/// One study taking part in a run.
class SimStudy {
  const SimStudy({
    required this.id,
    required this.name,
    required this.nodes,
    required this.parts,
    required this.orders,
    this.priority = 100,
    this.wipCap,
  });

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
