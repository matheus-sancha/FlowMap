/// The glyphs and names behind [WorkcenterIcon].
///
/// The enum itself lives in `data/database/enums.dart`, because it is stored;
/// this is the presentation half, exactly as `unit_labels.dart` is for the
/// takt units. The data layer must not import `material.dart` — it exports a
/// `Table` widget that shadows Drift's, and the collision turns every generated
/// accessor into an undefined name.
library;

import 'package:flutter/material.dart';

import '../data/database/enums.dart';
import '../l10n/generated/app_localizations.dart';

/// What a workcenter of an untyped or icon-less type is drawn as.
const fallbackWorkcenterIcon = Icons.precision_manufacturing_outlined;

/// The glyph itself.
///
/// An exhaustive switch of `const` references, deliberately: Flutter's icon
/// tree-shaking drops every glyph the compiler cannot see referenced, so an
/// `IconData` built from a codepoint read out of the database is a blank box in
/// release and correct in debug. This way the compiler sees all of them, and
/// adding a member to the enum without a glyph is a compile error — the same
/// argument as `taktUnitLabel`'s (DESIGN.md §16.3).
IconData workcenterIconGlyph(WorkcenterIcon icon) => switch (icon) {
  WorkcenterIcon.machining => Icons.precision_manufacturing_outlined,
  WorkcenterIcon.lathe => Icons.rotate_right,
  WorkcenterIcon.milling => Icons.blur_circular_outlined,
  WorkcenterIcon.drilling => Icons.vertical_align_bottom,
  WorkcenterIcon.grinding => Icons.circle_outlined,
  WorkcenterIcon.cutting => Icons.content_cut,
  WorkcenterIcon.bending => Icons.turn_right_outlined,
  WorkcenterIcon.press => Icons.compress,
  WorkcenterIcon.welding => Icons.bolt_outlined,
  WorkcenterIcon.cladding => Icons.layers_outlined,
  WorkcenterIcon.heatTreatment => Icons.local_fire_department_outlined,
  WorkcenterIcon.coating => Icons.opacity_outlined,
  WorkcenterIcon.painting => Icons.format_paint_outlined,
  WorkcenterIcon.cleaning => Icons.wash_outlined,
  WorkcenterIcon.assembly => Icons.handyman_outlined,
  WorkcenterIcon.robot => Icons.smart_toy_outlined,
  WorkcenterIcon.conveyor => Icons.conveyor_belt,
  WorkcenterIcon.inspection => Icons.search_outlined,
  WorkcenterIcon.testing => Icons.science_outlined,
  WorkcenterIcon.measuring => Icons.straighten_outlined,
  WorkcenterIcon.packing => Icons.inventory_2_outlined,
  WorkcenterIcon.storage => Icons.warehouse_outlined,
};

/// What the picker calls it.
String workcenterIconLabel(AppLocalizations l10n, WorkcenterIcon icon) =>
    switch (icon) {
      WorkcenterIcon.machining => l10n.iconMachining,
      WorkcenterIcon.lathe => l10n.iconLathe,
      WorkcenterIcon.milling => l10n.iconMilling,
      WorkcenterIcon.drilling => l10n.iconDrilling,
      WorkcenterIcon.grinding => l10n.iconGrinding,
      WorkcenterIcon.cutting => l10n.iconCutting,
      WorkcenterIcon.bending => l10n.iconBending,
      WorkcenterIcon.press => l10n.iconPress,
      WorkcenterIcon.welding => l10n.iconWelding,
      WorkcenterIcon.cladding => l10n.iconCladding,
      WorkcenterIcon.heatTreatment => l10n.iconHeatTreatment,
      WorkcenterIcon.coating => l10n.iconCoating,
      WorkcenterIcon.painting => l10n.iconPainting,
      WorkcenterIcon.cleaning => l10n.iconCleaning,
      WorkcenterIcon.assembly => l10n.iconAssembly,
      WorkcenterIcon.robot => l10n.iconRobot,
      WorkcenterIcon.conveyor => l10n.iconConveyor,
      WorkcenterIcon.inspection => l10n.iconInspection,
      WorkcenterIcon.testing => l10n.iconTesting,
      WorkcenterIcon.measuring => l10n.iconMeasuring,
      WorkcenterIcon.packing => l10n.iconPacking,
      WorkcenterIcon.storage => l10n.iconStorage,
    };
