import 'package:drift/drift.dart';

import 'enums.dart';

// All ids are string uuids: stable across the `.flowmap` export/import bundle,
// which is how a project or template reaches another machine (DESIGN.md §2).
//
// Durations are stored as integer SECONDS and times of day as integer MINUTES
// from midnight — never as DateTime. A shift boundary at 15:13 is a clock
// reading, not an instant, and storing it as one would drag time zones and DST
// into arithmetic that is purely local (DESIGN.md §12.4).
//
// Deletion is soft: `archivedAt` non-null hides a row from pickers while
// leaving projects that already reference it intact (DESIGN.md §3).

// --- Shift patterns -------------------------------------------------------

/// How a plant divides its day. A project picks one pattern for its plant, and
/// every workcenter in that plant is staffed against the same shifts
/// (DESIGN.md §4.1).
///
/// `ABC` and `ABCD` are seeded and fully editable — shift times change more
/// often than plants do.
class ShiftPatterns extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get cycleType => textEnum<ShiftCycleType>()();

  /// Bitmask of base working weekdays, Monday = bit 0 … Sunday = bit 6, using
  /// `DateTime.monday`-based indexing.
  ///
  /// A bitmask rather than a child table: it is a fixed seven-value set that is
  /// always read whole, and a join to answer "is Tuesday a working day" would
  /// be on the hot path of every calendar walk.
  IntColumn get workingWeekdays => integer()();

  TextColumn get notes => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {name},
  ];
}

/// One shift window within a [ShiftPatterns] row.
///
/// For a rotating pattern these are windows, not crews — see
/// [ShiftCycleType.rotating].
class PatternShifts extends Table {
  TextColumn get id => text()();
  TextColumn get patternId =>
      text().references(ShiftPatterns, #id, onDelete: KeyAction.cascade)();

  /// What the shop floor calls it: `A`, `1st`, `Night`.
  TextColumn get label => text().withLength(min: 1, max: 40)();

  /// Order within the day, from the pattern's own start. Also the index into a
  /// workcenter's operators-per-shift list (DESIGN.md §4.2), which is why it is
  /// stored rather than derived from [startMinute]: a night shift starting at
  /// 23:40 sorts first by clock time but is last in the day.
  IntColumn get position => integer()();

  /// Minutes from midnight, 0–1439.
  IntColumn get startMinute => integer()();
  IntColumn get endMinute => integer()();

  /// Unpaid break inside the window, in seconds. Subtracted from the shift's
  /// gross duration to give productive time; not placed at a specific clock
  /// time, because no input in this app is precise enough to make that
  /// placement mean anything.
  IntColumn get breakSeconds => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {patternId, label},
    {patternId, position},
  ];
}

// --- The plant hierarchy --------------------------------------------------

/// Top of the resource tree. A project specifies exactly one plant, and a
/// workcenter belongs to exactly one plant (DESIGN.md §3).
class Plants extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get code => text().withLength(max: 40).nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {name},
  ];
}

class ProductionCells extends Table {
  TextColumn get id => text()();
  TextColumn get plantId =>
      text().references(Plants, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {plantId, name},
  ];
}

class ProductionLines extends Table {
  TextColumn get id => text()();
  TextColumn get cellId =>
      text().references(ProductionCells, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {cellId, name},
  ];
}

/// Editable picklist: Machining, Cladding, Welding, … Seeded, and the user adds
/// their own. Referenced rather than snapshotted onto the workcenter, because a
/// type is an identity attribute and renames must propagate (DESIGN.md §3).
class WorkcenterTypes extends Table {
  TextColumn get id => text()();

  /// Which of the icon library's glyphs a workcenter of this type is drawn
  /// with, stored as a [WorkcenterIcon] name.
  ///
  /// **A name, not a codepoint.** Flutter's icon tree-shaking drops every glyph
  /// the compiler cannot see referenced, so an `IconData` built from a stored
  /// number is a blank box in release and correct in debug. The enum resolves
  /// through an exhaustive switch, which the compiler does see.
  TextColumn get icon => textEnum<WorkcenterIcon>().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {name},
  ];
}

/// A machine or station. Belongs to exactly one plant, per the spec.
///
/// **Which lines it is drawn under is a separate table** — [WorkcenterLines].
/// The resource hierarchy is Plant → Cell → Line → Workcenter, but studies on
/// different production lines are explicitly allowed to use the same
/// workcenter, and cross-line contention at a shared workcenter is the point of
/// a combined simulation run (DESIGN.md §7.7). Making the line a hard parent
/// would forbid exactly the case the app exists to analyse, so the plant is the
/// owner and the tree is a filing arrangement.
class Workcenters extends Table {
  TextColumn get id => text()();
  TextColumn get plantId =>
      text().references(Plants, #id, onDelete: KeyAction.cascade)();
  TextColumn get typeId => text().nullable().references(
    WorkcenterTypes,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// What the shop floor calls it, and what the VSM process box is labelled —
  /// `CLAD04`, `BAN11`.
  ///
  /// _Rejected: a separate `code` alongside this._ It shipped in v1 and every
  /// user filled both fields with the same value, then had to read two
  /// identical columns in every picker. One name is what a workcenter has.
  TextColumn get name => text().withLength(min: 1, max: 200)();

  /// How many orders it can run at once (DESIGN.md §3.1, §8.3).
  ///
  /// One is a single machine, which is what every workcenter was before this
  /// column. Above one the engine gives the station that many servers, and it
  /// genuinely runs that many orders side by side, each with its own process
  /// time — which is what distinguishes this from a batch process, where one
  /// window holds several orders and the time does not double. The observed
  /// data is what decided it: TTAT's process times scale with batch size, and
  /// an oven curing a load would not.
  ///
  /// **It means the same thing everywhere.** §8.4's occupation, §8.3's
  /// utilization denominator and §6.1's flow equivalent all divide by a
  /// station's available time, so all three take this — otherwise a two-unit
  /// station reads 200 % loaded on the Summary while the run reports it
  /// comfortable.
  ///
  /// _Rejected: a pool of two invented members._ It needs no code at all, and
  /// it puts two machines that do not exist into the plant, the Summary, the
  /// Queue table and every Gantt from then on.
  IntColumn get parallelCapacity =>
      integer().withDefault(const Constant(1))();

  TextColumn get notes => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {plantId, name},
  ];
}

/// Which production lines a workcenter is drawn under (DESIGN.md §3).
///
/// **A set, not a parent.** `CLAD04` genuinely serves two lines in a real
/// plant, and the single `home_line_id` this replaces meant filing it under the
/// second one silently took it out of the first — the tree fought the very
/// arrangement the app exists to analyse.
///
/// It is **organisational only**. Membership constrains nothing: any study of
/// any line may target any workcenter of the plant, with or without a row here.
/// The two things it affects are where the workcenter appears in the Resources
/// tree, and which line-scoped calendar exceptions reach it (§4.3).
class WorkcenterLines extends Table {
  TextColumn get workcenterId =>
      text().references(Workcenters, #id, onDelete: KeyAction.cascade)();
  TextColumn get lineId =>
      text().references(ProductionLines, #id, onDelete: KeyAction.cascade)();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {workcenterId, lineId};
}

/// A named group of interchangeable workcenters (DESIGN.md §3.1). A flow step
/// targets either one workcenter or one pool; an order sent to a pool runs on
/// whichever member frees first.
class WorkcenterPools extends Table {
  TextColumn get id => text()();
  TextColumn get plantId =>
      text().references(Plants, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {plantId, name},
  ];
}

/// Pool membership. A workcenter may belong to several pools (DESIGN.md §18.2),
/// so this is a plain many-to-many with no uniqueness beyond the pair.
class WorkcenterPoolMembers extends Table {
  TextColumn get poolId =>
      text().references(WorkcenterPools, #id, onDelete: KeyAction.cascade)();
  TextColumn get workcenterId =>
      text().references(Workcenters, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {poolId, workcenterId};
}

// --- Settings -------------------------------------------------------------

/// Key/value app settings, including the `seededAt` stamps that keep reference
/// data from being re-seeded over a deliberate deletion (DATA.md).
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
