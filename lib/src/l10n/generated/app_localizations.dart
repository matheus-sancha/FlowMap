import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('pt'),
  ];

  /// Application name, shown in the window title and the About screen.
  ///
  /// In en, this message translates to:
  /// **'FlowMap'**
  String get appTitle;

  /// No description provided for @navProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get navProjects;

  /// No description provided for @navTemplates.
  ///
  /// In en, this message translates to:
  /// **'Study Templates'**
  String get navTemplates;

  /// No description provided for @navResources.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get navResources;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get navAbout;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get actionArchive;

  /// No description provided for @actionRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get actionRestore;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get actionDuplicate;

  /// No description provided for @actionRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get actionRename;

  /// No description provided for @fieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fieldName;

  /// No description provided for @fieldCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get fieldCode;

  /// No description provided for @fieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get fieldType;

  /// No description provided for @fieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get fieldNotes;

  /// No description provided for @fieldStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get fieldStart;

  /// No description provided for @fieldEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get fieldEnd;

  /// No description provided for @validationRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get validationRequired;

  /// No description provided for @validationNameTaken.
  ///
  /// In en, this message translates to:
  /// **'That name is already used here'**
  String get validationNameTaken;

  /// No description provided for @resourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get resourcesTitle;

  /// No description provided for @resourcesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No plant yet. Create one to start building studies.'**
  String get resourcesEmpty;

  /// No description provided for @resourcesShowArchived.
  ///
  /// In en, this message translates to:
  /// **'Show archived'**
  String get resourcesShowArchived;

  /// No description provided for @resourcesArchivedBadge.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get resourcesArchivedBadge;

  /// No description provided for @plant.
  ///
  /// In en, this message translates to:
  /// **'Plant'**
  String get plant;

  /// No description provided for @plantNew.
  ///
  /// In en, this message translates to:
  /// **'New plant'**
  String get plantNew;

  /// No description provided for @plantDeleteBlocked.
  ///
  /// In en, this message translates to:
  /// **'This plant has production cells. Archive it instead.'**
  String get plantDeleteBlocked;

  /// No description provided for @productionCell.
  ///
  /// In en, this message translates to:
  /// **'Production cell'**
  String get productionCell;

  /// No description provided for @productionCells.
  ///
  /// In en, this message translates to:
  /// **'Production cells'**
  String get productionCells;

  /// No description provided for @productionCellNew.
  ///
  /// In en, this message translates to:
  /// **'New production cell'**
  String get productionCellNew;

  /// No description provided for @productionLine.
  ///
  /// In en, this message translates to:
  /// **'Production line'**
  String get productionLine;

  /// No description provided for @productionLines.
  ///
  /// In en, this message translates to:
  /// **'Production lines'**
  String get productionLines;

  /// No description provided for @productionLineNew.
  ///
  /// In en, this message translates to:
  /// **'New production line'**
  String get productionLineNew;

  /// No description provided for @workcenter.
  ///
  /// In en, this message translates to:
  /// **'Workcenter'**
  String get workcenter;

  /// No description provided for @workcenters.
  ///
  /// In en, this message translates to:
  /// **'Workcenters'**
  String get workcenters;

  /// No description provided for @workcenterNew.
  ///
  /// In en, this message translates to:
  /// **'New workcenter'**
  String get workcenterNew;

  /// No description provided for @workcenterType.
  ///
  /// In en, this message translates to:
  /// **'Workcenter type'**
  String get workcenterType;

  /// No description provided for @workcenterTypes.
  ///
  /// In en, this message translates to:
  /// **'Workcenter types'**
  String get workcenterTypes;

  /// No description provided for @workcenterTypeNew.
  ///
  /// In en, this message translates to:
  /// **'New workcenter type'**
  String get workcenterTypeNew;

  /// No description provided for @workcenterPool.
  ///
  /// In en, this message translates to:
  /// **'Workcenter pool'**
  String get workcenterPool;

  /// No description provided for @workcenterPools.
  ///
  /// In en, this message translates to:
  /// **'Workcenter pools'**
  String get workcenterPools;

  /// No description provided for @workcenterPoolNew.
  ///
  /// In en, this message translates to:
  /// **'New pool'**
  String get workcenterPoolNew;

  /// No description provided for @workcenterPoolMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get workcenterPoolMembers;

  /// No description provided for @workcenterPoolEmpty.
  ///
  /// In en, this message translates to:
  /// **'A pool needs at least one workcenter.'**
  String get workcenterPoolEmpty;

  /// No description provided for @shiftPattern.
  ///
  /// In en, this message translates to:
  /// **'Shift pattern'**
  String get shiftPattern;

  /// No description provided for @shiftPatterns.
  ///
  /// In en, this message translates to:
  /// **'Shift patterns'**
  String get shiftPatterns;

  /// No description provided for @shiftPatternNew.
  ///
  /// In en, this message translates to:
  /// **'New shift pattern'**
  String get shiftPatternNew;

  /// No description provided for @shiftPatternCycle.
  ///
  /// In en, this message translates to:
  /// **'Cycle'**
  String get shiftPatternCycle;

  /// No description provided for @shiftPatternCycleFixedWeekly.
  ///
  /// In en, this message translates to:
  /// **'Fixed weekly'**
  String get shiftPatternCycleFixedWeekly;

  /// No description provided for @shiftPatternCycleRotating.
  ///
  /// In en, this message translates to:
  /// **'Rotating (continuous)'**
  String get shiftPatternCycleRotating;

  /// No description provided for @shiftPatternWorkingDays.
  ///
  /// In en, this message translates to:
  /// **'Base working days'**
  String get shiftPatternWorkingDays;

  /// No description provided for @shiftPatternShifts.
  ///
  /// In en, this message translates to:
  /// **'Shifts'**
  String get shiftPatternShifts;

  /// No description provided for @shiftPatternShiftNew.
  ///
  /// In en, this message translates to:
  /// **'Add shift'**
  String get shiftPatternShiftNew;

  /// No description provided for @shiftPatternNoShifts.
  ///
  /// In en, this message translates to:
  /// **'A pattern needs at least one shift.'**
  String get shiftPatternNoShifts;

  /// No description provided for @shiftLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get shiftLabel;

  /// No description provided for @shiftStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get shiftStart;

  /// No description provided for @shiftEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get shiftEnd;

  /// No description provided for @shiftBreak.
  ///
  /// In en, this message translates to:
  /// **'Break'**
  String get shiftBreak;

  /// No description provided for @shiftCrossesMidnight.
  ///
  /// In en, this message translates to:
  /// **'Crosses midnight'**
  String get shiftCrossesMidnight;

  /// No description provided for @shiftDuration.
  ///
  /// In en, this message translates to:
  /// **'Net duration'**
  String get shiftDuration;

  /// No description provided for @shiftOverlapWarning.
  ///
  /// In en, this message translates to:
  /// **'This shift overlaps {other}.'**
  String shiftOverlapWarning(String other);

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySun;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String confirmDeleteTitle(String name);

  /// No description provided for @confirmDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get confirmDeleteBody;

  /// No description provided for @confirmArchiveBody.
  ///
  /// In en, this message translates to:
  /// **'It stays available to projects already using it, but is hidden from pickers.'**
  String get confirmArchiveBody;

  /// No description provided for @aboutVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutBuild.
  ///
  /// In en, this message translates to:
  /// **'Build {build}'**
  String aboutBuild(String build);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsDateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get settingsDateFormat;

  /// No description provided for @settingsDateFormatLocale.
  ///
  /// In en, this message translates to:
  /// **'Follow language'**
  String get settingsDateFormatLocale;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @valueNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get valueNone;

  /// No description provided for @workcenterNameHelp.
  ///
  /// In en, this message translates to:
  /// **'What the shop floor calls it, and the label on the process box — e.g. CLAD04.'**
  String get workcenterNameHelp;

  /// No description provided for @workcenterAddExisting.
  ///
  /// In en, this message translates to:
  /// **'Add existing'**
  String get workcenterAddExisting;

  /// No description provided for @workcenterAddExistingHelp.
  ///
  /// In en, this message translates to:
  /// **'A workcenter belongs to the plant, so this only changes where it appears in the tree. Any study of any line can use it either way.'**
  String get workcenterAddExistingHelp;

  /// No description provided for @workcenterNoneToAdd.
  ///
  /// In en, this message translates to:
  /// **'Every workcenter in this plant is already on this line.'**
  String get workcenterNoneToAdd;

  /// No description provided for @workcenterHomeLine.
  ///
  /// In en, this message translates to:
  /// **'Home production line'**
  String get workcenterHomeLine;

  /// No description provided for @workcenterHomeLineHelp.
  ///
  /// In en, this message translates to:
  /// **'Where it appears in the tree. Studies on other lines can still use it, and that shared use is what the simulation contends for.'**
  String get workcenterHomeLineHelp;

  /// No description provided for @workcenterTypeUnset.
  ///
  /// In en, this message translates to:
  /// **'No type'**
  String get workcenterTypeUnset;

  /// No description provided for @workcenterTypeDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Workcenters using this type keep working; their type is cleared.'**
  String get workcenterTypeDeleteBody;

  /// No description provided for @workcenterPoolNoCandidates.
  ///
  /// In en, this message translates to:
  /// **'This plant has no workcenters yet.'**
  String get workcenterPoolNoCandidates;

  /// No description provided for @resourcesUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Not on a line'**
  String get resourcesUnassigned;

  /// No description provided for @resourcesUnassignedHelp.
  ///
  /// In en, this message translates to:
  /// **'Workcenters that belong to the plant but are not drawn under a production line.'**
  String get resourcesUnassignedHelp;

  /// No description provided for @shiftPatternRotatingHelp.
  ///
  /// In en, this message translates to:
  /// **'Runs every day. Shifts are time windows, not crews — four crews rotating through two 12-hour windows is two shifts here, because capacity comes from the windows covered.'**
  String get shiftPatternRotatingHelp;

  /// No description provided for @shiftPatternEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get shiftPatternEveryDay;

  /// No description provided for @shiftPatternNoWorkingDays.
  ///
  /// In en, this message translates to:
  /// **'No working days'**
  String get shiftPatternNoWorkingDays;

  /// No description provided for @shiftPatternOpenPerDay.
  ///
  /// In en, this message translates to:
  /// **'Open {duration}/day'**
  String shiftPatternOpenPerDay(String duration);

  /// No description provided for @shiftBreakMinutes.
  ///
  /// In en, this message translates to:
  /// **'Break (min)'**
  String get shiftBreakMinutes;

  /// No description provided for @shiftBreakOf.
  ///
  /// In en, this message translates to:
  /// **'Break {duration}'**
  String shiftBreakOf(String duration);

  /// No description provided for @projectNew.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get projectNew;

  /// No description provided for @projectsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No projects yet.'**
  String get projectsEmpty;

  /// No description provided for @projectMissing.
  ///
  /// In en, this message translates to:
  /// **'That project no longer exists.'**
  String get projectMissing;

  /// No description provided for @projectNeedsPlant.
  ///
  /// In en, this message translates to:
  /// **'Create a plant in Resources before starting a project.'**
  String get projectNeedsPlant;

  /// No description provided for @projectPlantHelp.
  ///
  /// In en, this message translates to:
  /// **'Cannot be changed later: every study, schedule and flow step in the project points at this plant\'s workcenters.'**
  String get projectPlantHelp;

  /// No description provided for @projectPatternHelp.
  ///
  /// In en, this message translates to:
  /// **'The shift split every workcenter in this project is staffed against.'**
  String get projectPatternHelp;

  /// No description provided for @projectDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Its studies, schedules and flows go with it. This cannot be undone.'**
  String get projectDeleteBody;

  /// No description provided for @studyNew.
  ///
  /// In en, this message translates to:
  /// **'New study'**
  String get studyNew;

  /// No description provided for @studiesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No studies in this project yet.'**
  String get studiesEmpty;

  /// No description provided for @studyNameHint.
  ///
  /// In en, this message translates to:
  /// **'Current state'**
  String get studyNameHint;

  /// No description provided for @studyNeedsLine.
  ///
  /// In en, this message translates to:
  /// **'This plant has no production lines yet.'**
  String get studyNeedsLine;

  /// No description provided for @studyLineHelp.
  ///
  /// In en, this message translates to:
  /// **'A study belongs to one line. Several studies of the same line are scenarios; only one can be selected for a simulation.'**
  String get studyLineHelp;

  /// No description provided for @studyDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Its flow and annotations go with it. This cannot be undone.'**
  String get studyDeleteBody;

  /// No description provided for @studyIncludeInSimulation.
  ///
  /// In en, this message translates to:
  /// **'Include in simulation'**
  String get studyIncludeInSimulation;

  /// No description provided for @studyExcludeFromSimulation.
  ///
  /// In en, this message translates to:
  /// **'Exclude from simulation'**
  String get studyExcludeFromSimulation;

  /// No description provided for @studyTabFlow.
  ///
  /// In en, this message translates to:
  /// **'Flow'**
  String get studyTabFlow;

  /// No description provided for @studyTabTakt.
  ///
  /// In en, this message translates to:
  /// **'Takt'**
  String get studyTabTakt;

  /// No description provided for @studyTabDemand.
  ///
  /// In en, this message translates to:
  /// **'Demand'**
  String get studyTabDemand;

  /// No description provided for @studyTabSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get studyTabSummary;

  /// No description provided for @actionMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get actionMoveUp;

  /// No description provided for @actionMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get actionMoveDown;

  /// No description provided for @validationNotADuration.
  ///
  /// In en, this message translates to:
  /// **'Not a time'**
  String get validationNotADuration;

  /// No description provided for @validationNotADate.
  ///
  /// In en, this message translates to:
  /// **'Not a date'**
  String get validationNotADate;

  /// No description provided for @validationPositiveWhole.
  ///
  /// In en, this message translates to:
  /// **'A whole number above zero'**
  String get validationPositiveWhole;

  /// No description provided for @validationUnknownPart.
  ///
  /// In en, this message translates to:
  /// **'No part with that number in this study'**
  String get validationUnknownPart;

  /// No description provided for @stepProblemNoProcessTime.
  ///
  /// In en, this message translates to:
  /// **'This part has no process time here.'**
  String get stepProblemNoProcessTime;

  /// No description provided for @stepEquivalence.
  ///
  /// In en, this message translates to:
  /// **'Equivalent'**
  String get stepEquivalence;

  /// No description provided for @flowPart.
  ///
  /// In en, this message translates to:
  /// **'Part'**
  String get flowPart;

  /// No description provided for @flowNoParts.
  ///
  /// In en, this message translates to:
  /// **'No parts yet'**
  String get flowNoParts;

  /// No description provided for @footerEquivalence.
  ///
  /// In en, this message translates to:
  /// **'Equivalent'**
  String get footerEquivalence;

  /// No description provided for @footerEquivalenceHelp.
  ///
  /// In en, this message translates to:
  /// **'This part\'s process time across the flow divided by the flow equivalent\'s. 1.13 means it consumes 1.13 takts of the line\'s capacity.'**
  String get footerEquivalenceHelp;

  /// No description provided for @flowSourceNeedsDemand.
  ///
  /// In en, this message translates to:
  /// **'Needs at least one part in the Demand tab'**
  String get flowSourceNeedsDemand;

  /// No description provided for @mm3.
  ///
  /// In en, this message translates to:
  /// **'MM3'**
  String get mm3;

  /// No description provided for @mm3Column.
  ///
  /// In en, this message translates to:
  /// **'MM3'**
  String get mm3Column;

  /// No description provided for @mm3Scope.
  ///
  /// In en, this message translates to:
  /// **'Measured over'**
  String get mm3Scope;

  /// No description provided for @mm3WholeFlow.
  ///
  /// In en, this message translates to:
  /// **'Whole flow'**
  String get mm3WholeFlow;

  /// No description provided for @mm3Smoothness.
  ///
  /// In en, this message translates to:
  /// **'Average deviation'**
  String get mm3Smoothness;

  /// No description provided for @mm3SmoothnessHelp.
  ///
  /// In en, this message translates to:
  /// **'How far the moving average sits from 1.0 on average. 1.0 is one takt of the scope\'s capacity per order, which is a perfectly levelled sequence.'**
  String get mm3SmoothnessHelp;

  /// No description provided for @mm3NoSequence.
  ///
  /// In en, this message translates to:
  /// **'No orders in the sequence yet.'**
  String get mm3NoSequence;

  /// No description provided for @mm3NotMeasurable.
  ///
  /// In en, this message translates to:
  /// **'Nothing to measure yet: the parts in this sequence have no process times in this scope.'**
  String get mm3NotMeasurable;

  /// No description provided for @mm3Help.
  ///
  /// In en, this message translates to:
  /// **'A centred moving average of three over the sequence, blank at both ends. Reorder on the Sequence tab and watch it flatten.'**
  String get mm3Help;

  /// No description provided for @summaryOccupation.
  ///
  /// In en, this message translates to:
  /// **'Occupation by workcenter'**
  String get summaryOccupation;

  /// No description provided for @summaryDemandTakt.
  ///
  /// In en, this message translates to:
  /// **'Demand takt'**
  String get summaryDemandTakt;

  /// No description provided for @summaryRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get summaryRequired;

  /// No description provided for @summaryAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get summaryAvailable;

  /// No description provided for @summaryOperatorsAllocated.
  ///
  /// In en, this message translates to:
  /// **'Operators allocated'**
  String get summaryOperatorsAllocated;

  /// No description provided for @summaryOperatorsNeeded.
  ///
  /// In en, this message translates to:
  /// **'Operators needed'**
  String get summaryOperatorsNeeded;

  /// No description provided for @summaryNoSteps.
  ///
  /// In en, this message translates to:
  /// **'This flow has no bound process steps yet.'**
  String get summaryNoSteps;

  /// No description provided for @summaryNothingToRank.
  ///
  /// In en, this message translates to:
  /// **'Nothing to rank yet: no step has both a schedule and demand.'**
  String get summaryNothingToRank;

  /// No description provided for @summaryOverloaded.
  ///
  /// In en, this message translates to:
  /// **'Above 100 %: this station cannot do it however the sequence is arranged.'**
  String get summaryOverloaded;

  /// No description provided for @summaryWithinCapacity.
  ///
  /// In en, this message translates to:
  /// **'Within capacity for this period.'**
  String get summaryWithinCapacity;

  /// No description provided for @summaryNoDemandTakt.
  ///
  /// In en, this message translates to:
  /// **'No demand takt yet: it needs a station with hours and orders due in this period.'**
  String get summaryNoDemandTakt;

  /// No description provided for @summaryBottleneck.
  ///
  /// In en, this message translates to:
  /// **'Bottleneck: {name} at {occupation}'**
  String summaryBottleneck(String name, String occupation);

  /// No description provided for @summaryOrdersDue.
  ///
  /// In en, this message translates to:
  /// **'{count} orders due'**
  String summaryOrdersDue(String count);

  /// No description provided for @summaryVisitsHelp.
  ///
  /// In en, this message translates to:
  /// **'The flow routes through this station {count} times, and every visit loads it.'**
  String summaryVisitsHelp(String count);

  /// No description provided for @summaryMissingTimes.
  ///
  /// In en, this message translates to:
  /// **'{count} parts due here have no process time, so the required hours are an understatement.'**
  String summaryMissingTimes(String count);

  /// No description provided for @summaryRequiredHelp.
  ///
  /// In en, this message translates to:
  /// **'{work} of process time plus {changeovers} changeovers worth {changeover}.'**
  String summaryRequiredHelp(
    String work,
    String changeovers,
    String changeover,
  );

  /// No description provided for @summaryOccupationHelp.
  ///
  /// In en, this message translates to:
  /// **'{occupation} = {required} required over {available} available.'**
  String summaryOccupationHelp(
    String occupation,
    String required,
    String available,
  );

  /// No description provided for @summaryPaceSetter.
  ///
  /// In en, this message translates to:
  /// **'Measured at {name}, the busiest station, which has {available} available this period.'**
  String summaryPaceSetter(String name, String available);

  /// No description provided for @summaryTaktConfigured.
  ///
  /// In en, this message translates to:
  /// **'Configured takt'**
  String get summaryTaktConfigured;

  /// No description provided for @summaryTaktConfiguredHelp.
  ///
  /// In en, this message translates to:
  /// **'The takt this line is set to run at, resolved at the pace-setting station.'**
  String get summaryTaktConfiguredHelp;

  /// No description provided for @summaryTaktRaw.
  ///
  /// In en, this message translates to:
  /// **'Raw demand takt'**
  String get summaryTaktRaw;

  /// No description provided for @summaryTaktRawHelp.
  ///
  /// In en, this message translates to:
  /// **'Available time over {orders} orders due. What a visitor expects.'**
  String summaryTaktRawHelp(String orders);

  /// No description provided for @summaryTaktAdjusted.
  ///
  /// In en, this message translates to:
  /// **'Equivalent-adjusted demand takt'**
  String get summaryTaktAdjusted;

  /// No description provided for @summaryTaktAdjustedHelp.
  ///
  /// In en, this message translates to:
  /// **'Available time over {equivalents} part-equivalents due. What actually matters under a mixed part mix: an order worth two takts of work counts twice.'**
  String summaryTaktAdjustedHelp(String equivalents);

  /// No description provided for @demandParts.
  ///
  /// In en, this message translates to:
  /// **'Parts'**
  String get demandParts;

  /// No description provided for @demandSequence.
  ///
  /// In en, this message translates to:
  /// **'Sequence'**
  String get demandSequence;

  /// No description provided for @demandPartNumber.
  ///
  /// In en, this message translates to:
  /// **'Part number'**
  String get demandPartNumber;

  /// No description provided for @demandDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get demandDescription;

  /// No description provided for @demandTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get demandTotal;

  /// No description provided for @demandOrderNumber.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get demandOrderNumber;

  /// No description provided for @demandBatchSize.
  ///
  /// In en, this message translates to:
  /// **'Batch'**
  String get demandBatchSize;

  /// No description provided for @demandNeedDate.
  ///
  /// In en, this message translates to:
  /// **'Need date'**
  String get demandNeedDate;

  /// No description provided for @demandMaterialDate.
  ///
  /// In en, this message translates to:
  /// **'Material date'**
  String get demandMaterialDate;

  /// No description provided for @demandMaterialDateHelp.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get demandMaterialDateHelp;

  /// No description provided for @demandUnbound.
  ///
  /// In en, this message translates to:
  /// **'not bound'**
  String get demandUnbound;

  /// No description provided for @demandTimesHelp.
  ///
  /// In en, this message translates to:
  /// **'Per piece. Type 30:00:00, 1.5h, 90min or 2d; a bare number is read as hours. Leave a cell blank where the part skips the step. Paste a block from Excel with Ctrl+V.'**
  String get demandTimesHelp;

  /// No description provided for @demandSequenceHelp.
  ///
  /// In en, this message translates to:
  /// **'The order the plant will build in. Nothing reorders it but you. Paste a block from Excel with Ctrl+V.'**
  String get demandSequenceHelp;

  /// No description provided for @demandNoSteps.
  ///
  /// In en, this message translates to:
  /// **'This flow has no process steps yet, so there is nothing to cost a part against.'**
  String get demandNoSteps;

  /// No description provided for @demandNeedsPart.
  ///
  /// In en, this message translates to:
  /// **'Add a part before adding orders.'**
  String get demandNeedsPart;

  /// No description provided for @demandPartDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Its process times go with it, and every order for it leaves the sequence.'**
  String get demandPartDeleteBody;

  /// No description provided for @takt.
  ///
  /// In en, this message translates to:
  /// **'Takt'**
  String get takt;

  /// No description provided for @taktUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get taktUnit;

  /// No description provided for @taktEmpty.
  ///
  /// In en, this message translates to:
  /// **'No takt defined for this production line yet.'**
  String get taktEmpty;

  /// No description provided for @taktPeriodNew.
  ///
  /// In en, this message translates to:
  /// **'New takt period'**
  String get taktPeriodNew;

  /// No description provided for @taktPeriodDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this takt period?'**
  String get taktPeriodDeleteTitle;

  /// No description provided for @taktDaysHelp.
  ///
  /// In en, this message translates to:
  /// **'Days are relative to each workcenter\'s own capacity: a 3-day takt is 68 h at a station open 22:40 a day, and 26:24 at one open 8:48.'**
  String get taktDaysHelp;

  /// No description provided for @taktLiteralHelp.
  ///
  /// In en, this message translates to:
  /// **'Resolves to the same duration at every workcenter.'**
  String get taktLiteralHelp;

  /// No description provided for @unitDays.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get unitDays;

  /// No description provided for @unitHours.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get unitHours;

  /// No description provided for @unitMinutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get unitMinutes;

  /// No description provided for @unitSeconds.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get unitSeconds;

  /// No description provided for @unitDaysShort.
  ///
  /// In en, this message translates to:
  /// **'d'**
  String get unitDaysShort;

  /// No description provided for @unitHoursShort.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get unitHoursShort;

  /// No description provided for @unitMinutesShort.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get unitMinutesShort;

  /// No description provided for @unitSecondsShort.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get unitSecondsShort;

  /// No description provided for @schedulePeriodNew.
  ///
  /// In en, this message translates to:
  /// **'New period'**
  String get schedulePeriodNew;

  /// No description provided for @schedulePeriodDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this schedule period?'**
  String get schedulePeriodDeleteTitle;

  /// No description provided for @scheduleShifts.
  ///
  /// In en, this message translates to:
  /// **'Shifts'**
  String get scheduleShifts;

  /// No description provided for @scheduleOperatorsPerShift.
  ///
  /// In en, this message translates to:
  /// **'Operators per shift'**
  String get scheduleOperatorsPerShift;

  /// No description provided for @scheduleShiftsDerived.
  ///
  /// In en, this message translates to:
  /// **'Shifts: {count} ({operators}) — counted from the shifts with operators, never stored separately.'**
  String scheduleShiftsDerived(String count, String operators);

  /// No description provided for @availability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get availability;

  /// No description provided for @availabilityHelp.
  ///
  /// In en, this message translates to:
  /// **'Fraction of open time the workcenter can actually run. Applied once, to process time.'**
  String get availabilityHelp;

  /// No description provided for @availabilityInvalid.
  ///
  /// In en, this message translates to:
  /// **'Must be above 0% and at most 100%'**
  String get availabilityInvalid;

  /// No description provided for @rework.
  ///
  /// In en, this message translates to:
  /// **'Rework'**
  String get rework;

  /// No description provided for @reworkHelp.
  ///
  /// In en, this message translates to:
  /// **'Fraction of work that has to be redone. Inflates process time.'**
  String get reworkHelp;

  /// No description provided for @reworkInvalid.
  ///
  /// In en, this message translates to:
  /// **'Must be 0% or more'**
  String get reworkInvalid;

  /// No description provided for @occupation.
  ///
  /// In en, this message translates to:
  /// **'Occupation'**
  String get occupation;

  /// No description provided for @workcentersTabEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add steps to the flow to schedule their workcenters here.'**
  String get workcentersTabEmpty;

  /// No description provided for @workcentersTabPattern.
  ///
  /// In en, this message translates to:
  /// **'Shift pattern: {shifts}'**
  String workcentersTabPattern(String shifts);

  /// No description provided for @scheduleIssueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No periods defined. Nothing here can be costed until there is at least one.'**
  String get scheduleIssueEmpty;

  /// No description provided for @scheduleIssueOverlap.
  ///
  /// In en, this message translates to:
  /// **'Two periods both cover {from} to {to}.'**
  String scheduleIssueOverlap(String from, String to);

  /// No description provided for @scheduleIssueGap.
  ///
  /// In en, this message translates to:
  /// **'No period covers {from} to {to}.'**
  String scheduleIssueGap(String from, String to);

  /// No description provided for @scheduleIssueInverted.
  ///
  /// In en, this message translates to:
  /// **'A period ends ({to}) before it starts ({from}).'**
  String scheduleIssueInverted(String from, String to);

  /// No description provided for @periodPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous period'**
  String get periodPrevious;

  /// No description provided for @periodNext.
  ///
  /// In en, this message translates to:
  /// **'Next period'**
  String get periodNext;

  /// No description provided for @periodMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get periodMonth;

  /// No description provided for @periodQuarterly.
  ///
  /// In en, this message translates to:
  /// **'Quarter'**
  String get periodQuarterly;

  /// No description provided for @periodSemesterly.
  ///
  /// In en, this message translates to:
  /// **'Semester'**
  String get periodSemesterly;

  /// No description provided for @periodYearly.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get periodYearly;

  /// No description provided for @periodQuarter.
  ///
  /// In en, this message translates to:
  /// **'Q{quarter} {year}'**
  String periodQuarter(String quarter, String year);

  /// No description provided for @periodSemester.
  ///
  /// In en, this message translates to:
  /// **'H{half} {year}'**
  String periodSemester(String half, String year);

  /// No description provided for @periodVariesHelp.
  ///
  /// In en, this message translates to:
  /// **'Takt or staffing changes inside this period. The map shows the state on its first day.'**
  String get periodVariesHelp;

  /// No description provided for @footerTaktHelp.
  ///
  /// In en, this message translates to:
  /// **'The rhythm of the production line in this period — one unit leaves the line every takt.'**
  String get footerTaktHelp;

  /// No description provided for @footerProcessTimeHelp.
  ///
  /// In en, this message translates to:
  /// **'Every step\'s process time added up. Value-adding time only; waiting is not counted.'**
  String get footerProcessTimeHelp;

  /// No description provided for @footerLeadTimeHelp.
  ///
  /// In en, this message translates to:
  /// **'Process time plus every wait between steps — how long one order takes to cross the whole flow.'**
  String get footerLeadTimeHelp;

  /// No description provided for @footerPceHelp.
  ///
  /// In en, this message translates to:
  /// **'Process cycle efficiency: process time ÷ lead time. The share of elapsed time that is value-adding.'**
  String get footerPceHelp;

  /// No description provided for @flowDataSource.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get flowDataSource;

  /// No description provided for @flowSourceEquivalent.
  ///
  /// In en, this message translates to:
  /// **'Flow equivalent'**
  String get flowSourceEquivalent;

  /// No description provided for @flowSourceSinglePart.
  ///
  /// In en, this message translates to:
  /// **'One part (needs demand)'**
  String get flowSourceSinglePart;

  /// No description provided for @flowSourceWeighted.
  ///
  /// In en, this message translates to:
  /// **'All variants, weighted (needs demand)'**
  String get flowSourceWeighted;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get exportPdf;

  /// No description provided for @flowSupplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get flowSupplier;

  /// No description provided for @flowCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get flowCustomer;

  /// No description provided for @flowFitToScreen.
  ///
  /// In en, this message translates to:
  /// **'Fit to screen'**
  String get flowFitToScreen;

  /// No description provided for @flowZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get flowZoomIn;

  /// No description provided for @flowZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get flowZoomOut;

  /// No description provided for @flowInsertHere.
  ///
  /// In en, this message translates to:
  /// **'Insert here'**
  String get flowInsertHere;

  /// No description provided for @flowInsertStep.
  ///
  /// In en, this message translates to:
  /// **'Process step'**
  String get flowInsertStep;

  /// No description provided for @flowInsertStepHelp.
  ///
  /// In en, this message translates to:
  /// **'Runs on a workcenter or a pool.'**
  String get flowInsertStepHelp;

  /// No description provided for @flowInsertInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get flowInsertInventory;

  /// No description provided for @flowInsertInventoryHelp.
  ///
  /// In en, this message translates to:
  /// **'Where orders wait between steps.'**
  String get flowInsertInventoryHelp;

  /// No description provided for @flowStep.
  ///
  /// In en, this message translates to:
  /// **'Process step'**
  String get flowStep;

  /// No description provided for @flowInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get flowInventory;

  /// No description provided for @flowStepTarget.
  ///
  /// In en, this message translates to:
  /// **'Workcenter or pool'**
  String get flowStepTarget;

  /// No description provided for @flowStepTargetHelp.
  ///
  /// In en, this message translates to:
  /// **'A step runs on exactly one. A pool sends each order to whichever member frees first.'**
  String get flowStepTargetHelp;

  /// No description provided for @flowNodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get flowNodeLabel;

  /// No description provided for @flowNodeLabelHelp.
  ///
  /// In en, this message translates to:
  /// **'Shown instead of the workcenter code.'**
  String get flowNodeLabelHelp;

  /// No description provided for @flowMoveLeft.
  ///
  /// In en, this message translates to:
  /// **'Move earlier'**
  String get flowMoveLeft;

  /// No description provided for @flowMoveRight.
  ///
  /// In en, this message translates to:
  /// **'Move later'**
  String get flowMoveRight;

  /// No description provided for @flowDeleteNodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this node from the flow?'**
  String get flowDeleteNodeTitle;

  /// No description provided for @stepProcessTime.
  ///
  /// In en, this message translates to:
  /// **'Process time'**
  String get stepProcessTime;

  /// No description provided for @stepChangeover.
  ///
  /// In en, this message translates to:
  /// **'Changeover'**
  String get stepChangeover;

  /// No description provided for @stepChangeoverHelp.
  ///
  /// In en, this message translates to:
  /// **'Charged only when the previous order on this workcenter was a different part.'**
  String get stepChangeoverHelp;

  /// No description provided for @stepOperators.
  ///
  /// In en, this message translates to:
  /// **'Operators'**
  String get stepOperators;

  /// No description provided for @stepEquivalentTime.
  ///
  /// In en, this message translates to:
  /// **'Process specific takt time'**
  String get stepEquivalentTime;

  /// No description provided for @stepEquivalentFollowsTakt.
  ///
  /// In en, this message translates to:
  /// **'Follows takt'**
  String get stepEquivalentFollowsTakt;

  /// No description provided for @stepEquivalentHelp.
  ///
  /// In en, this message translates to:
  /// **'This step\'s own takt, used by the flow equivalent instead of the line\'s. Leave blank to follow the line\'s takt. Set it where a full takt would skew the balance — an inspection worth a fraction of one. Days are this station\'s productive days, so 1 day equals one takt-day.'**
  String get stepEquivalentHelp;

  /// No description provided for @stepProblemUnbound.
  ///
  /// In en, this message translates to:
  /// **'No workcenter or pool selected.'**
  String get stepProblemUnbound;

  /// No description provided for @stepProblemArchived.
  ///
  /// In en, this message translates to:
  /// **'Its workcenter has been archived or deleted.'**
  String get stepProblemArchived;

  /// No description provided for @stepProblemNoSchedule.
  ///
  /// In en, this message translates to:
  /// **'No schedule period covers this month.'**
  String get stepProblemNoSchedule;

  /// No description provided for @stepProblemEmptyPool.
  ///
  /// In en, this message translates to:
  /// **'This pool has no members.'**
  String get stepProblemEmptyPool;

  /// Tooltip on a process box whose step targets a pool rather than one workcenter.
  ///
  /// In en, this message translates to:
  /// **'Pool · {count} workcenters'**
  String stepPoolMembers(String count);

  /// No description provided for @inventoryModeQuantity.
  ///
  /// In en, this message translates to:
  /// **'Pieces'**
  String get inventoryModeQuantity;

  /// No description provided for @inventoryModeDuration.
  ///
  /// In en, this message translates to:
  /// **'Fixed wait'**
  String get inventoryModeDuration;

  /// No description provided for @inventoryPieces.
  ///
  /// In en, this message translates to:
  /// **'Pieces waiting'**
  String get inventoryPieces;

  /// No description provided for @inventoryPiecesHelp.
  ///
  /// In en, this message translates to:
  /// **'Counted as days of stock: pieces × takt of the period being viewed.'**
  String get inventoryPiecesHelp;

  /// No description provided for @inventoryWait.
  ///
  /// In en, this message translates to:
  /// **'Wait'**
  String get inventoryWait;

  /// No description provided for @inventoryWaitHelp.
  ///
  /// In en, this message translates to:
  /// **'A day is 24 hours here. Whether those hours pass on the clock or only while the plant runs is the switch below.'**
  String get inventoryWaitHelp;

  /// No description provided for @inventoryWorkingTime.
  ///
  /// In en, this message translates to:
  /// **'Working time only'**
  String get inventoryWorkingTime;

  /// No description provided for @inventoryWorkingTimeHelp.
  ///
  /// In en, this message translates to:
  /// **'Off for cooling or transport, which do not stop for the weekend. On for a queue that only moves while the plant runs.'**
  String get inventoryWorkingTimeHelp;

  /// No description provided for @footerProcessTime.
  ///
  /// In en, this message translates to:
  /// **'Process time'**
  String get footerProcessTime;

  /// No description provided for @footerLeadTime.
  ///
  /// In en, this message translates to:
  /// **'Lead time'**
  String get footerLeadTime;

  /// No description provided for @footerPce.
  ///
  /// In en, this message translates to:
  /// **'PCE'**
  String get footerPce;

  /// No description provided for @footerEndDate.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get footerEndDate;

  /// No description provided for @footerRunningDays.
  ///
  /// In en, this message translates to:
  /// **'{days} running days · {date}'**
  String footerRunningDays(String days, String date);

  /// No description provided for @footerEndDateHelp.
  ///
  /// In en, this message translates to:
  /// **'When one order starting on the first day of this period would finish, walked through the real calendars. The gap against lead time is the weekends and shutdowns.'**
  String get footerEndDateHelp;

  /// No description provided for @pdfGenerated.
  ///
  /// In en, this message translates to:
  /// **'FlowMap {build} · generated {timestamp}'**
  String pdfGenerated(String build, String timestamp);

  /// No description provided for @pdfSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String pdfSaved(String path);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
