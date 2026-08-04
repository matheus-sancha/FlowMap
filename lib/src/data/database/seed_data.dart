/// The reference data a fresh install starts with.
///
/// Seeded content, not built-in behaviour: every row here is editable and
/// deletable, and nothing in the app assumes any of it exists.
library;

import 'enums.dart';

/// The workcenter types from the spec. Users add their own.
/// A guess at the icon for a type the user has just named, so the seeds and
/// most hand-typed names arrive with a sensible glyph rather than a blank.
///
/// Matched on the name as typed, in English, because that is what the seeds are
/// and what a shop-floor picklist is written in. A wrong guess costs one click
/// in the picker; no guess costs a click for every type anyone ever creates.
WorkcenterIcon? guessWorkcenterIcon(String typeName) {
  final name = typeName.toLowerCase();
  for (final entry in _iconGuesses.entries) {
    if (name.contains(entry.key)) return entry.value;
  }
  return null;
}

const _iconGuesses = <String, WorkcenterIcon>{
  'lathe': WorkcenterIcon.lathe,
  'turn': WorkcenterIcon.lathe,
  'mill': WorkcenterIcon.milling,
  'drill': WorkcenterIcon.drilling,
  'grind': WorkcenterIcon.grinding,
  'cut': WorkcenterIcon.cutting,
  'saw': WorkcenterIcon.cutting,
  'bend': WorkcenterIcon.bending,
  'press': WorkcenterIcon.press,
  'stamp': WorkcenterIcon.press,
  'weld': WorkcenterIcon.welding,
  'clad': WorkcenterIcon.cladding,
  'heat': WorkcenterIcon.heatTreatment,
  'furnace': WorkcenterIcon.heatTreatment,
  'oven': WorkcenterIcon.heatTreatment,
  'coat': WorkcenterIcon.coating,
  'paint': WorkcenterIcon.painting,
  'clean': WorkcenterIcon.cleaning,
  'wash': WorkcenterIcon.cleaning,
  'assembl': WorkcenterIcon.assembly,
  'robot': WorkcenterIcon.robot,
  'conveyor': WorkcenterIcon.conveyor,
  'inspect': WorkcenterIcon.inspection,
  'test': WorkcenterIcon.testing,
  'measur': WorkcenterIcon.measuring,
  'pack': WorkcenterIcon.packing,
  'stor': WorkcenterIcon.storage,
  'machin': WorkcenterIcon.machining,
};

const workcenterTypeSeeds = <String>[
  'Machining',
  'Cladding',
  'Welding',
  'Coating',
  'Heat Treatment',
  'Bending',
  'Assembly',
  'Testing',
  'Inspection',
];

/// A shift inside a [ShiftPatternSeed], with times as minutes from midnight.
class ShiftSeed {
  const ShiftSeed(
    this.label,
    this.startMinute,
    this.endMinute, {
    this.breakSeconds = 0,
  });

  final String label;
  final int startMinute;
  final int endMinute;
  final int breakSeconds;
}

class ShiftPatternSeed {
  const ShiftPatternSeed({
    required this.name,
    required this.cycleType,
    required this.workingWeekdays,
    required this.shifts,
    this.notes,
  });

  final String name;
  final ShiftCycleType cycleType;
  final int workingWeekdays;
  final List<ShiftSeed> shifts;
  final String? notes;
}

/// Monday–Friday, as a [ShiftPatterns.workingWeekdays] bitmask.
const _mondayToFriday = 1 | 2 | 4 | 8 | 16;
const _everyDay = 1 | 2 | 4 | 8 | 16 | 32 | 64;

const _minutes40 = 40 * 60;

const shiftPatternSeeds = <ShiftPatternSeed>[
  // Monday–Friday, three shifts, 40-minute break each. Saturday and Sunday are
  // opened by a calendar exception when extra hours are run, using these same
  // times (DESIGN.md §4.3).
  //
  // The 3rd shift closes the day at 23:40–05:45. The source specification
  // listed 2nd and 3rd shift with identical times (both 14:26–23:40), which
  // cannot be right; rather than seed a duplicate window that would count the
  // afternoon's capacity twice, the seed completes the 24-hour cycle. Edit it
  // to whatever the plant actually runs.
  ShiftPatternSeed(
    name: 'ABC',
    cycleType: ShiftCycleType.fixedWeekly,
    workingWeekdays: _mondayToFriday,
    shifts: [
      ShiftSeed('A', 5 * 60 + 45, 15 * 60 + 13, breakSeconds: _minutes40),
      ShiftSeed('B', 14 * 60 + 26, 23 * 60 + 40, breakSeconds: _minutes40),
      ShiftSeed('C', 23 * 60 + 40, 5 * 60 + 45, breakSeconds: _minutes40),
    ],
  ),

  // 24/7 continuous operation. Four crews (A/B/C/D) rotate through TWO windows,
  // so the pattern holds two shifts, not four: capacity comes from the windows
  // covered, and four entries would count each day twice. Which crew is on
  // which day changes nothing a deterministic model can see.
  ShiftPatternSeed(
    name: 'ABCD',
    cycleType: ShiftCycleType.rotating,
    workingWeekdays: _everyDay,
    notes: 'Four crews (A/B/C/D) rotating through two 12-hour windows.',
    shifts: [
      ShiftSeed('Day (A/C)', 7 * 60, 19 * 60),
      ShiftSeed('Night (B/D)', 19 * 60, 7 * 60),
    ],
  ),
];
