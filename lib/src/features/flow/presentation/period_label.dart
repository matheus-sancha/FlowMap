import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../application/flow_view.dart';

/// How a viewed span is written: `Aug 2026`, `Q3 2026`, `H2 2026`, `2026`.
///
/// Quarters and semesters have no `intl` pattern — they are business periods,
/// not calendar ones — so they are composed from a number and the year rather
/// than formatted.
String periodLabel(
  BuildContext context,
  DateTime anchor,
  PeriodGranularity granularity,
) {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toString();

  return switch (granularity) {
    PeriodGranularity.month => DateFormat.yMMM(locale).format(anchor),
    PeriodGranularity.quarter => l10n.periodQuarter(
      '${((anchor.month - 1) ~/ 3) + 1}',
      '${anchor.year}',
    ),
    PeriodGranularity.semester => l10n.periodSemester(
      '${anchor.month <= 6 ? 1 : 2}',
      '${anchor.year}',
    ),
    PeriodGranularity.year => '${anchor.year}',
  };
}

String granularityLabel(AppLocalizations l10n, PeriodGranularity granularity) =>
    switch (granularity) {
      PeriodGranularity.month => l10n.periodMonth,
      PeriodGranularity.quarter => l10n.periodQuarterly,
      PeriodGranularity.semester => l10n.periodSemesterly,
      PeriodGranularity.year => l10n.periodYearly,
    };

/// Which numbers the map is showing. Shared by the toolbar's selector and the
/// PDF's header, so an exported map cannot name a source the app was not
/// showing — an exhaustive switch, so M3's two sources cannot be added without
/// this being updated.
String flowDataSourceLabel(AppLocalizations l10n, FlowDataSource source) =>
    switch (source) {
      FlowDataSource.flowEquivalent => l10n.flowSourceEquivalent,
      FlowDataSource.singlePart => l10n.flowSourceSinglePart,
      FlowDataSource.weightedVariants => l10n.flowSourceWeighted,
    };
