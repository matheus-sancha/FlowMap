/// Rebalancing a run of like machines against the takt (DESIGN.md §7.4).
///
/// *Field: "If I change the takt time I need to rebalance the operations of the
/// workcenters, otherwise it will be unbalanced. The app should identify
/// workcenters of the same type, then rebalance the process time according to
/// the takt time, topping the first workcenter at the takt time and leaving the
/// rest, under or over, to the last workcenter of the same type in the
/// sequence."*
///
/// **Pure, and shared by the map and the engine**, which is the whole reason it
/// is a file of its own. The map balances against the viewed period's takt and
/// the engine against the run's, so the two legitimately differ — but they must
/// not differ because the arithmetic was written twice.
library;

/// One step, as the balance sees it.
///
/// Deliberately not a `FlowStepView` or a `SimStep`: those are the two callers,
/// and a rule that named either of them could not be shared by both.
typedef BalanceStep = ({
  /// The workcenter type, which is the identity a group is formed on. Null
  /// where the step names no station, or its station has no type — either way
  /// it can belong to no group.
  String? typeName,

  /// What was measured at this station: the observation, straight from the
  /// demand table.
  ///
  /// **Zero means the part does not route here, and null means nobody has
  /// said** — and neither takes a share (§7.7.1). They are different statements
  /// everywhere else in the app: a blank cell is a blocking readiness error
  /// (§6.2) and a zero is the plant saying it looked and the answer is none.
  /// Here they land in the same place, because a station with no positive work
  /// is a station this part does not use.
  Duration? measured,

  /// One takt of this station's own capacity — the cap it fills to. Null where
  /// the takt or the station's schedule could not be resolved.
  Duration? takt,
});

/// A run of adjacent steps that share a workcenter type (§7.4).
class BalanceGroup {
  const BalanceGroup({
    required this.typeName,
    required this.indices,
    required this.measuredTotal,
    required this.derived,
  });

  /// What the group's machines are, and the identity it was formed on.
  final String typeName;

  /// The indices of its members in the list handed to [balanceFlow], in flow
  /// order.
  ///
  /// **The stations that take a share**, not every step of the type-run it was
  /// found in: one whose measured time is zero does not route here and is left
  /// out (§7.7.1), without breaking the run for the ones either side of it.
  final List<int> indices;

  /// The work content the group holds for this part — the sum of what was
  /// measured at its members, which is the figure the split is derived from and
  /// the only thing about the group that is stored.
  final Duration measuredTotal;

  /// What each member should take, by index. Sums to [measuredTotal] exactly.
  final Map<int, Duration> derived;
}

/// Groups the flow's steps and splits each group's work against the takt.
///
/// **Consecutive steps sharing a type are one group.** A run of adjacent
/// cladding operations shares the work; cladding again after heat treat is a
/// different operation and a new group, because work cannot move across an
/// intervening furnace. Adjacency is what makes the rule physical.
///
/// **A group of one is not a group.** There is nothing to move the work to, so
/// a lone station keeps what was measured at it and never appears here — which
/// is what keeps a flow of unlike machines behaving exactly as it did before
/// this rule existed.
///
/// **Only stations with positive work are members** (§7.7.1). A zero is how the
/// plant says a part does not route through a station, so `CEU30 = 0 h,
/// CEU32 = 146 h` is one member and therefore no group at all — CEU32 keeps its
/// 146 h. A station sitting out is **transparent**: the members either side of
/// it still balance with each other.
///
/// **Fill each to its own takt and leave the remainder on the last**, which is
/// what was asked for. The last station is the one allowed to be under or over:
/// under when the group has slack, over when it is the bottleneck, and either
/// way the overflow is visible at the end of the run rather than smeared across
/// it where nobody would see it.
///
/// **A group whose takt cannot be resolved is not balanced at all.** One member
/// with no schedule and there is no cap to fill to, so the split would be an
/// invention — the measured figures stand and the step's own readiness problem
/// says why.
List<BalanceGroup> balanceFlow(List<BalanceStep> steps) {
  final groups = <BalanceGroup>[];

  var start = 0;
  while (start < steps.length) {
    final type = steps[start].typeName;
    if (type == null) {
      start++;
      continue;
    }

    var end = start;
    while (end + 1 < steps.length && steps[end + 1].typeName == type) {
      end++;
    }

    final run = [for (var i = start; i <= end; i++) i];
    start = end + 1;

    // **Only the stations this part actually runs on** (§7.7.1). A zero is how
    // the plant says a part does not route through a station, and giving one a
    // share puts work on a machine the part never visits — 94.3 h onto CEU30
    // for `P1000247599`, which is the defect this rule was corrected for.
    //
    // **Left out without breaking the run.** A station that does not take a
    // share is transparent to the ones either side of it: it is the same
    // operation, it simply has no work of this part. Walling the group at it
    // would stop two machines sharing work for a reason nobody asked for and
    // nothing on screen would say.
    final indices = [
      for (final i in run)
        if ((steps[i].measured ?? Duration.zero) > Duration.zero) i,
    ];
    if (indices.length < 2) continue;

    // Positive by construction now, so there is no zero-total case left to
    // guard: a group is two or more stations that each have work.
    final total = indices.fold(
      Duration.zero,
      (sum, i) => sum + steps[i].measured!,
    );
    // Asked of the members only. A station sitting out has no cap to fill and
    // its missing schedule is not this group's problem.
    if (indices.any((i) => steps[i].takt == null)) continue;

    // Fill each but the last to its own takt; the last takes what is left.
    // Walked in flow order because "the first workcenter" and "the last
    // workcenter of the same type in the sequence" are positions, not a
    // ranking.
    final derived = <int, Duration>{};
    var remaining = total;
    for (final i in indices.take(indices.length - 1)) {
      final take = steps[i].takt! < remaining ? steps[i].takt! : remaining;
      derived[i] = take;
      remaining -= take;
    }
    derived[indices.last] = remaining;

    groups.add(
      BalanceGroup(
        typeName: type,
        indices: indices,
        measuredTotal: total,
        derived: derived,
      ),
    );
  }

  return groups;
}

/// [balanceFlow]'s answer flattened to the lookup both callers actually want:
/// the derived time for a step, by index, absent where the step is not in a
/// balanced group.
Map<int, Duration> balancedProcessTimes(List<BalanceStep> steps) => {
  for (final group in balanceFlow(steps)) ...group.derived,
};
