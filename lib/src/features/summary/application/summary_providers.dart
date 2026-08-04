import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../demand/application/demand_providers.dart';
import '../../flow/application/flow_providers.dart';
import 'summary_view.dart';

/// The Summary for the study at the period the navigator is on.
///
/// Shares [viewedPeriodProvider] with the map, deliberately: a user who steps
/// the Flow tab to `Sep 2026` and then opens Summary is asking about September,
/// and a second period control would be a second answer to the same question.
final summaryViewProvider = Provider.family<SummaryView?, String>((
  ref,
  studyId,
) {
  final flow = ref.watch(flowViewProvider(studyId)).value;
  final demand = ref.watch(demandTableProvider(studyId));
  final orders = ref.watch(demandOrdersProvider(studyId)).value;
  if (flow == null || demand == null || orders == null) return null;

  return buildSummary(flow: flow, demand: demand, orders: orders);
});
