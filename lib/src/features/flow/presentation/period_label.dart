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

/// The same span written for a **column heading**: `Aug/26`, `Q3 2026`,
/// `H2 2026`, `2026`.
///
/// **Only the month differs from [periodLabel]**, and it differs because a
/// heading is read in a narrow column beside eleven others: `Aug 2026` spells
/// out the century, which no column in this app has ever needed. The coarser
/// grains are already as short as they go.
///
/// **The same `MMM/yy` the float matrix has always used**, so the two period
/// matrices in the app write a month the same way — and locale-aware, which
/// `period_matrix.dart`'s own default was not until they were matched.
///
/// *Not numeric.* `08/26` is a character narrower and the same in every locale,
/// and it was tried; a month name is what a reader recognises without counting.
/// The width it costs is real and paid in [PeriodMatrix.defaultMonthWidth]:
/// Portuguese abbreviates with a trailing point (`ago./26`) and Spanish
/// September is four letters (`sept/26`), so the widest heading is not the
/// English one.
String periodColumnLabel(
  BuildContext context,
  DateTime anchor,
  PeriodGranularity granularity,
) => granularity == PeriodGranularity.month
    ? DateFormat('MMM/yy', Localizations.localeOf(context).toString())
          .format(anchor)
    : periodLabel(context, anchor, granularity);

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
