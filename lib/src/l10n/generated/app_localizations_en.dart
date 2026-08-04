// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FlowMap';

  @override
  String get navProjects => 'Projects';

  @override
  String get navTemplates => 'Study Templates';

  @override
  String get navResources => 'Resources';

  @override
  String get navSettings => 'Settings';

  @override
  String get navAbout => 'About';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionArchive => 'Archive';

  @override
  String get actionRestore => 'Restore';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClose => 'Close';

  @override
  String get actionDuplicate => 'Duplicate';

  @override
  String get actionRename => 'Rename';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldCode => 'Code';

  @override
  String get fieldType => 'Type';

  @override
  String get fieldNotes => 'Notes';

  @override
  String get fieldStart => 'Start';

  @override
  String get fieldEnd => 'End';

  @override
  String get validationRequired => 'Required';

  @override
  String get validationNameTaken => 'That name is already used here';

  @override
  String get resourcesTitle => 'Resources';

  @override
  String get resourcesEmpty =>
      'No plant yet. Create one to start building studies.';

  @override
  String get resourcesShowArchived => 'Show archived';

  @override
  String get resourcesArchivedBadge => 'Archived';

  @override
  String get plant => 'Plant';

  @override
  String get plantNew => 'New plant';

  @override
  String get plantDeleteBlocked =>
      'This plant has production cells. Archive it instead.';

  @override
  String get productionCell => 'Production cell';

  @override
  String get productionCells => 'Production cells';

  @override
  String get productionCellNew => 'New production cell';

  @override
  String get productionLine => 'Production line';

  @override
  String get productionLines => 'Production lines';

  @override
  String get productionLineNew => 'New production line';

  @override
  String get workcenter => 'Workcenter';

  @override
  String get workcenters => 'Workcenters';

  @override
  String get workcenterNew => 'New workcenter';

  @override
  String get workcenterType => 'Workcenter type';

  @override
  String get workcenterTypes => 'Workcenter types';

  @override
  String get workcenterTypeNew => 'New workcenter type';

  @override
  String get workcenterPool => 'Workcenter pool';

  @override
  String get workcenterPools => 'Workcenter pools';

  @override
  String get workcenterPoolNew => 'New pool';

  @override
  String get workcenterPoolMembers => 'Members';

  @override
  String get workcenterPoolEmpty => 'A pool needs at least one workcenter.';

  @override
  String get shiftPattern => 'Shift pattern';

  @override
  String get shiftPatterns => 'Shift patterns';

  @override
  String get shiftPatternNew => 'New shift pattern';

  @override
  String get shiftPatternCycle => 'Cycle';

  @override
  String get shiftPatternCycleFixedWeekly => 'Fixed weekly';

  @override
  String get shiftPatternCycleRotating => 'Rotating (continuous)';

  @override
  String get shiftPatternWorkingDays => 'Base working days';

  @override
  String get shiftPatternShifts => 'Shifts';

  @override
  String get shiftPatternShiftNew => 'Add shift';

  @override
  String get shiftPatternNoShifts => 'A pattern needs at least one shift.';

  @override
  String get shiftLabel => 'Label';

  @override
  String get shiftStart => 'Start';

  @override
  String get shiftEnd => 'End';

  @override
  String get shiftBreak => 'Break';

  @override
  String get shiftCrossesMidnight => 'Crosses midnight';

  @override
  String get shiftDuration => 'Net duration';

  @override
  String shiftOverlapWarning(String other) {
    return 'This shift overlaps $other.';
  }

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String confirmDeleteTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get confirmDeleteBody => 'This cannot be undone.';

  @override
  String get confirmArchiveBody =>
      'It stays available to projects already using it, but is hidden from pickers.';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String aboutBuild(String build) {
    return 'Build $build';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsDateFormat => 'Date format';

  @override
  String get settingsDateFormatLocale => 'Follow language';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get valueNone => 'None';

  @override
  String get workcenterNameHelp =>
      'What the shop floor calls it, and the label on the process box — e.g. CLAD04.';

  @override
  String get workcenterAddExisting => 'Add existing';

  @override
  String get workcenterAddExistingHelp =>
      'A workcenter belongs to the plant, so this only changes where it appears in the tree. Any study of any line can use it either way.';

  @override
  String get workcenterNoneToAdd =>
      'Every workcenter in this plant is already on this line.';

  @override
  String get workcenterHomeLine => 'Home production line';

  @override
  String get workcenterHomeLineHelp =>
      'Where it appears in the tree. Studies on other lines can still use it, and that shared use is what the simulation contends for.';

  @override
  String get workcenterTypeUnset => 'No type';

  @override
  String get workcenterTypeDeleteBody =>
      'Workcenters using this type keep working; their type is cleared.';

  @override
  String get workcenterPoolNoCandidates => 'This plant has no workcenters yet.';

  @override
  String get resourcesUnassigned => 'Not on a line';

  @override
  String get resourcesUnassignedHelp =>
      'Workcenters that belong to the plant but are not drawn under a production line.';

  @override
  String get shiftPatternRotatingHelp =>
      'Runs every day. Shifts are time windows, not crews — four crews rotating through two 12-hour windows is two shifts here, because capacity comes from the windows covered.';

  @override
  String get shiftPatternEveryDay => 'Every day';

  @override
  String get shiftPatternNoWorkingDays => 'No working days';

  @override
  String shiftPatternOpenPerDay(String duration) {
    return 'Open $duration/day';
  }

  @override
  String get shiftBreakMinutes => 'Break (min)';

  @override
  String shiftBreakOf(String duration) {
    return 'Break $duration';
  }

  @override
  String get projectNew => 'New project';

  @override
  String get projectsEmpty => 'No projects yet.';

  @override
  String get projectMissing => 'That project no longer exists.';

  @override
  String get projectNeedsPlant =>
      'Create a plant in Resources before starting a project.';

  @override
  String get projectPlantHelp =>
      'Cannot be changed later: every study, schedule and flow step in the project points at this plant\'s workcenters.';

  @override
  String get projectPatternHelp =>
      'The shift split every workcenter in this project is staffed against.';

  @override
  String get projectDeleteBody =>
      'Its studies, schedules and flows go with it. This cannot be undone.';

  @override
  String get studyNew => 'New study';

  @override
  String get studiesEmpty => 'No studies in this project yet.';

  @override
  String get studyNameHint => 'Current state';

  @override
  String get studyNeedsLine => 'This plant has no production lines yet.';

  @override
  String get studyLineHelp =>
      'A study belongs to one line. Several studies of the same line are scenarios; only one can be selected for a simulation.';

  @override
  String get studyDeleteBody =>
      'Its flow and annotations go with it. This cannot be undone.';

  @override
  String get studyIncludeInSimulation => 'Include in simulation';

  @override
  String get studyExcludeFromSimulation => 'Exclude from simulation';

  @override
  String get studyTabFlow => 'Flow';

  @override
  String get studyTabTakt => 'Takt';

  @override
  String get studyTabDemand => 'Demand';

  @override
  String get studyTabSummary => 'Summary';

  @override
  String get milestoneSummary => 'The summary arrives with the next milestone.';

  @override
  String get actionMoveUp => 'Move up';

  @override
  String get actionMoveDown => 'Move down';

  @override
  String get validationNotADuration => 'Not a time';

  @override
  String get validationNotADate => 'Not a date';

  @override
  String get validationPositiveWhole => 'A whole number above zero';

  @override
  String get validationUnknownPart => 'No part with that number in this study';

  @override
  String get demandParts => 'Parts';

  @override
  String get demandSequence => 'Sequence';

  @override
  String get demandPartNumber => 'Part number';

  @override
  String get demandDescription => 'Description';

  @override
  String get demandTotal => 'Total';

  @override
  String get demandOrderNumber => 'Order';

  @override
  String get demandBatchSize => 'Batch';

  @override
  String get demandNeedDate => 'Need date';

  @override
  String get demandMaterialDate => 'Material date';

  @override
  String get demandMaterialDateHelp => 'optional';

  @override
  String get demandUnbound => 'not bound';

  @override
  String get demandTimesHelp =>
      'Per piece. Type 30:00:00, 1.5h, 90min or 2d; a bare number is read as hours. Leave a cell blank where the part skips the step. Paste a block from Excel with Ctrl+V.';

  @override
  String get demandSequenceHelp =>
      'The order the plant will build in. Nothing reorders it but you. Paste a block from Excel with Ctrl+V.';

  @override
  String get demandNoSteps =>
      'This flow has no process steps yet, so there is nothing to cost a part against.';

  @override
  String get demandNeedsPart => 'Add a part before adding orders.';

  @override
  String get demandPartDeleteBody =>
      'Its process times go with it, and every order for it leaves the sequence.';

  @override
  String get takt => 'Takt';

  @override
  String get taktUnit => 'Unit';

  @override
  String get taktEmpty => 'No takt defined for this production line yet.';

  @override
  String get taktPeriodNew => 'New takt period';

  @override
  String get taktPeriodDeleteTitle => 'Delete this takt period?';

  @override
  String get taktDaysHelp =>
      'Days are relative to each workcenter\'s own capacity: a 3-day takt is 68 h at a station open 22:40 a day, and 26:24 at one open 8:48.';

  @override
  String get taktLiteralHelp =>
      'Resolves to the same duration at every workcenter.';

  @override
  String get unitDays => 'days';

  @override
  String get unitHours => 'hours';

  @override
  String get unitMinutes => 'minutes';

  @override
  String get unitSeconds => 'seconds';

  @override
  String get unitDaysShort => 'd';

  @override
  String get unitHoursShort => 'h';

  @override
  String get unitMinutesShort => 'min';

  @override
  String get unitSecondsShort => 's';

  @override
  String get schedulePeriodNew => 'New period';

  @override
  String get schedulePeriodDeleteTitle => 'Delete this schedule period?';

  @override
  String get scheduleShifts => 'Shifts';

  @override
  String get scheduleOperatorsPerShift => 'Operators per shift';

  @override
  String scheduleShiftsDerived(String count, String operators) {
    return 'Shifts: $count ($operators) — counted from the shifts with operators, never stored separately.';
  }

  @override
  String get availability => 'Availability';

  @override
  String get availabilityHelp =>
      'Fraction of open time the workcenter can actually run. Applied once, to process time.';

  @override
  String get availabilityInvalid => 'Must be above 0% and at most 100%';

  @override
  String get rework => 'Rework';

  @override
  String get reworkHelp =>
      'Fraction of work that has to be redone. Inflates process time.';

  @override
  String get reworkInvalid => 'Must be 0% or more';

  @override
  String get occupation => 'Occupation';

  @override
  String get workcentersTabEmpty =>
      'Add steps to the flow to schedule their workcenters here.';

  @override
  String workcentersTabPattern(String shifts) {
    return 'Shift pattern: $shifts';
  }

  @override
  String get scheduleIssueEmpty =>
      'No periods defined. Nothing here can be costed until there is at least one.';

  @override
  String scheduleIssueOverlap(String from, String to) {
    return 'Two periods both cover $from to $to.';
  }

  @override
  String scheduleIssueGap(String from, String to) {
    return 'No period covers $from to $to.';
  }

  @override
  String scheduleIssueInverted(String from, String to) {
    return 'A period ends ($to) before it starts ($from).';
  }

  @override
  String get periodPrevious => 'Previous period';

  @override
  String get periodNext => 'Next period';

  @override
  String get periodMonth => 'Month';

  @override
  String get periodQuarterly => 'Quarter';

  @override
  String get periodSemesterly => 'Semester';

  @override
  String get periodYearly => 'Year';

  @override
  String periodQuarter(String quarter, String year) {
    return 'Q$quarter $year';
  }

  @override
  String periodSemester(String half, String year) {
    return 'H$half $year';
  }

  @override
  String get periodVariesHelp =>
      'Takt or staffing changes inside this period. The map shows the state on its first day.';

  @override
  String get footerTaktHelp =>
      'The rhythm of the production line in this period — one unit leaves the line every takt.';

  @override
  String get footerProcessTimeHelp =>
      'Every step\'s process time added up. Value-adding time only; waiting is not counted.';

  @override
  String get footerLeadTimeHelp =>
      'Process time plus every wait between steps — how long one order takes to cross the whole flow.';

  @override
  String get footerPceHelp =>
      'Process cycle efficiency: process time ÷ lead time. The share of elapsed time that is value-adding.';

  @override
  String get flowDataSource => 'Timeline';

  @override
  String get flowSourceEquivalent => 'Flow equivalent';

  @override
  String get flowSourceSinglePart => 'One part (needs demand)';

  @override
  String get flowSourceWeighted => 'All variants, weighted (needs demand)';

  @override
  String get exportPdf => 'Export PDF';

  @override
  String get flowSupplier => 'Supplier';

  @override
  String get flowCustomer => 'Customer';

  @override
  String get flowFitToScreen => 'Fit to screen';

  @override
  String get flowZoomIn => 'Zoom in';

  @override
  String get flowZoomOut => 'Zoom out';

  @override
  String get flowInsertHere => 'Insert here';

  @override
  String get flowInsertStep => 'Process step';

  @override
  String get flowInsertStepHelp => 'Runs on a workcenter or a pool.';

  @override
  String get flowInsertInventory => 'Inventory';

  @override
  String get flowInsertInventoryHelp => 'Where orders wait between steps.';

  @override
  String get flowStep => 'Process step';

  @override
  String get flowInventory => 'Inventory';

  @override
  String get flowStepTarget => 'Workcenter or pool';

  @override
  String get flowStepTargetHelp =>
      'A step runs on exactly one. A pool sends each order to whichever member frees first.';

  @override
  String get flowNodeLabel => 'Label';

  @override
  String get flowNodeLabelHelp => 'Shown instead of the workcenter code.';

  @override
  String get flowMoveLeft => 'Move earlier';

  @override
  String get flowMoveRight => 'Move later';

  @override
  String get flowDeleteNodeTitle => 'Remove this node from the flow?';

  @override
  String get stepProcessTime => 'Process time';

  @override
  String get stepChangeover => 'Changeover';

  @override
  String get stepChangeoverHelp =>
      'Charged only when the previous order on this workcenter was a different part.';

  @override
  String get stepOperators => 'Operators';

  @override
  String get stepEquivalentTime => 'Process specific takt time';

  @override
  String get stepEquivalentFollowsTakt => 'Follows takt';

  @override
  String get stepEquivalentHelp =>
      'This step\'s own takt, used by the flow equivalent instead of the line\'s. Leave blank to follow the line\'s takt. Set it where a full takt would skew the balance — an inspection worth a fraction of one. Days are this station\'s productive days, so 1 day equals one takt-day.';

  @override
  String get stepProblemUnbound => 'No workcenter or pool selected.';

  @override
  String get stepProblemArchived =>
      'Its workcenter has been archived or deleted.';

  @override
  String get stepProblemNoSchedule => 'No schedule period covers this month.';

  @override
  String get stepProblemEmptyPool => 'This pool has no members.';

  @override
  String stepPoolMembers(String count) {
    return 'Pool · $count workcenters';
  }

  @override
  String get inventoryModeQuantity => 'Pieces';

  @override
  String get inventoryModeDuration => 'Fixed wait';

  @override
  String get inventoryPieces => 'Pieces waiting';

  @override
  String get inventoryPiecesHelp =>
      'Counted as days of stock: pieces × takt of the period being viewed.';

  @override
  String get inventoryWait => 'Wait';

  @override
  String get inventoryWaitHelp =>
      'A day is 24 hours here. Whether those hours pass on the clock or only while the plant runs is the switch below.';

  @override
  String get inventoryWorkingTime => 'Working time only';

  @override
  String get inventoryWorkingTimeHelp =>
      'Off for cooling or transport, which do not stop for the weekend. On for a queue that only moves while the plant runs.';

  @override
  String get footerProcessTime => 'Process time';

  @override
  String get footerLeadTime => 'Lead time';

  @override
  String get footerPce => 'PCE';

  @override
  String get footerEndDate => 'End date';

  @override
  String footerRunningDays(String days, String date) {
    return '$days running days · $date';
  }

  @override
  String get footerEndDateHelp =>
      'When one order starting on the first day of this period would finish, walked through the real calendars. The gap against lead time is the weekends and shutdowns.';

  @override
  String pdfGenerated(String build, String timestamp) {
    return 'FlowMap $build · generated $timestamp';
  }

  @override
  String pdfSaved(String path) {
    return 'Saved to $path';
  }
}
