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

  /// No description provided for @studyTabSchedules.
  ///
  /// In en, this message translates to:
  /// **'Schedules'**
  String get studyTabSchedules;

  /// No description provided for @calendarExceptions.
  ///
  /// In en, this message translates to:
  /// **'Exceptions'**
  String get calendarExceptions;

  /// No description provided for @schedulesTaktScope.
  ///
  /// In en, this message translates to:
  /// **'shared by every study on this line'**
  String get schedulesTaktScope;

  /// No description provided for @schedulesExceptionsScope.
  ///
  /// In en, this message translates to:
  /// **'the whole project'**
  String get schedulesExceptionsScope;

  /// No description provided for @schedulesStationsScope.
  ///
  /// In en, this message translates to:
  /// **'this study\'s flow'**
  String get schedulesStationsScope;

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

  /// No description provided for @workcenterLines.
  ///
  /// In en, this message translates to:
  /// **'Drawn under these lines'**
  String get workcenterLines;

  /// No description provided for @workcenterLinesHelp.
  ///
  /// In en, this message translates to:
  /// **'Organisational only. Any study of any line can use this workcenter whichever boxes are ticked, and a station that serves two lines belongs under both.'**
  String get workcenterLinesHelp;

  /// No description provided for @workcenterNoLines.
  ///
  /// In en, this message translates to:
  /// **'This plant has no production lines yet.'**
  String get workcenterNoLines;

  /// No description provided for @workcenterOnLines.
  ///
  /// In en, this message translates to:
  /// **'on {count} lines'**
  String workcenterOnLines(String count);

  /// No description provided for @workcenterRemoveFromLine.
  ///
  /// In en, this message translates to:
  /// **'Take out of {line}'**
  String workcenterRemoveFromLine(String line);

  /// No description provided for @workcenterDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the workcenter from the plant, not just from this line. Its schedules go with it.'**
  String get workcenterDeleteBody;

  /// No description provided for @workcenterTypeIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get workcenterTypeIcon;

  /// No description provided for @workcenterTypeIconHelp.
  ///
  /// In en, this message translates to:
  /// **'Workcenters of this type are drawn with it, in the tree and in the pickers.'**
  String get workcenterTypeIconHelp;

  /// No description provided for @workcenterTypeNone.
  ///
  /// In en, this message translates to:
  /// **'No icon'**
  String get workcenterTypeNone;

  /// No description provided for @workcenterTypeEdit.
  ///
  /// In en, this message translates to:
  /// **'Workcenter type'**
  String get workcenterTypeEdit;

  /// No description provided for @iconMachining.
  ///
  /// In en, this message translates to:
  /// **'Machining'**
  String get iconMachining;

  /// No description provided for @iconLathe.
  ///
  /// In en, this message translates to:
  /// **'Lathe'**
  String get iconLathe;

  /// No description provided for @iconMilling.
  ///
  /// In en, this message translates to:
  /// **'Milling'**
  String get iconMilling;

  /// No description provided for @iconDrilling.
  ///
  /// In en, this message translates to:
  /// **'Drilling'**
  String get iconDrilling;

  /// No description provided for @iconGrinding.
  ///
  /// In en, this message translates to:
  /// **'Grinding'**
  String get iconGrinding;

  /// No description provided for @iconCutting.
  ///
  /// In en, this message translates to:
  /// **'Cutting'**
  String get iconCutting;

  /// No description provided for @iconBending.
  ///
  /// In en, this message translates to:
  /// **'Bending'**
  String get iconBending;

  /// No description provided for @iconPress.
  ///
  /// In en, this message translates to:
  /// **'Press'**
  String get iconPress;

  /// No description provided for @iconWelding.
  ///
  /// In en, this message translates to:
  /// **'Welding'**
  String get iconWelding;

  /// No description provided for @iconCladding.
  ///
  /// In en, this message translates to:
  /// **'Cladding'**
  String get iconCladding;

  /// No description provided for @iconHeatTreatment.
  ///
  /// In en, this message translates to:
  /// **'Heat treatment'**
  String get iconHeatTreatment;

  /// No description provided for @iconCoating.
  ///
  /// In en, this message translates to:
  /// **'Coating'**
  String get iconCoating;

  /// No description provided for @iconPainting.
  ///
  /// In en, this message translates to:
  /// **'Painting'**
  String get iconPainting;

  /// No description provided for @iconCleaning.
  ///
  /// In en, this message translates to:
  /// **'Cleaning'**
  String get iconCleaning;

  /// No description provided for @iconAssembly.
  ///
  /// In en, this message translates to:
  /// **'Assembly'**
  String get iconAssembly;

  /// No description provided for @iconRobot.
  ///
  /// In en, this message translates to:
  /// **'Robot'**
  String get iconRobot;

  /// No description provided for @iconConveyor.
  ///
  /// In en, this message translates to:
  /// **'Conveyor'**
  String get iconConveyor;

  /// No description provided for @iconInspection.
  ///
  /// In en, this message translates to:
  /// **'Inspection'**
  String get iconInspection;

  /// No description provided for @iconTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing'**
  String get iconTesting;

  /// No description provided for @iconMeasuring.
  ///
  /// In en, this message translates to:
  /// **'Measuring'**
  String get iconMeasuring;

  /// No description provided for @iconPacking.
  ///
  /// In en, this message translates to:
  /// **'Packing'**
  String get iconPacking;

  /// No description provided for @iconStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get iconStorage;

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

  /// No description provided for @projectDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Its studies, schedules and flows go with it. This cannot be undone.'**
  String get projectDeleteBody;

  /// No description provided for @study.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get study;

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

  /// No description provided for @studiesCollapse.
  ///
  /// In en, this message translates to:
  /// **'Hide the studies list'**
  String get studiesCollapse;

  /// No description provided for @studiesExpand.
  ///
  /// In en, this message translates to:
  /// **'Show the studies list'**
  String get studiesExpand;

  /// No description provided for @studyTabSettings.
  ///
  /// In en, this message translates to:
  /// **'Study Settings'**
  String get studyTabSettings;

  /// No description provided for @studyTabTakt.
  ///
  /// In en, this message translates to:
  /// **'Flow Takt'**
  String get studyTabTakt;

  /// No description provided for @studySettingsIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get studySettingsIdentity;

  /// No description provided for @studySettingsInRuns.
  ///
  /// In en, this message translates to:
  /// **'In simulation'**
  String get studySettingsInRuns;

  /// No description provided for @studyName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get studyName;

  /// No description provided for @studyLine.
  ///
  /// In en, this message translates to:
  /// **'Production line'**
  String get studyLine;

  /// No description provided for @studyIncludeInRuns.
  ///
  /// In en, this message translates to:
  /// **'Include in runs'**
  String get studyIncludeInRuns;

  /// No description provided for @studyIncludeInRunsHelp.
  ///
  /// In en, this message translates to:
  /// **'A run takes every included study at once, contending for the same plant.'**
  String get studyIncludeInRunsHelp;

  /// No description provided for @studyWipCap.
  ///
  /// In en, this message translates to:
  /// **'WIP cap'**
  String get studyWipCap;

  /// No description provided for @studyWipCapUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get studyWipCapUnlimited;

  /// No description provided for @studyWipCapHelp.
  ///
  /// In en, this message translates to:
  /// **'The most orders this study may have in the flow at once. A release waits for a completion, which is what makes the flow pulled rather than pushed. Blank is unlimited.'**
  String get studyWipCapHelp;

  /// No description provided for @studyPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get studyPriority;

  /// No description provided for @studyPriorityHelp.
  ///
  /// In en, this message translates to:
  /// **'Which study wins when two of them want the same station at the same instant. Lower goes first. Only a tie-break — it never reorders a queue on its own.'**
  String get studyPriorityHelp;

  /// No description provided for @studyTabFlow.
  ///
  /// In en, this message translates to:
  /// **'Flow'**
  String get studyTabFlow;

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

  /// No description provided for @validationPositiveNumber.
  ///
  /// In en, this message translates to:
  /// **'A number above zero'**
  String get validationPositiveNumber;

  /// No description provided for @validationUnknownUnit.
  ///
  /// In en, this message translates to:
  /// **'Not a unit — try days, hours, min or s'**
  String get validationUnknownUnit;

  /// No description provided for @validationNotAPercentage.
  ///
  /// In en, this message translates to:
  /// **'A percentage between 0 and 100'**
  String get validationNotAPercentage;

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

  /// No description provided for @mm3SlotLoad.
  ///
  /// In en, this message translates to:
  /// **'Slot load'**
  String get mm3SlotLoad;

  /// No description provided for @mm3SlotLoadHelp.
  ///
  /// In en, this message translates to:
  /// **'The part\'s equivalent times its batch size — what this release slot actually costs the flow. MM3 averages this, not the equivalent.'**
  String get mm3SlotLoadHelp;

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

  /// No description provided for @actionImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get actionImport;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from {file}'**
  String importTitle(String file);

  /// No description provided for @importSheet.
  ///
  /// In en, this message translates to:
  /// **'Sheet'**
  String get importSheet;

  /// No description provided for @importMapping.
  ///
  /// In en, this message translates to:
  /// **'Their columns to ours'**
  String get importMapping;

  /// No description provided for @importNotMapped.
  ///
  /// In en, this message translates to:
  /// **'Not mapped'**
  String get importNotMapped;

  /// No description provided for @importColumnNumber.
  ///
  /// In en, this message translates to:
  /// **'Column {n}'**
  String importColumnNumber(String n);

  /// No description provided for @importUnmapped.
  ///
  /// In en, this message translates to:
  /// **'Nothing found for: {columns}. Those values will be left as they are.'**
  String importUnmapped(String columns);

  /// No description provided for @importPreview.
  ///
  /// In en, this message translates to:
  /// **'What will go in'**
  String get importPreview;

  /// No description provided for @importCountOk.
  ///
  /// In en, this message translates to:
  /// **'{count} rows ready'**
  String importCountOk(String count);

  /// No description provided for @importCountSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count} skipped'**
  String importCountSkipped(String count);

  /// No description provided for @importCountWarned.
  ///
  /// In en, this message translates to:
  /// **'{count} to look at'**
  String importCountWarned(String count);

  /// No description provided for @importPreviewTruncated.
  ///
  /// In en, this message translates to:
  /// **'and {count} more rows'**
  String importPreviewTruncated(String count);

  /// No description provided for @importAccept.
  ///
  /// In en, this message translates to:
  /// **'Import {count} rows'**
  String importAccept(String count);

  /// No description provided for @importDone.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} rows.'**
  String importDone(String count);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Nothing was imported: {error}'**
  String importFailed(String error);

  /// No description provided for @importUnreadable.
  ///
  /// In en, this message translates to:
  /// **'That file could not be read: {error}'**
  String importUnreadable(String error);

  /// No description provided for @importEmpty.
  ///
  /// In en, this message translates to:
  /// **'That file has no rows under a heading row.'**
  String get importEmpty;

  /// No description provided for @importIssueMissingPart.
  ///
  /// In en, this message translates to:
  /// **'No part number'**
  String get importIssueMissingPart;

  /// No description provided for @importIssueDuplicatePart.
  ///
  /// In en, this message translates to:
  /// **'This part appears twice in the file'**
  String get importIssueDuplicatePart;

  /// No description provided for @importIssueNeedBeforeMaterial.
  ///
  /// In en, this message translates to:
  /// **'Needed before its material arrives'**
  String get importIssueNeedBeforeMaterial;

  /// No description provided for @fieldNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get fieldNote;

  /// No description provided for @exceptions.
  ///
  /// In en, this message translates to:
  /// **'Calendar exceptions'**
  String get exceptions;

  /// No description provided for @exceptionNew.
  ///
  /// In en, this message translates to:
  /// **'New exception'**
  String get exceptionNew;

  /// No description provided for @exceptionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'None. The plant runs its shift pattern every working day.'**
  String get exceptionsEmpty;

  /// No description provided for @exceptionsHelp.
  ///
  /// In en, this message translates to:
  /// **'Holidays, shutdowns and extra hours. The most specific scope wins, so a plant-wide shutdown can be overridden by opening one workcenter that Saturday.'**
  String get exceptionsHelp;

  /// No description provided for @exceptionKindNonWorking.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get exceptionKindNonWorking;

  /// No description provided for @exceptionKindExtraWorking.
  ///
  /// In en, this message translates to:
  /// **'Extra hours'**
  String get exceptionKindExtraWorking;

  /// No description provided for @exceptionScope.
  ///
  /// In en, this message translates to:
  /// **'Applies to'**
  String get exceptionScope;

  /// No description provided for @exceptionScopePlant.
  ///
  /// In en, this message translates to:
  /// **'Whole plant'**
  String get exceptionScopePlant;

  /// No description provided for @exceptionScopeHelp.
  ///
  /// In en, this message translates to:
  /// **'A pool can be chosen under Workcenter; it is saved as one exception per member.'**
  String get exceptionScopeHelp;

  /// No description provided for @exceptionOperatorsHelp.
  ///
  /// In en, this message translates to:
  /// **'Who is on each shift that day. A zero closes that shift.'**
  String get exceptionOperatorsHelp;

  /// No description provided for @exceptionDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this exception?'**
  String get exceptionDeleteTitle;

  /// No description provided for @flowEndpointRename.
  ///
  /// In en, this message translates to:
  /// **'Rename endpoint'**
  String get flowEndpointRename;

  /// No description provided for @demandProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get demandProject;

  /// No description provided for @demandDeleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all orders'**
  String get demandDeleteAll;

  /// No description provided for @demandDeleteAllBody.
  ///
  /// In en, this message translates to:
  /// **'Every order in the sequence goes. The parts and their process times stay.'**
  String get demandDeleteAllBody;

  /// No description provided for @stepCycleTime.
  ///
  /// In en, this message translates to:
  /// **'Takt C/T'**
  String get stepCycleTime;

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
  /// **'Batch size'**
  String get demandBatchSize;

  /// No description provided for @demandBatchNumber.
  ///
  /// In en, this message translates to:
  /// **'Batch no.'**
  String get demandBatchNumber;

  /// No description provided for @demandBatchNumberHelp.
  ///
  /// In en, this message translates to:
  /// **'Your own identifier for this batch of this part — whatever the paperwork calls it. Free text: nothing matches on it, duplicates are allowed and it may be left blank. It appears on the production plan so a printed order can be found in your system.'**
  String get demandBatchNumberHelp;

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
  /// **'Part'**
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

  /// No description provided for @flowNodeNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get flowNodeNotes;

  /// No description provided for @flowNodeHasNotes.
  ///
  /// In en, this message translates to:
  /// **'Has notes'**
  String get flowNodeHasNotes;

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

  /// No description provided for @stepSetup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get stepSetup;

  /// No description provided for @stepTeardown.
  ///
  /// In en, this message translates to:
  /// **'Teardown'**
  String get stepTeardown;

  /// No description provided for @stepTeardownHelp.
  ///
  /// In en, this message translates to:
  /// **'Stripping the station after an order. Charged together with the next order’s setup, because whether a strip-down is needed depends on what comes next.'**
  String get stepTeardownHelp;

  /// No description provided for @stepSamePart.
  ///
  /// In en, this message translates to:
  /// **'Same part'**
  String get stepSamePart;

  /// No description provided for @stepSamePartHelp.
  ///
  /// In en, this message translates to:
  /// **'How much of the setup and teardown is still charged when the previous order was the same part. 0% makes a repeat free; 100% means batching buys nothing.'**
  String get stepSamePartHelp;

  /// No description provided for @stepChangeover.
  ///
  /// In en, this message translates to:
  /// **'Changeover'**
  String get stepChangeover;

  /// No description provided for @laneRule.
  ///
  /// In en, this message translates to:
  /// **'Queue order'**
  String get laneRule;

  /// No description provided for @laneRuleHelp.
  ///
  /// In en, this message translates to:
  /// **'How the station ahead picks the next order out of this lane. On a real lane you cannot take from the back, so this is a decision about the queue rather than about the machine — and it belongs here, where the queue is drawn.'**
  String get laneRuleHelp;

  /// No description provided for @laneRuleFollowsRun.
  ///
  /// In en, this message translates to:
  /// **'Follow the run\'s rule'**
  String get laneRuleFollowsRun;

  /// No description provided for @laneCapacity.
  ///
  /// In en, this message translates to:
  /// **'Lane capacity (orders)'**
  String get laneCapacity;

  /// No description provided for @laneCapacityHelp.
  ///
  /// In en, this message translates to:
  /// **'How many orders fit here. Leave blank for unlimited. When it is full the station behind cannot put its finished order down and stops, which is how congestion reaches back up the line. Separate from the pieces above: that figure is what is standing here today, this is what the floor allows.'**
  String get laneCapacityHelp;

  /// No description provided for @workcenterParallelCapacity.
  ///
  /// In en, this message translates to:
  /// **'Orders at once'**
  String get workcenterParallelCapacity;

  /// No description provided for @workcenterParallelCapacityHelp.
  ///
  /// In en, this message translates to:
  /// **'How many orders this station runs side by side. One is a single machine. Above one it has that many independent units, each paying its own changeovers — and twice the capacity everywhere it is measured. Use a pool instead when the machines are really separate and you want to see which ran what.'**
  String get workcenterParallelCapacityHelp;

  /// No description provided for @studyRunSettings.
  ///
  /// In en, this message translates to:
  /// **'Run settings'**
  String get studyRunSettings;

  /// No description provided for @studyStartBuffer.
  ///
  /// In en, this message translates to:
  /// **'Start buffer (calendar days)'**
  String get studyStartBuffer;

  /// No description provided for @studyStartBufferHelp.
  ///
  /// In en, this message translates to:
  /// **'Extra margin ahead of the calculated start. A run begins at the first order\'s need date, less its theoretical lead time, less this. Calendar days, because slippage happens whether or not the plant is open.'**
  String get studyStartBufferHelp;

  /// No description provided for @studyPaceSetter.
  ///
  /// In en, this message translates to:
  /// **'Pacemaker'**
  String get studyPaceSetter;

  /// No description provided for @studyPaceSetterHelp.
  ///
  /// In en, this message translates to:
  /// **'The station whose clock sets the release cadence, and whose lane decides when another order may start. Leave on automatic to use the busiest step.'**
  String get studyPaceSetterHelp;

  /// No description provided for @studyPaceSetterAutomatic.
  ///
  /// In en, this message translates to:
  /// **'Automatic — the busiest step'**
  String get studyPaceSetterAutomatic;

  /// No description provided for @simBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get simBlocked;

  /// No description provided for @simBlockedHelp.
  ///
  /// In en, this message translates to:
  /// **'Time the station spent holding a finished order because the lane ahead was full. Not counted as busy: a jammed station is occupied and producing nothing.'**
  String get simBlockedHelp;

  /// No description provided for @simEmptySlotLaneFull.
  ///
  /// In en, this message translates to:
  /// **'Lane full'**
  String get simEmptySlotLaneFull;

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
  /// **'Lead time (working days)'**
  String get footerLeadTime;

  /// No description provided for @footerLeadTimeRunning.
  ///
  /// In en, this message translates to:
  /// **'Lead time (running days)'**
  String get footerLeadTimeRunning;

  /// No description provided for @footerLeadTimeRunningHelp.
  ///
  /// In en, this message translates to:
  /// **'The working-day lead time × 1.4, the usual seven-over-five convention. A planning figure rather than a measurement: a simulation walks each station’s real calendar instead, so the two can differ and the run is what happened.'**
  String get footerLeadTimeRunningHelp;

  /// No description provided for @footerPce.
  ///
  /// In en, this message translates to:
  /// **'Process efficiency'**
  String get footerPce;

  /// No description provided for @exportGenerated.
  ///
  /// In en, this message translates to:
  /// **'FlowMap {build} · generated {timestamp}'**
  String exportGenerated(String build, String timestamp);

  /// No description provided for @exportSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String exportSaved(String path);

  /// No description provided for @projectTabSimulation.
  ///
  /// In en, this message translates to:
  /// **'Simulation'**
  String get projectTabSimulation;

  /// No description provided for @simFilterStudies.
  ///
  /// In en, this message translates to:
  /// **'Studies'**
  String get simFilterStudies;

  /// No description provided for @simFilterCells.
  ///
  /// In en, this message translates to:
  /// **'Cells'**
  String get simFilterCells;

  /// No description provided for @simFilterLines.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get simFilterLines;

  /// No description provided for @simFilterPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get simFilterPeriod;

  /// No description provided for @simFilterPeriodHelp.
  ///
  /// In en, this message translates to:
  /// **'Selects orders by their need date — the only one of an order’s dates that is never blank, so an order the run never completed still appears in its period. Station utilisation and blocked time keep describing the whole run, because the run does not store what a windowed figure would need.'**
  String get simFilterPeriodHelp;

  /// No description provided for @simFilterAll.
  ///
  /// In en, this message translates to:
  /// **'all'**
  String get simFilterAll;

  /// No description provided for @simFilterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get simFilterClear;

  /// No description provided for @simWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Simulation'**
  String get simWorkspace;

  /// No description provided for @simStationsWholeRun.
  ///
  /// In en, this message translates to:
  /// **'These describe the whole run, not the filtered slice — the run does not store what a narrowed open time would need.'**
  String get simStationsWholeRun;

  /// No description provided for @simulationRun.
  ///
  /// In en, this message translates to:
  /// **'Simulate'**
  String get simulationRun;

  /// No description provided for @simulationRunning.
  ///
  /// In en, this message translates to:
  /// **'Running…'**
  String get simulationRunning;

  /// No description provided for @simulationRunSettings.
  ///
  /// In en, this message translates to:
  /// **'Run settings'**
  String get simulationRunSettings;

  /// No description provided for @simulationDispatch.
  ///
  /// In en, this message translates to:
  /// **'Dispatch'**
  String get simulationDispatch;

  /// No description provided for @simulationDispatchHelp.
  ///
  /// In en, this message translates to:
  /// **'How a workcenter picks which waiting order to run next. Every rule breaks ties by arrival, then study priority, then sequence, so the same inputs always produce the same run.'**
  String get simulationDispatchHelp;

  /// No description provided for @dispatchFifo.
  ///
  /// In en, this message translates to:
  /// **'FIFO — by arrival'**
  String get dispatchFifo;

  /// No description provided for @dispatchEarliestDueDate.
  ///
  /// In en, this message translates to:
  /// **'Earliest need date'**
  String get dispatchEarliestDueDate;

  /// No description provided for @dispatchShortestProcessing.
  ///
  /// In en, this message translates to:
  /// **'Shortest processing time'**
  String get dispatchShortestProcessing;

  /// No description provided for @simulationStudiesIn.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No studies selected} =1{1 study in this run} other{{count} studies in this run}}'**
  String simulationStudiesIn(int count);

  /// No description provided for @simulationNoStudies.
  ///
  /// In en, this message translates to:
  /// **'No study is selected for a run'**
  String get simulationNoStudies;

  /// No description provided for @simulationNoStudiesHelp.
  ///
  /// In en, this message translates to:
  /// **'Flag a study in the sidebar. Several studies of one line are scenarios of one reality, so a run takes at most one of each.'**
  String get simulationNoStudiesHelp;

  /// No description provided for @simulationNotReady.
  ///
  /// In en, this message translates to:
  /// **'Not ready to run'**
  String get simulationNotReady;

  /// No description provided for @simProblemNoTakt.
  ///
  /// In en, this message translates to:
  /// **'No takt period covers the day this run would start.'**
  String get simProblemNoTakt;

  /// No description provided for @simProblemNoOrders.
  ///
  /// In en, this message translates to:
  /// **'The demand sequence is empty — there is nothing to release.'**
  String get simProblemNoOrders;

  /// No description provided for @simProblemUnboundStep.
  ///
  /// In en, this message translates to:
  /// **'A step targets no workcenter, or its pool is empty.'**
  String get simProblemUnboundStep;

  /// No description provided for @simProblemNoPaceSetter.
  ///
  /// In en, this message translates to:
  /// **'No step can pace the releases: every one of them is unbound.'**
  String get simProblemNoPaceSetter;

  /// No description provided for @simulationNeverRun.
  ///
  /// In en, this message translates to:
  /// **'No run yet'**
  String get simulationNeverRun;

  /// No description provided for @simulationNeverRunHelp.
  ///
  /// In en, this message translates to:
  /// **'Simulate runs every selected study against one model of the plant, so one line’s orders genuinely delay another’s.'**
  String get simulationNeverRunHelp;

  /// No description provided for @simulationAbortHorizon.
  ///
  /// In en, this message translates to:
  /// **'Demand exceeds capacity. {count} orders never completed, and the run was abandoned rather than looping forever.'**
  String simulationAbortHorizon(String count);

  /// No description provided for @simulationAbortNothingToRun.
  ///
  /// In en, this message translates to:
  /// **'Nothing could be started: every station’s calendar is shut, or no study had a costable first order.'**
  String get simulationAbortNothingToRun;

  /// No description provided for @simOnTimeDelivery.
  ///
  /// In en, this message translates to:
  /// **'On-time delivery'**
  String get simOnTimeDelivery;

  /// No description provided for @simOnTimeOfOrders.
  ///
  /// In en, this message translates to:
  /// **'{onTime} of {orders} orders on time'**
  String simOnTimeOfOrders(String onTime, String orders);

  /// No description provided for @simOnTimeHelp.
  ///
  /// In en, this message translates to:
  /// **'Counted over every order, not only the delivered ones: an order that never came out is not on time, whatever its need date says.'**
  String get simOnTimeHelp;

  /// No description provided for @simDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get simDelivered;

  /// No description provided for @simDeliveredOf.
  ///
  /// In en, this message translates to:
  /// **'{delivered} of {orders}'**
  String simDeliveredOf(String delivered, String orders);

  /// No description provided for @simAverageFloat.
  ///
  /// In en, this message translates to:
  /// **'Average float'**
  String get simAverageFloat;

  /// No description provided for @simAverageFloatHelp.
  ///
  /// In en, this message translates to:
  /// **'Need date minus order end, averaged over the orders that finished. Positive is early, with that much time in hand; negative is late by that much. An order that never ended has no float and is left out here — it still counts as late above.'**
  String get simAverageFloatHelp;

  /// No description provided for @simAverageLeadTime.
  ///
  /// In en, this message translates to:
  /// **'Average lead time'**
  String get simAverageLeadTime;

  /// No description provided for @simAverageLeadTimeHelp.
  ///
  /// In en, this message translates to:
  /// **'Wall-clock time in the flow, from release to the last step.'**
  String get simAverageLeadTimeHelp;

  /// No description provided for @simTheoreticalLeadTime.
  ///
  /// In en, this message translates to:
  /// **'Theoretical lead time'**
  String get simTheoreticalLeadTime;

  /// No description provided for @simTheoreticalLeadTimeHelp.
  ///
  /// In en, this message translates to:
  /// **'The same orders without queueing, each walked from its own release through the real calendars. Excludes changeover, which depends on what ran before and so is not a property of the part.'**
  String get simTheoreticalLeadTimeHelp;

  /// No description provided for @simLeadTimeEfficiency.
  ///
  /// In en, this message translates to:
  /// **'Lead-time efficiency'**
  String get simLeadTimeEfficiency;

  /// No description provided for @simLeadTimeEfficiencyHelp.
  ///
  /// In en, this message translates to:
  /// **'Actual ÷ theoretical. 1.0 is queue-free and higher is worse; the excess over 1.0 is exactly the waiting.'**
  String get simLeadTimeEfficiencyHelp;

  /// No description provided for @simEmptySlots.
  ///
  /// In en, this message translates to:
  /// **'Empty release slots'**
  String get simEmptySlots;

  /// No description provided for @simEmptySlotsHelp.
  ///
  /// In en, this message translates to:
  /// **'Slots that came round with nothing to put in them: the head of the sequence had no material yet, or the flow was already at its WIP cap. The sequence is the thing under study, so an empty slot is counted rather than quietly repaired.'**
  String get simEmptySlotsHelp;

  /// No description provided for @simByQueue.
  ///
  /// In en, this message translates to:
  /// **'Ranked by queue time'**
  String get simByQueue;

  /// No description provided for @simByShare.
  ///
  /// In en, this message translates to:
  /// **'Ranked by share of the flow'**
  String get simByShare;

  /// No description provided for @simRankingsHelp.
  ///
  /// In en, this message translates to:
  /// **'Both rankings are here because their disagreement is the diagnostic: a long queue at a station that is not busy is a sequencing problem, not a capacity one.'**
  String get simRankingsHelp;

  /// No description provided for @simQueue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get simQueue;

  /// No description provided for @simQueueAverage.
  ///
  /// In en, this message translates to:
  /// **'Average queue'**
  String get simQueueAverage;

  /// No description provided for @simVisits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get simVisits;

  /// No description provided for @simChangeovers.
  ///
  /// In en, this message translates to:
  /// **'Changeovers'**
  String get simChangeovers;

  /// No description provided for @utilization.
  ///
  /// In en, this message translates to:
  /// **'Utilization'**
  String get utilization;

  /// No description provided for @simUtilizationHelp.
  ///
  /// In en, this message translates to:
  /// **'Busy ÷ open time observed in this run. Not the same as occupation, which is required ÷ available before any run — where the two disagree, sequencing or starvation got in the way.'**
  String get simUtilizationHelp;

  /// No description provided for @simContributed.
  ///
  /// In en, this message translates to:
  /// **'Queue + processing'**
  String get simContributed;

  /// No description provided for @simShareOfFlow.
  ///
  /// In en, this message translates to:
  /// **'Share of flow'**
  String get simShareOfFlow;

  /// No description provided for @simPerPart.
  ///
  /// In en, this message translates to:
  /// **'Per part number'**
  String get simPerPart;

  /// No description provided for @simOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get simOrders;

  /// No description provided for @simOnTime.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get simOnTime;

  /// No description provided for @simNothingRanked.
  ///
  /// In en, this message translates to:
  /// **'No station ran anything.'**
  String get simNothingRanked;

  /// No description provided for @simRunSpan.
  ///
  /// In en, this message translates to:
  /// **'{start} → {end}'**
  String simRunSpan(String start, String end);

  /// No description provided for @simEarlierRuns.
  ///
  /// In en, this message translates to:
  /// **'Earlier runs'**
  String get simEarlierRuns;

  /// No description provided for @simRunLabel.
  ///
  /// In en, this message translates to:
  /// **'{timestamp} · {rule}'**
  String simRunLabel(String timestamp, String rule);

  /// No description provided for @simViewResults.
  ///
  /// In en, this message translates to:
  /// **'View results'**
  String get simViewResults;

  /// No description provided for @simulationRunFailed.
  ///
  /// In en, this message translates to:
  /// **'The run could not be completed'**
  String get simulationRunFailed;

  /// No description provided for @simProductionPlan.
  ///
  /// In en, this message translates to:
  /// **'Production plan — orders over time'**
  String get simProductionPlan;

  /// No description provided for @simProductionPlanHelp.
  ///
  /// In en, this message translates to:
  /// **'What this run says each order does. Rows are in sequence order, which is also release order: the engine releases strictly from the head of the sequence and never reorders it. Blank columns mean a run made before FlowMap recorded them.'**
  String get simProductionPlanHelp;

  /// No description provided for @simPlanOrder.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get simPlanOrder;

  /// No description provided for @simPlanOrderStart.
  ///
  /// In en, this message translates to:
  /// **'Order start'**
  String get simPlanOrderStart;

  /// No description provided for @simPlanOrderEnd.
  ///
  /// In en, this message translates to:
  /// **'Order end'**
  String get simPlanOrderEnd;

  /// No description provided for @simPlanTheoreticalLeadTime.
  ///
  /// In en, this message translates to:
  /// **'Theoretical LT'**
  String get simPlanTheoreticalLeadTime;

  /// No description provided for @simPlanActualLeadTime.
  ///
  /// In en, this message translates to:
  /// **'Actual LT'**
  String get simPlanActualLeadTime;

  /// No description provided for @simDispatchOverrides.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 station overridden} other{{count} stations overridden}}'**
  String simDispatchOverrides(int count);

  /// No description provided for @simDispatchOverrideRow.
  ///
  /// In en, this message translates to:
  /// **'{name}: {rule}'**
  String simDispatchOverrideRow(String name, String rule);

  /// No description provided for @simRunDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'The run and everything it recorded go. The studies it was made from are untouched.'**
  String get simRunDeleteBody;

  /// No description provided for @simResultsView.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get simResultsView;

  /// No description provided for @simGanttView.
  ///
  /// In en, this message translates to:
  /// **'Gantt'**
  String get simGanttView;

  /// No description provided for @simGanttEmpty.
  ///
  /// In en, this message translates to:
  /// **'This run recorded no steps, so there is nothing to draw.'**
  String get simGanttEmpty;

  /// No description provided for @simGanttGapHelp.
  ///
  /// In en, this message translates to:
  /// **'One row per station, one bar per order, all studies together — a station is shared, so splitting the chart by study would draw it idle while it was running another line\'s order. A bar is the station committed to that order, closed hours included. A gap is a station not running: closed, or starved. How much of it was open at all is in the Queue table.'**
  String get simGanttGapHelp;

  /// No description provided for @simGanttOrder.
  ///
  /// In en, this message translates to:
  /// **'Order {number}'**
  String simGanttOrder(String number);

  /// No description provided for @simGanttCommitted.
  ///
  /// In en, this message translates to:
  /// **'Committed'**
  String get simGanttCommitted;

  /// No description provided for @simGanttWaited.
  ///
  /// In en, this message translates to:
  /// **'Waited before starting'**
  String get simGanttWaited;

  /// No description provided for @simGanttChangeover.
  ///
  /// In en, this message translates to:
  /// **'A changeover was paid to start it'**
  String get simGanttChangeover;

  /// No description provided for @simScheduleTail.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 order finished after {date} using the last defined schedule} other{{count} orders finished after {date} using the last defined schedule}}'**
  String simScheduleTail(int count, String date);

  /// No description provided for @simScheduleTailHelp.
  ///
  /// In en, this message translates to:
  /// **'Takt and workcenter schedule periods stop at that date, so the run carried the last one forward past it. That is not an error — a run goes until the last order completes — but the figures after that date describe capacity nobody has defined. Extend the periods and run again to be sure of them.'**
  String get simScheduleTailHelp;

  /// No description provided for @settingsDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get settingsDisplay;

  /// No description provided for @settingsDateFormatHelp.
  ///
  /// In en, this message translates to:
  /// **'How dates are written and read across the app, including the Excel export. Independent of the interface language. ISO dates are always accepted when typing, whichever format is chosen.'**
  String get settingsDateFormatHelp;

  /// No description provided for @dateFormatLocale.
  ///
  /// In en, this message translates to:
  /// **'Follow the system language'**
  String get dateFormatLocale;

  /// No description provided for @dateFormatDayMonthYear.
  ///
  /// In en, this message translates to:
  /// **'Day/month/year'**
  String get dateFormatDayMonthYear;

  /// No description provided for @dateFormatMonthDayYear.
  ///
  /// In en, this message translates to:
  /// **'Month/day/year'**
  String get dateFormatMonthDayYear;

  /// No description provided for @dateFormatIso.
  ///
  /// In en, this message translates to:
  /// **'Year-month-day (ISO)'**
  String get dateFormatIso;

  /// No description provided for @simGanttLaneHolds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Lane holds 1 order} other{Lane holds {count} orders}}'**
  String simGanttLaneHolds(int count);

  /// No description provided for @simGanttLaneUncapped.
  ///
  /// In en, this message translates to:
  /// **'Lane has no limit'**
  String get simGanttLaneUncapped;

  /// No description provided for @simGanttStillWaiting.
  ///
  /// In en, this message translates to:
  /// **'Still standing here when the run ended'**
  String get simGanttStillWaiting;

  /// No description provided for @simGanttRowsStations.
  ///
  /// In en, this message translates to:
  /// **'Stations'**
  String get simGanttRowsStations;

  /// No description provided for @simGanttRowsWithLanes.
  ///
  /// In en, this message translates to:
  /// **'Stations + lanes'**
  String get simGanttRowsWithLanes;

  /// No description provided for @simGanttRowsHelp.
  ///
  /// In en, this message translates to:
  /// **'Whether the queue bands between stations are drawn. Without them the chart reads as a flow; with them it reads as a queue.'**
  String get simGanttRowsHelp;

  /// No description provided for @simGanttZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get simGanttZoomIn;

  /// No description provided for @simGanttZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get simGanttZoomOut;

  /// No description provided for @simGanttFloored.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 bar drawn wider than it is} other{{count} bars drawn wider than they are}}'**
  String simGanttFloored(int count);

  /// No description provided for @simGanttFlooredHelp.
  ///
  /// In en, this message translates to:
  /// **'At this zoom these steps are thinner than a pixel, so they are drawn at the minimum width to keep them visible. Their position is exact; their width is not. Zoom in and the note goes.'**
  String get simGanttFlooredHelp;

  /// No description provided for @exportExcel.
  ///
  /// In en, this message translates to:
  /// **'Export to Excel'**
  String get exportExcel;

  /// No description provided for @simExportRunSheet.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get simExportRunSheet;
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
