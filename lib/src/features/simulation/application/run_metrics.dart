/// What a run reports (DESIGN.md §8).
///
/// Pure functions over a [SimRunResult], so every figure a report or a screen
/// shows can be checked against a hand-computed expectation without a database
/// or a widget tree (§15).
///
/// The rankings here are the **simulated** half of §8.1. The Summary's
/// occupation is the static half, available before any run; the two are meant
/// to be read together, because where they disagree is itself diagnostic — a
/// long queue at a station that is not busy is a sequencing problem, not a
/// capacity one.
library;

import 'sim_assembly.dart' show stationPools;
import 'sim_model.dart';
import 'sim_result.dart';
import 'theoretical_lead_time.dart';

/// How one part fared across the run.
class PartMetrics {
  const PartMetrics({
    required this.partId,
    required this.studyId,
    required this.partNumber,
    required this.orders,
    required this.delivered,
    required this.onTime,
    required this.averageLeadTime,
    required this.averageFloat,
  });

  final String partId;

  /// The study the part belongs to.
  ///
  /// A part number is unique **within a study**, not within a project
  /// (`DemandParts.uniqueKeys`, §16.15), so a run spanning two lines can carry
  /// two different parts both called `PN2` — different routings, different
  /// process times, two rows here reading the same. Without this the table
  /// cannot say which is which, and neither can anything that colours by part.
  final String studyId;

  final String partNumber;

  final int orders;
  final int delivered;
  final int onTime;

  /// Wall-clock time in the flow, averaged over the orders that finished.
  final Duration? averageLeadTime;

  /// Average slack against the need date. **Positive is early**, negative late.
  final Duration? averageFloat;
}

/// How one station behaved, as opposed to how loaded it was predicted to be.
class WorkcenterRunMetrics {
  const WorkcenterRunMetrics({
    required this.workcenterId,
    required this.name,
    required this.busy,
    required this.open,
    required this.queueTime,
    required this.visits,
    required this.changeovers,
    required this.contributedTime,
    this.typeId,
    this.typeName,
    this.blocked = Duration.zero,
    this.poolId,
    this.poolName,
  });

  final String workcenterId;
  final String name;

  /// The pool this station was dispatched through, as the run recorded it
  /// (§3.1, §7.10). Null means **ungrouped**, never "every pool": the station
  /// was named directly by every step that used it, was reached through more
  /// than one pool, or the run predates v18.
  ///
  /// [poolName] outlives [poolId] on purpose — a station reached two ways
  /// carries the names it served with no id to group under, so a reader can see
  /// why it is standing on its own.
  final String? poolId;
  final String? poolName;

  /// The workcenter's type as the run copied it in (§10.2), or null on a run
  /// made before v25 and on a station whose type was never set.
  ///
  /// **Read back rather than re-derived**, for the reason the pool is: a station
  /// retyped since would otherwise re-column every run in the picker (§7.10).
  final String? typeId;
  final String? typeName;

  /// Open time spent running (§8.3's utilization numerator).
  final Duration busy;

  /// Open time the station had across the run.
  final Duration open;

  /// Time it stood holding a finished order because the lane ahead was full
  /// (§5.5).
  ///
  /// **Not part of [busy]**, so [utilization] keeps meaning "running". Read
  /// beside it rather than folded into it: a station at 40 % utilization and
  /// 50 % blocked is a different plant from one at 40 % and idle, and only the
  /// first is fixed by making room downstream.
  final Duration blocked;

  /// Total time orders spent waiting here — §8.1's first post-run ranking.
  final Duration queueTime;

  final int visits;
  final int changeovers;

  /// Queue plus processing: everything an order spent at this station, which
  /// is what its share of the flow's lead time is measured from.
  final Duration contributedTime;

  /// Busy ÷ open — **utilization**, a simulated output, not to be confused
  /// with occupation (§8.3).
  double? get utilization =>
      open.inSeconds == 0 ? null : busy.inSeconds / open.inSeconds;

  Duration get averageQueue =>
      visits == 0 ? Duration.zero : queueTime ~/ visits;
}

/// Everything §8 asks a run to report.
class RunMetrics {
  const RunMetrics({
    required this.orders,
    required this.delivered,
    required this.onTime,
    required this.emptySlots,
    required this.averageFloat,
    required this.averageLeadTime,
    required this.theoreticalLeadTime,
    required this.parts,
    required this.workcenters,
    this.settledActual,
    this.settledTheoretical,
    this.settledOrders = 0,
    this.warmUpOrders = 0,
  });

  final int orders;
  final int delivered;
  final int onTime;
  final int emptySlots;

  /// Average slack against the need date. **Positive is early**, negative late;
  /// null when nothing was delivered.
  final Duration? averageFloat;

  /// Average wall-clock time in the flow, over the orders that finished.
  final Duration? averageLeadTime;

  /// The same orders' theoretical lead time (§7.9), averaged.
  ///
  /// **A standard, not a floor**: it charges the stock standing in every queue
  /// and a full cold changeover at every step, neither of which a run spends,
  /// so it may land either side of [averageLeadTime].
  final Duration? theoreticalLeadTime;

  /// [averageLeadTime] and [theoreticalLeadTime] again, over the orders
  /// [leadTimeEfficiency] is actually computed from (§8.7).
  ///
  /// Two things are excluded, and only from these. **Orders missing either
  /// figure** — delivered but not walkable, or walkable but never delivered —
  /// because a ratio of two means taken over two different populations is a
  /// ratio of nothing. And **the warm-up**: every order released before its
  /// study's first delivery, which met a flow no order had yet crossed.
  ///
  /// Null when no order qualifies.
  final Duration? settledActual;
  final Duration? settledTheoretical;

  /// How many orders [leadTimeEfficiency] covers, and how many the warm-up rule
  /// held back — so a reader can see what the headline is speaking for.
  final int settledOrders;
  final int warmUpOrders;

  final List<PartMetrics> parts;

  /// Every station the run touched, ranked busiest-queue first.
  final List<WorkcenterRunMetrics> workcenters;

  int get late => delivered - onTime;

  /// On-time ÷ total (§8). Counted over **all** orders, not just the delivered
  /// ones: an order that never came out is not on time.
  double get onTimeDelivery => orders == 0 ? 0 : onTime / orders;

  /// `theoretical ÷ actual`, rendered as a percentage (§8.7).
  ///
  /// **Above 1.0 is good**: the flow crossed faster than the standard, because
  /// it queued less than the standard expects. Below 1.0 is more queueing than
  /// the standard allows for.
  ///
  /// This was `actual ÷ theoretical` and shipped that way, so a flow running
  /// *well* displayed a *low* number. It survived because §7.9.1, §8 and §8.5
  /// all described the reciprocal and all agreed with each other; only the code
  /// and the field disagreed.
  ///
  /// **Computed from [settledActual] and [settledTheoretical]**, not from the
  /// two averages above them: those count every order, because they are facts
  /// about orders someone was promised, while this is a ratio against a
  /// standard the warm-up orders were never measured against.
  double? get leadTimeEfficiency {
    final actual = settledActual;
    final theoretical = settledTheoretical;
    if (actual == null || theoretical == null || actual.inSeconds == 0) {
      return null;
    }
    return theoretical.inSeconds / actual.inSeconds;
  }

  /// The station the headline names: the one orders wait at longest.
  /// **The busiest station that actually ran something.**
  ///
  /// `workcenters` lists every station the run modelled, idle ones included, so
  /// that an open machine nobody loaded keeps its name and its type. A machine
  /// with no visits is not a bottleneck under any reading — and in a run where
  /// nothing queued at all it would otherwise take the top of a ranking sorted
  /// by queue time, and be named as one.
  WorkcenterRunMetrics? get bottleneck =>
      workcenters.where((station) => station.visits > 0).firstOrNull;

  /// The same stations ranked by share of the flow's total time instead — the
  /// second ranking §8.1 asks for, kept separate because the disagreement
  /// between the two is the diagnostic.
  List<WorkcenterRunMetrics> get byContribution {
    final ranked = [...workcenters]
      ..sort((a, b) => b.contributedTime.compareTo(a.contributedTime));
    return ranked;
  }

  /// A station's share of everything orders spent inside the flow.
  double shareOfFlow(WorkcenterRunMetrics station) {
    var total = 0;
    for (final entry in workcenters) {
      total += entry.contributedTime.inSeconds;
    }
    return total == 0 ? 0 : station.contributedTime.inSeconds / total;
  }
}

/// Measures a finished run.
///
/// [studies] and [workcenters] are the same objects the run was given: the
/// theoretical lead time is walked per order from them, because it is a
/// property of the part and the plant rather than of the run.
RunMetrics computeRunMetrics({
  required SimRunResult result,
  required List<SimStudy> studies,
  required Map<String, SimWorkcenter> workcenters,
}) => summariseRun(
  result: result,
  partNumbers: {
    for (final study in studies)
      for (final part in study.parts.values) part.id: part.partNumber,
  },
  workcenterNames: {
    for (final entry in workcenters.entries) entry.key: entry.value.name,
  },
  includeUnvisited: true,
  // Resolved from the studies rather than looked up: this is the same map the
  // repository copies into the run, so a fresh run and the same run read back
  // group their stations identically (§7.10).
  pools: stationPools(studies),
  theoreticalByOrder: theoreticalLeadTimes(
    result: result,
    studies: studies,
    workcenters: workcenters,
  ),
);

/// §7.9's queue-free figure for each order that completed, keyed by order id.
///
/// Walked from the order's **own release instant**, so the comparison is like
/// with like: the same order, in the same plant, minus the queueing. An order
/// that never came out is absent rather than zero — inventing a figure for it
/// would flatter the run.
///
/// Split out from [computeRunMetrics] because it is the one part of a run's
/// arithmetic that needs the plant rather than the result: a run read back out
/// of storage has the numbers but not the calendars that produced them
/// (§7.10), so it is stored per order and handed to [summariseRun] directly.
Map<String, Duration> theoreticalLeadTimes({
  required SimRunResult result,
  required List<SimStudy> studies,
  required Map<String, SimWorkcenter> workcenters,
}) {
  final studiesById = {for (final study in studies) study.id: study};
  final walked = <String, Duration>{};

  for (final outcome in result.orders) {
    final released = outcome.released;
    if (released == null || outcome.leadTime == null) continue;

    final study = studiesById[outcome.studyId];
    final part = study?.parts[outcome.partId];
    final order = study?.orders.where((o) => o.id == outcome.orderId).firstOrNull;
    if (study == null || part == null || order == null) continue;

    final theoretical = theoreticalLeadTime(
      nodes: study.nodes,
      workcenters: workcenters,
      part: part,
      batchSize: order.batchSize,
      from: released,
      // **The takt this order opened under** (§7.9), so its standard is built
      // from the same work split the run charged it. Read off the release
      // instant the engine recorded rather than carried on the outcome: it is
      // the same lookup the engine made and cannot drift from it.
      takt: study.taktKeyAt(released),
    );
    if (theoretical != null) walked[outcome.orderId] = theoretical.elapsed;
  }

  return walked;
}

/// Everything §8 asks, from a result and the three things that name it.
///
/// The entry point a **stored** run comes back through (§7.10): part numbers,
/// station names and each order's theoretical figure are copied into storage
/// beside the run precisely so this can be answered without the plant, which
/// may have been edited since. A fresh run reaches the same code through
/// [computeRunMetrics], so what a run reports cannot drift from what it
/// reported when it was made.
RunMetrics summariseRun({
  /// Workcenter id → its type, as the run recorded it. Empty on a run made
  /// before v25, which is what makes §10.3 offer no pivot rather than one with
  /// a single unnamed column.
  required SimRunResult result,
  required Map<String, String> partNumbers,
  required Map<String, String> workcenterNames,
  required Map<String, Duration> theoreticalByOrder,
  Map<String, StationPool> pools = const {},
  Map<String, ({String id, String name})> types = const {},
  /// Whether a station the run modelled but no order reached gets a row.
  ///
  /// **True for the whole run, false for a slice**, and the difference is what
  /// each is for. The run's own list is the plant it ran against, and since
  /// capacity started following the schedule that includes machines nobody
  /// loaded — they are on the Occupation grid and need their name and their
  /// type from here, or they draw as a uuid and vanish under a type filter.
  ///
  /// A *slice* is the stations its own orders touched. `filterRun` keeps the
  /// open-time maps whole on purpose — utilisation is the run's, not the
  /// slice's — so seeding from them there would put every station in the plant
  /// into every filtered ranking, which is the splice that file removed.
  bool includeUnvisited = false,
}) {
  var floatTotal = Duration.zero;
  var leadTotal = Duration.zero;
  var theoreticalTotal = Duration.zero;
  var theoreticalCount = 0;
  var delivered = 0;
  var onTime = 0;

  // **The warm-up boundary, per study** (§8.7): the first moment that study
  // delivered anything. Until then no order of that line has crossed the whole
  // flow, so nothing downstream has seen contention and those orders are not
  // measuring the same plant the rest are.
  //
  // Per study rather than per run, because a study is a line with its own flow
  // and — since §7.8 — its own cold start. A line that begins three months
  // later fills its own pipeline then, not when the earliest line filled its.
  final firstDelivery = <String, DateTime>{};
  for (final outcome in result.orders) {
    final at = outcome.delivered;
    if (at == null) continue;
    final known = firstDelivery[outcome.studyId];
    if (known == null || at.isBefore(known)) firstDelivery[outcome.studyId] = at;
  }

  var settledActualTotal = Duration.zero;
  var settledTheoreticalTotal = Duration.zero;
  var settledCount = 0;
  var warmUpCount = 0;

  final byPart = <String, _PartTally>{};

  for (final outcome in result.orders) {
    final tally = byPart.putIfAbsent(
      outcome.partId,
      () => _PartTally(
        partNumbers[outcome.partId] ?? outcome.partId,
        outcome.studyId,
      ),
    );
    tally.orders++;

    if (outcome.isOnTime) onTime++;
    if (outcome.delivered == null) continue;

    delivered++;
    tally.delivered++;
    if (outcome.isOnTime) tally.onTime++;

    final float = outcome.float!;
    floatTotal += float;
    tally.floatTotal += float;

    final lead = outcome.leadTime;
    if (lead != null) {
      leadTotal += lead;
      tally.leadTotal += lead;
      tally.leadCount++;

      final theoretical = theoreticalByOrder[outcome.orderId];
      if (theoretical != null) {
        theoreticalTotal += theoretical;
        theoreticalCount++;

        // Both figures present, so this order *could* go into the ratio. Only
        // the warm-up rule can hold it back now.
        final opened = firstDelivery[outcome.studyId];
        final released = outcome.released;
        if (opened != null && released != null && released.isBefore(opened)) {
          warmUpCount++;
        } else {
          settledActualTotal += lead;
          settledTheoreticalTotal += theoretical;
          settledCount++;
        }
      }
    }
  }

  // **Every station the run modelled, not only the ones an order reached** —
  // see [includeUnvisited]. Seeded from the open time, so an idle machine keeps
  // its name and its type; its tally stays at zero visits, which is the true
  // thing to say about it and what the utilization column already means: 0 % of
  // an open machine.
  final stations = <String, _StationTally>{
    if (includeUnvisited)
      for (final id in result.openByWorkcenter.keys)
        id: _StationTally(workcenterNames[id] ?? id),
  };
  for (final row in result.steps) {
    final tally = stations.putIfAbsent(
      row.workcenterId,
      () => _StationTally(workcenterNames[row.workcenterId] ?? row.workcenterId),
    );
    tally.visits++;
    tally.queue += row.wait;
    tally.contributed += row.wait + row.occupied;
    if (row.changeoverIncurred) tally.changeovers++;
  }

  final ranked =
      [
        for (final entry in stations.entries)
          WorkcenterRunMetrics(
            workcenterId: entry.key,
            name: entry.value.name,
            busy: result.busyByWorkcenter[entry.key] ?? Duration.zero,
            open: result.openByWorkcenter[entry.key] ?? Duration.zero,
            queueTime: entry.value.queue,
            visits: entry.value.visits,
            changeovers: entry.value.changeovers,
            contributedTime: entry.value.contributed,
            blocked: result.blockedByWorkcenter[entry.key] ?? Duration.zero,
            poolId: pools[entry.key]?.id,
            poolName: pools[entry.key]?.name,
            typeId: types[entry.key]?.id,
            typeName: types[entry.key]?.name,
          ),
      ]..sort((a, b) {
        final queue = b.queueTime.compareTo(a.queueTime);
        // Name last, so a plant where nothing queues still ranks the same way
        // twice running.
        return queue != 0 ? queue : a.name.compareTo(b.name);
      });

  return RunMetrics(
    orders: result.orders.length,
    delivered: delivered,
    onTime: onTime,
    emptySlots: result.emptySlots.length,
    averageFloat: delivered == 0 ? null : floatTotal ~/ delivered,
    averageLeadTime: delivered == 0 ? null : leadTotal ~/ delivered,
    theoreticalLeadTime: theoreticalCount == 0
        ? null
        : theoreticalTotal ~/ theoreticalCount,
    settledActual: settledCount == 0
        ? null
        : settledActualTotal ~/ settledCount,
    settledTheoretical: settledCount == 0
        ? null
        : settledTheoreticalTotal ~/ settledCount,
    settledOrders: settledCount,
    warmUpOrders: warmUpCount,
    parts: [
      for (final entry in byPart.entries) entry.value.toMetrics(entry.key),
    ]..sort((a, b) {
      final number = a.partNumber.compareTo(b.partNumber);
      // Study last, so two studies' `PN2` land adjacent and in the same order
      // twice running. Sorting on the number alone left their order to
      // whichever the map happened to yield first, which is a list that
      // reorders itself between reads of one run.
      return number != 0 ? number : a.studyId.compareTo(b.studyId);
    }),
    workcenters: ranked,
  );
}

class _PartTally {
  _PartTally(this.partNumber, this.studyId);

  final String partNumber;
  final String studyId;
  int orders = 0;
  int delivered = 0;
  int onTime = 0;
  int leadCount = 0;
  Duration floatTotal = Duration.zero;
  Duration leadTotal = Duration.zero;

  PartMetrics toMetrics(String partId) => PartMetrics(
    partId: partId,
    studyId: studyId,
    partNumber: partNumber,
    orders: orders,
    delivered: delivered,
    onTime: onTime,
    averageLeadTime: leadCount == 0 ? null : leadTotal ~/ leadCount,
    averageFloat: delivered == 0 ? null : floatTotal ~/ delivered,
  );
}

class _StationTally {
  _StationTally(this.name);

  final String name;
  int visits = 0;
  int changeovers = 0;
  Duration queue = Duration.zero;
  Duration contributed = Duration.zero;
}
