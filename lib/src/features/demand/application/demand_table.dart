/// The demand grid as it is drawn, pasted into and validated — a pure function
/// of the study's parts, their stored process times and the flow's current
/// steps (DESIGN.md §9).
///
/// Nothing here queries or renders, so every rule about blank cells and totals
/// is testable without a database or a widget tree.
library;

import '../../../data/database/database.dart';
import '../../../data/database/enums.dart';
import '../../flow/application/flow_view.dart' show flowStepTitle;

/// One column of the grid: a flow step, and the id its process times are keyed
/// by.
class DemandColumn {
  const DemandColumn({
    required this.nodeId,
    required this.targetId,
    required this.title,
  });

  /// The flow node this column was drawn from, and **what its process time is
  /// keyed by** since §9.
  ///
  /// Two columns may share a [targetId] — a part that visits one station twice
  /// — and until v24 they were two columns over *one* stored value, on the
  /// argument that the station takes the same time per piece on both passes.
  /// Driving §8.6 overturned that: a routing revisits a machine because the
  /// second pass is a different operation, and the model could not say so. They
  /// are two independent cells now.
  final String nodeId;

  /// The workcenter or pool the step targets, or null when the step is unbound.
  /// An unbound step is a blocking readiness error (§11); the column is drawn
  /// so the hole is visible, but nothing can be typed into it.
  final String? targetId;

  /// What the process box is labelled — the column header.
  final String title;
}

/// The id a step's process times are keyed by (DESIGN.md §9).
///
/// **The pool, when the step targets one** — never the member that happens to
/// stand for it on the map. Pool members are interchangeable by definition
/// (§3.1), so a part has one process time at `CNC Lathes`, not four.
String? demandTargetOf(FlowNode step) => step.poolId ?? step.workcenterId;

/// The columns of the demand grid, in flow order.
///
/// Built from the flow's nodes rather than from a [FlowView], deliberately: the
/// view is what the *map* shows and now depends on this table to show a real
/// part (§5.4), so reading it here would close a cycle. The header is
/// [flowStepTitle], the same rule the process box uses, so a step renamed on
/// the map renames its column.
List<DemandColumn> demandColumnsOf({
  required List<FlowNode> nodes,
  required Map<String, String> workcenterNames,
  required Map<String, String> poolNames,
}) => [
  for (final node in nodes)
    if (node.kind == FlowNodeKind.step)
      DemandColumn(
        nodeId: node.id,
        targetId: demandTargetOf(node),
        title: flowStepTitle(
          node,
          workcenterName: workcenterNames[node.workcenterId],
          poolName: poolNames[node.poolId],
        ),
      ),
];

/// The parts, the columns and the cells between them.
class DemandTable {
  const DemandTable({
    required this.parts,
    required this.columns,
    required this.times,
  });

  final List<DemandPart> parts;
  final List<DemandColumn> columns;

  /// `partId → nodeId → per-piece time`, as the repository loads it (§9).
  ///
  /// **A cell is absent, not zero, when a part skips a step** (§5.1). The whole
  /// grid rests on that distinction: a blank means "not routed here" and costs
  /// nothing, a zero means "takes no time" and is almost always a typo.
  final Map<String, Map<String, Duration>> times;

  /// **Keyed by the node, not the target.** Passing a target id compiles and
  /// returns null — a part silently uncosted rather than a build failure —
  /// which is why §9 visited every call site by hand.
  Duration? timeFor(String partId, String? nodeId) =>
      nodeId == null ? null : times[partId]?[nodeId];

  /// What one piece of [partId] costs across the whole flow — the numerator of
  /// `eq(part, flow)` (§6.2).
  ///
  /// Summed over the **columns**, not over the stored rows: a station visited
  /// twice is paid for twice, and a stored time for a step no longer in the
  /// flow is not paid for at all.
  Duration totalFor(String partId) {
    var total = Duration.zero;
    for (final column in columns) {
      total += timeFor(partId, column.nodeId) ?? Duration.zero;
    }
    return total;
  }

  /// Whether [partId] has a time at every column of the flow.
  ///
  /// Reported rather than defaulted: a part with no time at a step it must
  /// visit is a blocking readiness error, and the panel has to be able to name
  /// the part and the step (§11).
  bool isFullyCosted(String partId) =>
      columns.every((c) => timeFor(partId, c.nodeId) != null);

  /// Every (part, column) pair with no time — what the readiness panel lists.
  Iterable<({DemandPart part, DemandColumn column})> get missingCells sync* {
    for (final part in parts) {
      for (final column in columns) {
        if (timeFor(part.id, column.nodeId) == null) {
          yield (part: part, column: column);
        }
      }
    }
  }
}
