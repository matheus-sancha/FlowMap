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
  /// demand table. Null and zero are the same thing here — nothing measured
  /// contributes nothing to the total.
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
/// **Fill each to its own takt and leave the remainder on the last**, which is
/// what was asked for. The last station is the one allowed to be under or over:
/// under when the group has slack, over when it is the bottleneck, and either
/// way the overflow is visible at the end of the run rather than smeared across
/// it where nobody would see it.
///
/// **A group whose takt cannot be resolved is not balanced at all.** One member
/// with no schedule and there is no cap to fill to, so the split would be an
/// invention — the measured figures stand and the step's own readiness problem
/// says why. The same for a group nothing was measured in: zero split four ways
/// is four zeroes, and a zero is a number someone will add up (§11).
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

    final indices = [for (var i = start; i <= end; i++) i];
    start = end + 1;
    if (indices.length < 2) continue;

    final total = indices.fold(
      Duration.zero,
      (sum, i) => sum + (steps[i].measured ?? Duration.zero),
    );
    if (total == Duration.zero) continue;
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
