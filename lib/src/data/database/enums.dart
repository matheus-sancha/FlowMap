/// How a shift pattern repeats (DESIGN.md §4.1).
enum ShiftCycleType {
  /// Fixed times on the pattern's base working weekdays; other days are
  /// non-working unless a calendar exception opens them (the `ABC` case, where
  /// Saturday is extra hours running the same shift times).
  fixedWeekly,

  /// Continuous coverage: every calendar day is a working day.
  ///
  /// The shifts of a rotating pattern are **time windows, not crews**. `ABCD`
  /// describes four crews rotating through two 12-hour windows, and capacity
  /// comes from the windows — storing four shifts would count each day's
  /// capacity twice. Which crew is on which day changes nothing the
  /// deterministic model can see (DESIGN.md §4.4), so it is not modelled.
  rotating,
}

/// Which glyph a workcenter type is drawn with (DESIGN.md §12.1).
///
/// **Stored as a name, never as a codepoint.** Flutter's icon tree-shaking
/// removes every glyph the compiler cannot see referenced, so an `IconData`
/// built from a stored number renders as a blank box in a release build and
/// looks perfect in debug. `workcenterIconGlyph` resolves this through an
/// exhaustive switch of constants, which the compiler does see.
enum WorkcenterIcon {
  machining,
  lathe,
  milling,
  drilling,
  grinding,
  cutting,
  bending,
  press,
  welding,
  cladding,
  heatTreatment,
  coating,
  painting,
  cleaning,
  assembly,
  robot,
  conveyor,
  inspection,
  testing,
  measuring,
  packing,
  storage,
}

/// What a calendar exception does to a day (DESIGN.md §4.3).
enum CalendarExceptionKind {
  /// Holiday or shutdown: the day is closed.
  nonWorking,

  /// Extra hours: the day is opened, with its own staffing.
  extraWorking,
}

/// Which resources an exception reaches. Most specific wins, so a plant-wide
/// shutdown can be overridden by opening one workcenter that Saturday.
enum CalendarExceptionScope { plant, productionLine, workcenter }

/// How a takt is entered and read back.
///
/// **`days` here means working days of a workcenter**, not 24 hours — a takt is
/// resolved against each station's own capacity (DESIGN.md §6.1). That is why
/// this is a separate type from [DurationUnit], where a day is a day.
enum TaktUnit { days, hours, minutes, seconds }

/// How a plain duration is entered and read back — a cooling time, a transport
/// wait.
///
/// **`days` here is 24 hours.** Whether that duration is consumed on the wall
/// clock or only while the plant runs is a separate question, answered by the
/// inventory node's own working-time flag (DESIGN.md §5.5).
enum DurationUnit { days, hours, minutes, seconds }

/// How a workcenter chooses which waiting order to run next (DESIGN.md §7.4).
///
/// **Here rather than beside the engine that reads it**, because a station may
/// now override the run's rule and that override is stored (§7.4). `sim_model`
/// re-exports it, so the engine still names it without importing the schema —
/// but the enum itself has to live somewhere a table definition can reach, and
/// `sim_model` reaches the calendar, which the schema must not.
enum DispatchRule {
  /// By arrival at the step. The default, and what a shop floor does.
  fifo,

  /// Earliest need date first — "what if we dispatched by due date" is exactly
  /// the experiment this app exists to run.
  earliestDueDate,

  /// Shortest processing time first.
  shortestProcessing;

  /// Every rule falls back to the same three keys, so a run of the same inputs
  /// always produces the same output (§4.4): arrival, then the study's
  /// priority, then its position in the sequence.
  bool get isDefault => this == DispatchRule.fifo;
}

/// What a node on the flow spine is (DESIGN.md §5.1).
enum FlowNodeKind {
  /// A process step, targeting one workcenter or one pool.
  step,

  /// A buffer between steps.
  inventory,
}

/// How an inventory node states its wait (DESIGN.md §5.5).
enum InventoryMode {
  /// N pieces, shown as days through the takt of the period being viewed.
  quantity,

  /// A fixed wait — cooling, transport, curing.
  duration,
}

/// The decorative VSM symbols (DESIGN.md §5.2). None of these affect a number;
/// they document intent on the map.
enum AnnotationSymbol {
  shipmentTruck,
  supermarket,
  kanbanPost,
  withdrawalKanban,
  productionControl,
  informationArrow,
  kaizenBurst,
  operator,
  note,
}
