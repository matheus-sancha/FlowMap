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
  String get plantNew => 'New Plant';

  @override
  String get productionCell => 'Production cell';

  @override
  String get productionCells => 'Production cells';

  @override
  String get productionCellNew => 'New Production Cell';

  @override
  String get productionLine => 'Production line';

  @override
  String get productionLines => 'Production lines';

  @override
  String get productionLineNew => 'New Production Line';

  @override
  String get workcenter => 'Workcenter';

  @override
  String get studyTabCapacity => 'Capacity';

  @override
  String get exceptionsScope =>
      'Applies to the whole project — every study in it.';

  @override
  String get projectSettings => 'Project settings';

  @override
  String get projectSettingsIdentity => 'Identity';

  @override
  String get projectPatternHelp =>
      'The shift pattern every workcenter in this project reads its open hours from. Changing it re-times every station, and every figure derived from one.';

  @override
  String get calendarExceptions => 'Exceptions';

  @override
  String get schedulesTaktScope => 'shared by every study on this line';

  @override
  String get schedulesStationsScope => 'this study\'s flow';

  @override
  String get workcenters => 'Workcenters';

  @override
  String get workcenterNew => 'New Workcenter';

  @override
  String get workcenterType => 'Workcenter type';

  @override
  String get workcenterTypes => 'Workcenter types';

  @override
  String get workcenterTypeNew => 'New workcenter type';

  @override
  String get workcenterLines => 'Drawn under these lines';

  @override
  String get workcenterLinesHelp =>
      'Organisational only. Any study of any line can use this workcenter whichever boxes are ticked, and a station that serves two lines belongs under both.';

  @override
  String get workcenterNoLines => 'This plant has no production lines yet.';

  @override
  String workcenterOnLines(String count) {
    return 'on $count lines';
  }

  @override
  String workcenterRemoveFromLine(String line) {
    return 'Take out of $line';
  }

  @override
  String get workcenterDeleteBody =>
      'This removes the workcenter from the plant, not just from this line. Its schedules go with it.';

  @override
  String get workcenterTypeIcon => 'Icon';

  @override
  String get workcenterTypeLabourPaced => 'Operators set the pace';

  @override
  String get workcenterCapacityType => 'Workcenter Capacity Type';

  @override
  String get workcenterCapacityMachine => 'Machine Pace';

  @override
  String get workcenterCapacityOperator => 'Operator Pace';

  @override
  String get workcenterTypeLabourPacedHelp =>
      'Machine Pace: the machine runs at its own rate whoever is standing at it, and the crew only opens the shift — a second operator on one CNC does not double its output. Operator Pace: a bench, a booth or an inspection table, where the crew on shift is the throughput. Process times are entered as one operator\'s work either way.';

  @override
  String get workcenterTypeNone => 'No icon';

  @override
  String get workcenterTypeEdit => 'Workcenter type';

  @override
  String get iconMachining => 'Machining';

  @override
  String get iconLathe => 'Lathe';

  @override
  String get iconMilling => 'Milling';

  @override
  String get iconDrilling => 'Drilling';

  @override
  String get iconGrinding => 'Grinding';

  @override
  String get iconCutting => 'Cutting';

  @override
  String get iconBending => 'Bending';

  @override
  String get iconPress => 'Press';

  @override
  String get iconWelding => 'Welding';

  @override
  String get iconCladding => 'Cladding';

  @override
  String get iconHeatTreatment => 'Heat treatment';

  @override
  String get iconCoating => 'Coating';

  @override
  String get iconPainting => 'Painting';

  @override
  String get iconCleaning => 'Cleaning';

  @override
  String get iconAssembly => 'Assembly';

  @override
  String get iconRobot => 'Robot';

  @override
  String get iconConveyor => 'Conveyor';

  @override
  String get iconInspection => 'Inspection';

  @override
  String get iconTesting => 'Testing';

  @override
  String get iconMeasuring => 'Measuring';

  @override
  String get iconPacking => 'Packing';

  @override
  String get iconStorage => 'Storage';

  @override
  String get workcenterPool => 'Workcenter pool';

  @override
  String get workcenterPools => 'Workcenter pools';

  @override
  String get workcenterPoolNew => 'New Pool';

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
  String get shiftPatternCycleFixedWeekly => 'Fixed Weekly';

  @override
  String get shiftPatternCycleRotating => 'Rotating (Continuous)';

  @override
  String get shiftPatternWorkingDays => 'Base working days';

  @override
  String get shiftPatternShifts => 'Shifts';

  @override
  String get shiftPatternShiftNew => 'Add Shift';

  @override
  String get shiftPatternNoShifts => 'A pattern needs at least one shift.';

  @override
  String get shiftLabel => 'Label';

  @override
  String get shiftStart => 'Start';

  @override
  String get shiftEnd => 'End';

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
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'Follow the system';

  @override
  String get settingsDateFormat => 'Date format';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get valueNone => 'None';

  @override
  String get workcenterAddExisting => 'Add Existing';

  @override
  String get workcenterNoneToAdd =>
      'Every workcenter in this plant is already on this line.';

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
  String get projectNew => 'New Project';

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
  String get projectDeleteBody =>
      'Its studies, schedules and flows go with it. This cannot be undone.';

  @override
  String get study => 'Study';

  @override
  String get studyNew => 'New Study';

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
  String get studiesCollapse => 'Hide the studies list';

  @override
  String get studiesExpand => 'Show the studies list';

  @override
  String get studyTabSettings => 'Study Settings';

  @override
  String get studyTabTakt => 'Flow Takt';

  @override
  String get studySettingsIdentity => 'Identity';

  @override
  String get studySettingsInRuns => 'Simulation settings';

  @override
  String get studyName => 'Name';

  @override
  String get studyLine => 'Production line';

  @override
  String get studyIncludeInRuns => 'Include in simulation';

  @override
  String get studyIncludeInRunsHelp =>
      'A run takes every included study at once, contending for the same plant.';

  @override
  String get studyWipCap => 'WIP cap';

  @override
  String get studyWipCapUnlimited => 'Unlimited';

  @override
  String get studyWipCapHelp =>
      'The most orders this study may have in the flow at once. A release waits for a completion, which is what makes the flow pulled rather than pushed. Blank is unlimited.';

  @override
  String get studyTabFlow => 'Flow';

  @override
  String get studyTabDemand => 'Demand';

  @override
  String get studyTabSummary => 'Summary';

  @override
  String get actionMoveUp => 'Move up';

  @override
  String get actionMoveDown => 'Move down';

  @override
  String get validationNotADuration => 'Not a time';

  @override
  String get validationNotADate => 'Not a date';

  @override
  String get validationPositiveNumber => 'A number above zero';

  @override
  String get validationUnknownUnit => 'Not a unit — try days, hours, min or s';

  @override
  String get validationNotAPercentage => 'A percentage between 0 and 100';

  @override
  String get validationPositiveWhole => 'A whole number above zero';

  @override
  String get validationUnknownPart => 'No part with that number in this study';

  @override
  String get stepProblemNoProcessTime => 'This part has no process time here.';

  @override
  String get stepEquivalence => 'Equivalent';

  @override
  String get footerEquivalence => 'Equivalent';

  @override
  String get footerEquivalenceHelp =>
      'This part\'s process time across the flow divided by the flow equivalent\'s. 1.13 means it consumes 1.13 takts of the line\'s capacity.';

  @override
  String get flowSourceNeedsDemand =>
      'Needs at least one part in the Demand tab';

  @override
  String get mm3 => 'MM3';

  @override
  String get mm3Column => 'MM3';

  @override
  String get mm3Scope => 'Measured over';

  @override
  String get mm3WholeFlow => 'Whole flow';

  @override
  String get mm3Smoothness => 'Average deviation';

  @override
  String get mm3SmoothnessHelp =>
      'How far the moving average sits from 1.0 on average. 1.0 is one takt of the scope\'s capacity per order, which is a perfectly levelled sequence.';

  @override
  String get mm3SlotLoad => 'Slot load';

  @override
  String get mm3NoSequence => 'No orders in the sequence yet.';

  @override
  String get mm3NotMeasurable =>
      'Nothing to measure yet: the parts in this sequence have no process times in this scope.';

  @override
  String get mm3Help =>
      'A centred moving average of three over the sequence, blank at both ends.';

  @override
  String get summaryOccupation => 'Occupation by workcenter';

  @override
  String get summaryDemandTakt => 'Demand takt';

  @override
  String get summaryRequired => 'Required';

  @override
  String get summaryAvailable => 'Available';

  @override
  String get summaryOperatorsAllocated => 'Operators allocated';

  @override
  String get summaryOperatorsNeeded => 'Operators needed';

  @override
  String get summaryNoSteps => 'This flow has no bound process steps yet.';

  @override
  String get summaryNothingToRank =>
      'Nothing to rank yet: no step has both a schedule and demand.';

  @override
  String get summaryOverloaded =>
      'Above 100 %: this station cannot do it however the sequence is arranged.';

  @override
  String get summaryWithinCapacity => 'Within capacity for this period.';

  @override
  String get summaryNoDemandTakt =>
      'No demand takt yet: it needs a station with hours and orders due in this period.';

  @override
  String summaryBottleneck(String name, String occupation) {
    return 'Bottleneck: $name at $occupation';
  }

  @override
  String summaryOrdersDue(String count) {
    return '$count orders due';
  }

  @override
  String summaryVisitsHelp(String count) {
    return 'The flow routes through this station $count times, and every visit loads it.';
  }

  @override
  String summaryMissingTimes(String count) {
    return '$count parts due here have no process time, so the required hours are an understatement.';
  }

  @override
  String summaryRequiredHelp(
    String work,
    String changeovers,
    String changeover,
  ) {
    return '$work of process time plus $changeovers changeovers worth $changeover.';
  }

  @override
  String summaryOccupationHelp(
    String occupation,
    String required,
    String available,
  ) {
    return '$occupation = $required required over $available available.';
  }

  @override
  String summaryPaceSetter(String name, String available) {
    return 'Measured at $name, the busiest station, which has $available available this period.';
  }

  @override
  String get summaryTaktConfigured => 'Configured takt';

  @override
  String get summaryTaktConfiguredHelp =>
      'The takt this line is set to run at, resolved at the pace-setting station.';

  @override
  String get summaryTaktRaw => 'Raw demand takt';

  @override
  String summaryTaktRawHelp(String orders) {
    return 'Available time over $orders orders due. What a visitor expects.';
  }

  @override
  String get summaryTaktAdjusted => 'Equivalent-adjusted demand takt';

  @override
  String summaryTaktAdjustedHelp(String equivalents) {
    return 'Available time over $equivalents part-equivalents due. What actually matters under a mixed part mix: an order worth two takts of work counts twice.';
  }

  @override
  String get actionImport => 'Import';

  @override
  String importTitle(String file) {
    return 'Import from $file';
  }

  @override
  String get importSheet => 'Sheet';

  @override
  String get importMapping => 'Their columns to ours';

  @override
  String get importNotMapped => 'Not mapped';

  @override
  String importColumnNumber(String n) {
    return 'Column $n';
  }

  @override
  String importUnmapped(String columns) {
    return 'Nothing found for: $columns. Those values will be left as they are.';
  }

  @override
  String get importPreview => 'What will go in';

  @override
  String importCountOk(String count) {
    return '$count rows ready';
  }

  @override
  String importCountSkipped(String count) {
    return '$count skipped';
  }

  @override
  String importCountWarned(String count) {
    return '$count to look at';
  }

  @override
  String importPreviewTruncated(String count) {
    return 'and $count more rows';
  }

  @override
  String importAccept(String count) {
    return 'Import $count Rows';
  }

  @override
  String importDone(String count) {
    return 'Imported $count rows.';
  }

  @override
  String importFailed(String error) {
    return 'Nothing was imported: $error';
  }

  @override
  String importUnreadable(String error) {
    return 'That file could not be read: $error';
  }

  @override
  String get importEmpty => 'That file has no rows under a heading row.';

  @override
  String get importIssueMissingPart => 'No part number';

  @override
  String get importIssueDuplicatePart => 'This part appears twice in the file';

  @override
  String get importIssueNeedBeforeMaterial =>
      'Needed before its material arrives';

  @override
  String get fieldNote => 'Note';

  @override
  String get exceptions => 'Calendar exceptions';

  @override
  String get exceptionNew => 'New Exception';

  @override
  String get exceptionsEmpty =>
      'None. The plant runs its shift pattern every working day.';

  @override
  String get exceptionsHelp =>
      'Holidays, shutdowns and extra hours. The most specific scope wins, so a plant-wide shutdown can be overridden by opening one workcenter that Saturday.';

  @override
  String get exceptionKindNonWorking => 'Closed';

  @override
  String get exceptionKindExtraWorking => 'Extra Hours';

  @override
  String get exceptionScope => 'Applies to';

  @override
  String get exceptionScopePlant => 'Whole plant';

  @override
  String get exceptionScopeHelp =>
      'A pool can be chosen under Workcenter; it is saved as one exception per member.';

  @override
  String get exceptionOperatorsHelp =>
      'Who is on each shift that day. A zero closes that shift.';

  @override
  String get exceptionDeleteTitle => 'Delete this exception?';

  @override
  String get flowEndpointRename => 'Rename endpoint';

  @override
  String get demandProject => 'Project';

  @override
  String get demandDeleteAll => 'Delete All Orders';

  @override
  String get demandDeleteAllBody =>
      'Every order in the sequence goes. The parts and their process times stay.';

  @override
  String get stepCycleTime => 'Takt C/T';

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
  String get demandBatchSize => 'Batch size';

  @override
  String get demandBatchNumber => 'Batch no.';

  @override
  String get demandBatchNumberHelp =>
      'Your own identifier for this batch of this part — whatever the paperwork calls it. Free text: nothing matches on it, duplicates are allowed and it may be left blank. It appears on the production plan so a printed order can be found in your system.';

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
      'Per piece. Type 30:00:00, 1.5h, 90min or 2d; a bare number is read as hours. Leave a cell blank where the part skips the step.';

  @override
  String get demandSequenceHelp =>
      'The order the plant will build in. Nothing reorders it but you.';

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
  String get taktPeriodDeleteTitle => 'Delete this takt period?';

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
  String get schedulePeriodDeleteTitle => 'Delete this schedule period?';

  @override
  String get scheduleShifts => 'Shifts';

  @override
  String get scheduleOperatorsPerShift => 'Operators per shift';

  @override
  String get scheduleOperatorsHelp =>
      'How many people are on each shift. A zero closes that shift. Whether more of them finish the work sooner is a property of the workcenter\'s type, not of this number — turn on “Operators set the pace” under Resources › Workcenter types, or the crew only opens the shift.';

  @override
  String get availability => 'Availability';

  @override
  String get rework => 'Rework';

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
  String get flowSourceEquivalent => 'Flow equivalent';

  @override
  String get flowSourceSinglePart => 'One part (needs demand)';

  @override
  String get flowSourceWeighted => 'All variants, weighted (needs demand)';

  @override
  String get exportPdf => 'Export PDF';

  @override
  String get flowShowing => 'Showing';

  @override
  String get flowSupplier => 'Supplier';

  @override
  String get flowCustomer => 'Customer';

  @override
  String get flowFitToScreen => 'Fit to Screen';

  @override
  String get flowZoomIn => 'Zoom in';

  @override
  String get flowZoomOut => 'Zoom out';

  @override
  String get flowInsertHere => 'Insert here';

  @override
  String get flowInsertStep => 'Process step';

  @override
  String get flowStep => 'Process step';

  @override
  String get flowStepTarget => 'Workcenter or pool';

  @override
  String get flowStepTargetHelp =>
      'A step runs on exactly one. A pool sends each order to whichever member frees first.';

  @override
  String get flowNodeNotes => 'Notes';

  @override
  String get flowMoveLeft => 'Move earlier';

  @override
  String get flowMoveRight => 'Move later';

  @override
  String get flowDeleteNodeTitle => 'Remove this node from the flow?';

  @override
  String get stepProcessTime => 'Process time';

  @override
  String get stepSetup => 'Setup';

  @override
  String get stepTeardown => 'Teardown';

  @override
  String get stepTeardownHelp =>
      'Stripping the station after an order. Charged together with the next order’s setup, because whether a strip-down is needed depends on what comes next.';

  @override
  String get stepSamePart => 'Same part';

  @override
  String get stepSamePartHelp =>
      'How much of the setup and teardown is still charged when the previous order was the same part. 0% makes a repeat free; 100% means batching buys nothing.';

  @override
  String get stepChangeover => 'Changeover';

  @override
  String get laneCapacity => 'Lane capacity (orders)';

  @override
  String get laneCapacityHelp =>
      'How many orders fit here. Leave blank for unlimited. When it is full the station behind cannot put its finished order down and stops, which is how congestion reaches back up the line. Separate from the pieces above: that figure is what is standing here today, this is what the floor allows.';

  @override
  String get workcenterParallelCapacity => 'Orders at once';

  @override
  String get workcenterParallelCapacityHelp =>
      'How many orders this station runs side by side. One is a single machine. Above one it has that many independent units, each paying its own changeovers — and twice the capacity everywhere it is measured. Use a pool instead when the machines are really separate and you want to see which ran what.';

  @override
  String get studyStartBuffer => 'Start buffer (calendar days)';

  @override
  String get studyStartBufferHelp =>
      'Extra margin ahead of the calculated start. A run begins at the first order\'s need date, less its theoretical lead time, less this. Calendar days, because slippage happens whether or not the plant is open.';

  @override
  String get studyPaceSetter => 'Pacemaker';

  @override
  String get studyPaceSetterHelp =>
      'The station whose clock sets the release cadence, and whose lane decides when another order may start. Leave on automatic to use the busiest step.';

  @override
  String get studyPaceSetterAutomatic => 'Automatic — the busiest step';

  @override
  String get simBlocked => 'Blocked';

  @override
  String get simBlockedHelp =>
      'Time the station spent holding a finished order because the lane ahead was full. Not counted as busy: a jammed station is occupied and producing nothing.';

  @override
  String get simEmptySlotLaneFull => 'Lane full';

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
  String get inventoryModeDuration => 'Fixed Wait';

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
  String get footerProcessTime => 'Process time';

  @override
  String get footerLeadTime => 'Lead time (working days)';

  @override
  String get footerLeadTimeRunning => 'Lead time (running days)';

  @override
  String get footerLeadTimeRunningHelp =>
      'The working-day lead time × 1.4, the usual seven-over-five convention. A planning figure rather than a measurement: a simulation walks each station’s real calendar instead, so the two can differ and the run is what happened.';

  @override
  String get footerPce => 'Process efficiency';

  @override
  String exportGenerated(String build, String timestamp) {
    return 'FlowMap $build · generated $timestamp';
  }

  @override
  String exportSaved(String path) {
    return 'Saved to $path';
  }

  @override
  String get simFilterStudies => 'Studies';

  @override
  String get simFilterCells => 'Cells';

  @override
  String get simFilterLines => 'Lines';

  @override
  String get simFilterPeriod => 'Period';

  @override
  String get simFilterPeriodHelp =>
      'Selects orders by their need date — the only one of an order’s dates that is never blank, so an order the run never completed still appears in its period. Station utilisation and blocked time keep describing the whole run, because the run does not store what a windowed figure would need.';

  @override
  String get simFilterPeriodStart => 'First month';

  @override
  String get simFilterPeriodEnd => 'Last month';

  @override
  String get simFilterAll => 'all';

  @override
  String get simFilterProjects => 'Projects';

  @override
  String get simFilterParts => 'Part numbers';

  @override
  String get simFilterOrders => 'Orders';

  @override
  String get simFilterOrdersHint => 'e.g. 5, 12';

  @override
  String get simFilterNoProject => '(no project)';

  @override
  String simFilterOrdersEachStudy(int count) {
    return 'Order numbers repeat in every study — $count studies are in view';
  }

  @override
  String get simFilterClear => 'Clear Filters';

  @override
  String get simWorkspace => 'Simulation';

  @override
  String get simStationsWholeRun =>
      'Utilization and Blocked describe the whole run — the run does not store what a narrowed open time would need. The other columns follow the filter.';

  @override
  String get simulationRun => 'Simulate';

  @override
  String get simulationRunning => 'Running…';

  @override
  String get dispatchFifo => 'FIFO — by arrival';

  @override
  String get dispatchLifo => 'LIFO';

  @override
  String get dispatchEarliestDueDate => 'Earliest need date';

  @override
  String get dispatchShortestProcessing => 'Shortest processing time';

  @override
  String get simulationNoStudies => 'No study is selected for a run';

  @override
  String get simulationNoStudiesHelp =>
      'Flag a study in the sidebar. Several studies of one line are scenarios of one reality, so a run takes at most one of each.';

  @override
  String get simProblemNoTakt =>
      'No takt period covers the day this run would start.';

  @override
  String get simProblemNoOrders =>
      'The demand sequence is empty — there is nothing to release.';

  @override
  String get simProblemUnboundStep =>
      'A step targets no workcenter, or its pool is empty.';

  @override
  String get simProblemNoPaceSetter =>
      'No step can pace the releases: every one of them is unbound.';

  @override
  String get simulationNeverRun => 'No run yet';

  @override
  String get simulationNeverRunHelp =>
      'Simulate runs every selected study against one model of the plant, so one line’s orders genuinely delay another’s.';

  @override
  String simulationAbortHorizon(String count) {
    return 'Demand exceeds capacity. $count orders never completed, and the run was abandoned rather than looping forever.';
  }

  @override
  String get simulationAbortNothingToRun =>
      'Nothing could be started: every station’s calendar is shut, or no study had a costable first order.';

  @override
  String get simOnTimeDelivery => 'On-time delivery';

  @override
  String simOnTimeOfOrders(String onTime, String orders) {
    return '$onTime of $orders orders on time';
  }

  @override
  String get simOnTimeHelp =>
      'Counted over every order, not only the delivered ones: an order that never came out is not on time, whatever its need date says.';

  @override
  String get simDelivered => 'Delivered';

  @override
  String simDeliveredOf(String delivered, String orders) {
    return '$delivered of $orders';
  }

  @override
  String get simAverageFloat => 'Average float';

  @override
  String get simAverageFloatHelp =>
      'Need date minus order end, averaged over the orders that finished. Positive is early, with that much time in hand; negative is late by that much. An order that never ended has no float and is left out here — it still counts as late above.';

  @override
  String get simAverageLeadTime => 'Average lead time';

  @override
  String get simAverageLeadTimeHelp =>
      'Wall-clock time in the flow, from release to the last step.';

  @override
  String get simTheoreticalLeadTime => 'Theoretical lead time';

  @override
  String get simTheoreticalLeadTimeHelp =>
      'What these orders would take flowing through the plant as it stands — the work, a full changeover at every step and the stock standing in each queue — walked from each order\'s own release through the real calendars.';

  @override
  String get simLeadTimeEfficiency => 'Lead-time efficiency';

  @override
  String get simLeadTimeEfficiencyHelp =>
      'Theoretical ÷ actual. Above 100% the flow queued less than the standard expects; below 100% it queued more. Warm-up orders — those released before their line\'s first delivery, when the flow was still empty — are left out.';

  @override
  String get simEmptySlots => 'Empty release slots';

  @override
  String get simEmptySlotsHelp =>
      'Slots that came round with nothing to put in them: the head of the sequence had no material yet, or the flow was already at its WIP cap. The sequence is the thing under study, so an empty slot is counted rather than quietly repaired.';

  @override
  String get simByQueue => 'Ranked by queue time';

  @override
  String get simByShare => 'Ranked by share of the flow';

  @override
  String get simRankingsHelp =>
      'Both rankings are here because their disagreement is the diagnostic: a long queue at a station that is not busy is a sequencing problem, not a capacity one.';

  @override
  String get simQueue => 'Queue';

  @override
  String get simQueueAverage => 'Average queue';

  @override
  String get simVisits => 'Visits';

  @override
  String get simChangeovers => 'Changeovers';

  @override
  String get utilization => 'Utilization';

  @override
  String get simUtilizationHelp =>
      'Busy ÷ open time observed in this run. Not the same as occupation, which is required ÷ available before any run — where the two disagree, sequencing or starvation got in the way.';

  @override
  String get simContributed => 'Queue + processing';

  @override
  String get simShareOfFlow => 'Share of flow';

  @override
  String get simPerPart => 'Per part number';

  @override
  String get simOrders => 'Orders';

  @override
  String get simOnTime => 'On time';

  @override
  String get simNothingRanked => 'No station ran anything.';

  @override
  String simRunSpan(String start, String end) {
    return '$start → $end';
  }

  @override
  String get simEarlierRuns => 'Earlier runs';

  @override
  String simRunLabel(String timestamp, String rule) {
    return '$timestamp · $rule';
  }

  @override
  String get simViewResults => 'Simulation Results';

  @override
  String get simulationRunFailed => 'The run could not be completed';

  @override
  String get simProductionPlanHelp =>
      'Rows are in sequence order, which is also release order: the engine releases strictly from the head of the sequence and never reorders it. Blank columns mean a run made before FlowMap recorded them.';

  @override
  String get simPlanOrder => 'Order';

  @override
  String get simPlanOrderStart => 'Order start';

  @override
  String get simPlanOrderEnd => 'Order end';

  @override
  String get simPlanTakt => 'Takt';

  @override
  String get simPlanTheoreticalLeadTime => 'Theoretical LT';

  @override
  String get simPlanActualLeadTime => 'Actual LT';

  @override
  String get simPlanLeadTimeEfficiency => 'Efficiency';

  @override
  String get simRunQueuesMixed => 'mixed';

  @override
  String simRunQueueRow(String name, String rule) {
    return '$name: $rule';
  }

  @override
  String get simRunDeleteBody =>
      'The run and everything it recorded go. The studies it was made from are untouched.';

  @override
  String get simGanttView => 'Production Gantt';

  @override
  String get simGanttEmpty =>
      'This run recorded no steps, so there is nothing to draw.';

  @override
  String get simGanttGapHelp =>
      'A bar is the station committed to that order, closed hours included. A gap is a station not running: closed, or starved. How much of it was open at all is in the Queue table.';

  @override
  String simGanttOrder(String number) {
    return 'Order $number';
  }

  @override
  String get simGanttProject => 'Project';

  @override
  String get simGanttCommitted => 'Committed';

  @override
  String get simGanttTakt => 'Takt';

  @override
  String get simGanttProcess => 'Process time';

  @override
  String get simGanttWaited => 'Waited before starting';

  @override
  String get simGanttChangeover => 'A changeover was paid to start it';

  @override
  String simScheduleTail(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count orders finished after $date using the last defined schedule',
      one: '1 order finished after $date using the last defined schedule',
    );
    return '$_temp0';
  }

  @override
  String get simScheduleTailHelp =>
      'Takt and workcenter schedule periods stop at that date, so the run carried the last one forward past it. That is not an error — a run goes until the last order completes — but the figures after that date describe capacity nobody has defined. Extend the periods and run again to be sure of them.';

  @override
  String get settingsDisplay => 'Display';

  @override
  String get settingsDateFormatHelp =>
      'How dates are written and read across the app, including the Excel export. Independent of the interface language. ISO dates are always accepted when typing, whichever format is chosen.';

  @override
  String get dateFormatLocale => 'Follow the system language';

  @override
  String get dateFormatDayMonthYear => 'Day/month/year';

  @override
  String get dateFormatMonthDayYear => 'Month/day/year';

  @override
  String get dateFormatIso => 'Year-month-day (ISO)';

  @override
  String simGanttLaneHolds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Lane holds $count orders',
      one: 'Lane holds 1 order',
    );
    return '$_temp0';
  }

  @override
  String get simGanttLaneUncapped => 'Lane has no limit';

  @override
  String get simGanttStillWaiting => 'Still standing here when the run ended';

  @override
  String get simGanttRowsStations => 'Stations';

  @override
  String get simGanttRowsWithLanes => 'Stations + lanes';

  @override
  String get simGanttRowsHelp =>
      'Whether the queue bands between stations are drawn. Without them the chart reads as a flow; with them it reads as a queue.';

  @override
  String get simGanttZoomIn => 'Zoom in';

  @override
  String get simGanttZoomOut => 'Zoom out';

  @override
  String simGanttFloored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bars drawn wider than they are',
      one: '1 bar drawn wider than it is',
    );
    return '$_temp0';
  }

  @override
  String get simGanttFlooredHelp =>
      'At this zoom these steps are thinner than a pixel, so they are drawn at the minimum width to keep them visible. Their position is exact; their width is not. Zoom in and the note goes.';

  @override
  String get exportExcel => 'Export to Excel';

  @override
  String get simExportRunSheet => 'Run';

  @override
  String get flowQueueEdit => 'Set the queue in front of this step';

  @override
  String flowQueueShared(String target) {
    return 'One queue per station: every step that feeds $target waits in this one, in this study and in every other.';
  }

  @override
  String get flowQueueName => 'Name';

  @override
  String get flowQueueType => 'Queue type';

  @override
  String get flowQueueTypeHelp =>
      'How the station ahead picks the next order out of this queue. An untyped queue is a line nobody has given a rule to; the four rules are disciplines, and the map draws each one differently. The queue\'s caption on the map is this type and the station it stands in front of.';

  @override
  String get flowQueueStock => 'What is standing here now';

  @override
  String get queueTypeQueue => 'Queue — a line, no rule';

  @override
  String get queueShortFifo => 'FIFO';

  @override
  String get queueShortLifo => 'LIFO';

  @override
  String get queueShortEarliestDueDate => 'EDD';

  @override
  String get queueShortShortestProcessing => 'SPT';

  @override
  String get queueShortQueue => 'Queue';

  @override
  String get queueTypeSupermarket => 'Supermarket — not yet';

  @override
  String get flowBatchHelp =>
      'How many pieces each box is costed for. Process times are per piece, so an order of ten occupies a station ten times as long — which is what the simulation charges. Leave it blank to follow the orders this part actually has.';

  @override
  String get validationNumber => 'Enter a number';

  @override
  String get validationAboveZero => 'Enter a number above zero';

  @override
  String get simEmptySlotAwaitingMaterial => 'Awaiting material';

  @override
  String get simEmptySlotWipCap => 'WIP cap reached';

  @override
  String get flowEndStockInbound => 'Raw material stock';

  @override
  String get flowEndStockOutbound => 'Finished goods stock';

  @override
  String get flowEndStockQuantity => 'Pieces standing here';

  @override
  String get flowEndStockHelp =>
      'An observation of what is on the floor today, in pieces, shown as days through the takt of the period on screen. It counts towards the lead time and the days of stock, and nothing is dispatched out of it — orders are released on a takt, not pulled from a rack. Leave it blank if nobody has counted.';

  @override
  String get flowEndStockNone => 'Not counted';

  @override
  String get stepBalancedMark => '⇄';

  @override
  String stepBalancedHelp(String type, String measured) {
    return 'Rebalanced across the $type stations next to each other in this flow: each fills to its takt and the last takes the remainder, so changing the takt moves the split with no other edit. $measured was measured here, and the demand table still holds it.';
  }

  @override
  String get stepRebalance => 'Rebalance with adjacent like machines';

  @override
  String get stepRebalanceHelp =>
      'Stations of the same type standing next to each other share their work: each fills to its takt and the last takes the remainder, so changing the takt moves the split with no other edit. Turn it off to pin this station at what was measured on it.';

  @override
  String stepRebalanceNoType(String name) {
    return '$name has no workcenter type, so nothing says it is like its neighbours.';
  }

  @override
  String stepRebalanceNoNeighbour(String type) {
    return 'No adjacent step shares the type $type.';
  }

  @override
  String get stepRebalanceNoWork =>
      'This part has no time here, so the station is not sharing work.';

  @override
  String stepRebalanceOn(String type) {
    return 'Sharing work with the adjacent $type stations.';
  }

  @override
  String simRunTakt(String takt) {
    return 'Ran at $takt';
  }

  @override
  String simRunTaktChanges(String date) {
    return 'The takt changed on $date, inside this run.';
  }

  @override
  String get simRunTaktMixed => 'mixed';

  @override
  String flowTaktChanges(String from, String to, String date, String shown) {
    return 'Takt $from → $to on $date — showing $shown';
  }

  @override
  String simRunCadenceEnded(String study, String date, int count) {
    return '$study stopped opening orders on $date — its takt schedule ends there, and $count never opened.';
  }

  @override
  String get settingsLanguageHelp =>
      'Which language the app is drawn in. Follow the system uses your Windows display language.';

  @override
  String get languageEn => 'English';

  @override
  String get languageEs => 'Español';

  @override
  String get languagePt => 'Português';

  @override
  String stepRebalanceOnWithRework(
    String type,
    String filled,
    String capacity,
    String rework,
  ) {
    return 'Sharing work with the adjacent $type stations. Filled to $filled of $capacity — $rework% rework means that much content uses one whole takt.';
  }

  @override
  String stepRebalanceRemainder(String type, String filled, String capacity) {
    return 'Sharing work with the adjacent $type stations. They fill to their takt and this one takes what is left — $filled, inside the $capacity one takt holds.';
  }

  @override
  String stepRebalanceRemainderOver(
    String type,
    String filled,
    String capacity,
  ) {
    return 'Sharing work with the adjacent $type stations. They fill to their takt and this one takes what is left — $filled, past the $capacity one takt holds. The group needs more than its stations have.';
  }

  @override
  String get occupationView => 'Occupation';

  @override
  String get occupationType => 'Type';

  @override
  String get occupationStation => 'Station';

  @override
  String get occupationLine => 'Line';

  @override
  String get occupationUngraphable =>
      'This run was made before the app recorded what a month of a station was worth, so it cannot be graphed. Run the simulation again to get a chart.';

  @override
  String get projectSettingsFloat => 'Float thresholds';

  @override
  String get projectSettingsFloatHelp =>
      'Where the float matrix turns red and green. Between the two is amber.';

  @override
  String get projectFloatRed => 'Red at or below (days)';

  @override
  String get projectFloatGreen => 'Green at or above (days)';

  @override
  String get projectFloatRedHelp =>
      'An order with this much slack or less is drawn red. Zero means an order delivered exactly on its need date has none left.';

  @override
  String get projectFloatGreenHelp =>
      'An order with at least this much slack is drawn green.';

  @override
  String get floatMatrixTitle => 'Delivery Float';

  @override
  String get floatMatrixHelp =>
      'Columns are the month of the order\'s need date, rows its rank in that month by need date. Cells are slack in days — positive is early.';

  @override
  String get floatMatrixUndelivered => 'Never delivered';

  @override
  String get floatMatrixEmpty =>
      'No orders in this slice have a need date to place.';

  @override
  String floatLegendRed(String days) {
    return '$days d or less';
  }

  @override
  String floatLegendAmber(String red, String green) {
    return 'Between $red d and $green d';
  }

  @override
  String floatLegendGreen(String days) {
    return '$days d or more';
  }

  @override
  String get workspaceModeStudy => 'Study';

  @override
  String get simTabOverview => 'Simulation Overview';

  @override
  String get simTabPlan => 'Production Plan';

  @override
  String get simPlanByStudy => 'By Study';

  @override
  String get simPlanCombined => 'Combined';

  @override
  String get simPlanStudy => 'Study';

  @override
  String get simPlanCell => 'Cell';

  @override
  String get simPlanLine => 'Line';

  @override
  String get simRunCovers => 'Studies in this run';

  @override
  String get simRunCoversFiltered => 'filtered out';

  @override
  String simulationStudiesNotReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count studies are not ready to run',
      one: '1 study is not ready to run',
    );
    return '$_temp0';
  }

  @override
  String get occupationByWorkcenter => 'Per Workcenter';

  @override
  String get occupationByLine => 'Per Line';

  @override
  String get occupationByType => 'Per Type';

  @override
  String get occupationWorkcenterType => 'Workcenter Type';

  @override
  String get occupationUntyped => 'Untyped';

  @override
  String get occupationUnitPercent => '%';

  @override
  String get occupationUnitHours => 'Hours';

  @override
  String get occupationUnitGap => 'Gap';

  @override
  String get occupationWorkcenter => 'Workcenter';

  @override
  String get occupationAmberAbove => 'Amber above';

  @override
  String get occupationRedAbove => 'Red above';

  @override
  String get occupationBands =>
      'Where the Occupation grid turns amber and red. A station asked for more hours than it has open is over by definition; the amber band is the room left for the changeover the next order brings.';

  @override
  String get occupationProcess => 'Process';

  @override
  String get occupationRework => 'Rework';

  @override
  String get occupationChangeover => 'Changeover';

  @override
  String get occupationOutsideFilter => 'Outside the filter';

  @override
  String occupationStations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stations aggregated',
      one: '1 station aggregated',
    );
    return '$_temp0';
  }

  @override
  String get occupationTipDemand => 'Demand';

  @override
  String get occupationTipCapacity => 'Capacity';

  @override
  String occupationHours(Object hours) {
    return '$hours h';
  }

  @override
  String get occupationTotal => 'TOTAL';

  @override
  String get occupationAllMonths => 'all months shown';

  @override
  String get floatAverage => 'AVG';

  @override
  String floatAverageHelp(Object days) {
    return '$days days of float on average.';
  }

  @override
  String get demandPasteHint =>
      'Type a value, or paste a block from Excel with Ctrl+V.';

  @override
  String get occupationBandsTitle => 'Occupation bands';
}
