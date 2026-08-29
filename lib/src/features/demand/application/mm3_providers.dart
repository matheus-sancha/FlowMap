import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../flow/application/flow_providers.dart';
import 'demand_providers.dart';
import 'demand_table.dart';
import 'mm3.dart';

part 'mm3_providers.g.dart';

/// The scope MM3 is measured over, chosen by the user.
///
/// Kept separate from the series so switching scope does not reassemble the
/// steps — and so "not chosen yet" can resolve to the busiest station rather
/// than to a stored id that may no longer be in the flow.
@riverpod
class Mm3ScopeSelection extends _$Mm3ScopeSelection {
  /// Null is "not chosen yet", which resolves to the busiest station; the
  /// empty string is the whole flow, chosen deliberately. Two different
  /// answers, so they need two different values.
  @override
  String? build(String studyId) => null;

  static const wholeFlow = '';

  void select(String? targetId) => state = targetId;
}

/// The flow's steps, reduced to what MM3 needs from each.
///
/// Reads the flow view rather than recomputing capacity: the yardstick is the
/// same figure the map's boxes are drawn from, so the two can never disagree
/// about what one takt of a station is worth.
final mm3StepsProvider = Provider.family<List<Mm3Step>, String>((ref, studyId) {
  final view = ref.watch(flowViewProvider(studyId)).value;
  if (view == null) return const [];

  return [
    for (final step in view.steps)
      if (demandTargetOf(step.node) case final targetId?)
        Mm3Step(
          nodeId: step.node.id,
          targetId: targetId,
          equivalentProcessTime: step.equivalentProcessTime,
          rework: step.rework ?? 0,
        ),
  ];
});

/// The measured sequence, ready to draw.
final mm3SeriesProvider = Provider.family<Mm3Series?, String>((ref, studyId) {
  final table = ref.watch(demandTableProvider(studyId));
  final orders = ref.watch(demandOrdersProvider(studyId)).value;
  if (table == null || orders == null) return null;

  final steps = ref.watch(mm3StepsProvider(studyId));
  final chosen = ref.watch(mm3ScopeSelectionProvider(studyId));

  final String? targetId;
  if (chosen == Mm3ScopeSelection.wholeFlow) {
    targetId = null;
  } else {
    targetId =
        chosen ?? busiestTargetId(orders: orders, table: table, steps: steps);
  }

  // A target the flow no longer contains falls back to the whole flow rather
  // than measuring against nothing.
  final column = table.columns
      .where((c) => c.targetId == targetId)
      .firstOrNull;

  return computeMm3(
    scope: Mm3Scope(
      targetId: column?.targetId,
      title: column?.title ?? '',
    ),
    orders: orders,
    table: table,
    steps: steps,
  );
});

/// The scopes the selector offers: the whole flow, then each bound step.
final mm3ScopesProvider = Provider.family<List<DemandColumn>, String>((
  ref,
  studyId,
) {
  final table = ref.watch(demandTableProvider(studyId));
  if (table == null) return const [];
  return [
    for (final column in table.columns)
      if (column.targetId != null) column,
  ];
});
