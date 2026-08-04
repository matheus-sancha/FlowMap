// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'FlowMap';

  @override
  String get navProjects => 'Proyectos';

  @override
  String get navTemplates => 'Plantillas de estudio';

  @override
  String get navResources => 'Recursos';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get navAbout => 'Acerca de';

  @override
  String get actionAdd => 'Añadir';

  @override
  String get actionEdit => 'Editar';

  @override
  String get actionDelete => 'Eliminar';

  @override
  String get actionArchive => 'Archivar';

  @override
  String get actionRestore => 'Restaurar';

  @override
  String get actionSave => 'Guardar';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionClose => 'Cerrar';

  @override
  String get actionDuplicate => 'Duplicar';

  @override
  String get actionRename => 'Renombrar';

  @override
  String get fieldName => 'Nombre';

  @override
  String get fieldCode => 'Código';

  @override
  String get fieldType => 'Tipo';

  @override
  String get fieldNotes => 'Notas';

  @override
  String get fieldStart => 'Inicio';

  @override
  String get fieldEnd => 'Fin';

  @override
  String get validationRequired => 'Obligatorio';

  @override
  String get validationNameTaken => 'Ese nombre ya está en uso aquí';

  @override
  String get resourcesTitle => 'Recursos';

  @override
  String get resourcesEmpty =>
      'Aún no hay planta. Crea una para empezar a construir estudios.';

  @override
  String get resourcesShowArchived => 'Mostrar archivados';

  @override
  String get resourcesArchivedBadge => 'Archivado';

  @override
  String get plant => 'Planta';

  @override
  String get plantNew => 'Nueva planta';

  @override
  String get plantDeleteBlocked =>
      'Esta planta tiene células de producción. Archívala en su lugar.';

  @override
  String get productionCell => 'Célula de producción';

  @override
  String get productionCells => 'Células de producción';

  @override
  String get productionCellNew => 'Nueva célula de producción';

  @override
  String get productionLine => 'Línea de producción';

  @override
  String get productionLines => 'Líneas de producción';

  @override
  String get productionLineNew => 'Nueva línea de producción';

  @override
  String get workcenter => 'Centro de trabajo';

  @override
  String get workcenters => 'Centros de trabajo';

  @override
  String get workcenterNew => 'Nuevo centro de trabajo';

  @override
  String get workcenterType => 'Tipo de centro de trabajo';

  @override
  String get workcenterTypes => 'Tipos de centro de trabajo';

  @override
  String get workcenterTypeNew => 'Nuevo tipo de centro de trabajo';

  @override
  String get workcenterPool => 'Pool de centros de trabajo';

  @override
  String get workcenterPools => 'Pools de centros de trabajo';

  @override
  String get workcenterPoolNew => 'Nuevo pool';

  @override
  String get workcenterPoolMembers => 'Miembros';

  @override
  String get workcenterPoolEmpty =>
      'Un pool necesita al menos un centro de trabajo.';

  @override
  String get shiftPattern => 'Patrón de turnos';

  @override
  String get shiftPatterns => 'Patrones de turnos';

  @override
  String get shiftPatternNew => 'Nuevo patrón de turnos';

  @override
  String get shiftPatternCycle => 'Ciclo';

  @override
  String get shiftPatternCycleFixedWeekly => 'Semanal fijo';

  @override
  String get shiftPatternCycleRotating => 'Rotativo (continuo)';

  @override
  String get shiftPatternWorkingDays => 'Días laborables base';

  @override
  String get shiftPatternShifts => 'Turnos';

  @override
  String get shiftPatternShiftNew => 'Añadir turno';

  @override
  String get shiftPatternNoShifts => 'Un patrón necesita al menos un turno.';

  @override
  String get shiftLabel => 'Etiqueta';

  @override
  String get shiftStart => 'Inicio';

  @override
  String get shiftEnd => 'Fin';

  @override
  String get shiftBreak => 'Descanso';

  @override
  String get shiftCrossesMidnight => 'Cruza medianoche';

  @override
  String get shiftDuration => 'Duración neta';

  @override
  String shiftOverlapWarning(String other) {
    return 'Este turno se solapa con $other.';
  }

  @override
  String get weekdayMon => 'Lun';

  @override
  String get weekdayTue => 'Mar';

  @override
  String get weekdayWed => 'Mié';

  @override
  String get weekdayThu => 'Jue';

  @override
  String get weekdayFri => 'Vie';

  @override
  String get weekdaySat => 'Sáb';

  @override
  String get weekdaySun => 'Dom';

  @override
  String confirmDeleteTitle(String name) {
    return '¿Eliminar $name?';
  }

  @override
  String get confirmDeleteBody => 'Esto no se puede deshacer.';

  @override
  String get confirmArchiveBody =>
      'Sigue disponible para los proyectos que ya lo usan, pero queda oculto en los selectores.';

  @override
  String aboutVersion(String version) {
    return 'Versión $version';
  }

  @override
  String aboutBuild(String build) {
    return 'Compilación $build';
  }

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageSystem => 'Sistema';

  @override
  String get settingsDateFormat => 'Formato de fecha';

  @override
  String get settingsDateFormatLocale => 'Seguir el idioma';

  @override
  String get comingSoon => 'Próximamente';

  @override
  String get valueNone => 'Ninguno';

  @override
  String get workcenterNameHelp =>
      'Como lo llama la planta, y la etiqueta de la caja de proceso — por ejemplo CLAD04.';

  @override
  String get workcenterAddExisting => 'Añadir existente';

  @override
  String get workcenterAddExistingHelp =>
      'Un centro de trabajo pertenece a la planta, así que esto solo cambia dónde aparece en el árbol. Cualquier estudio de cualquier línea puede usarlo igualmente.';

  @override
  String get workcenterNoneToAdd =>
      'Todos los centros de trabajo de esta planta ya están en esta línea.';

  @override
  String get workcenterHomeLine => 'Línea de producción principal';

  @override
  String get workcenterHomeLineHelp =>
      'Dónde aparece en el árbol. Los estudios de otras líneas pueden usarlo igualmente, y ese uso compartido es lo que la simulación disputa.';

  @override
  String get workcenterTypeUnset => 'Sin tipo';

  @override
  String get workcenterTypeDeleteBody =>
      'Los centros de trabajo que usan este tipo siguen funcionando; su tipo queda vacío.';

  @override
  String get workcenterPoolNoCandidates =>
      'Esta planta aún no tiene centros de trabajo.';

  @override
  String get resourcesUnassigned => 'Fuera de línea';

  @override
  String get resourcesUnassignedHelp =>
      'Centros de trabajo que pertenecen a la planta pero no están bajo una línea de producción.';

  @override
  String get shiftPatternRotatingHelp =>
      'Opera todos los días. Los turnos son ventanas horarias, no cuadrillas — cuatro cuadrillas rotando en dos ventanas de 12 horas son dos turnos aquí, porque la capacidad viene de las ventanas cubiertas.';

  @override
  String get shiftPatternEveryDay => 'Todos los días';

  @override
  String get shiftPatternNoWorkingDays => 'Sin días laborables';

  @override
  String shiftPatternOpenPerDay(String duration) {
    return 'Abierto $duration/día';
  }

  @override
  String get shiftBreakMinutes => 'Descanso (min)';

  @override
  String shiftBreakOf(String duration) {
    return 'Descanso $duration';
  }

  @override
  String get projectNew => 'Nuevo proyecto';

  @override
  String get projectsEmpty => 'Aún no hay proyectos.';

  @override
  String get projectMissing => 'Ese proyecto ya no existe.';

  @override
  String get projectNeedsPlant =>
      'Crea una planta en Recursos antes de iniciar un proyecto.';

  @override
  String get projectPlantHelp =>
      'No se puede cambiar después: cada estudio, programación y paso de flujo del proyecto apunta a los centros de trabajo de esta planta.';

  @override
  String get projectPatternHelp =>
      'La división de turnos con la que se dota a cada centro de trabajo de este proyecto.';

  @override
  String get projectDeleteBody =>
      'Sus estudios, programaciones y flujos se van con él. Esto no se puede deshacer.';

  @override
  String get studyNew => 'Nuevo estudio';

  @override
  String get studiesEmpty => 'Aún no hay estudios en este proyecto.';

  @override
  String get studyNameHint => 'Situación actual';

  @override
  String get studyNeedsLine => 'Esta planta aún no tiene líneas de producción.';

  @override
  String get studyLineHelp =>
      'Un estudio pertenece a una línea. Varios estudios de la misma línea son escenarios; solo uno puede seleccionarse para la simulación.';

  @override
  String get studyDeleteBody =>
      'Su flujo y sus anotaciones se van con él. Esto no se puede deshacer.';

  @override
  String get studyIncludeInSimulation => 'Incluir en la simulación';

  @override
  String get studyExcludeFromSimulation => 'Excluir de la simulación';

  @override
  String get studyTabFlow => 'Flujo';

  @override
  String get studyTabTakt => 'Takt';

  @override
  String get studyTabDemand => 'Demanda';

  @override
  String get studyTabSummary => 'Resumen';

  @override
  String get milestoneSummary => 'El resumen llega en el próximo hito.';

  @override
  String get actionMoveUp => 'Subir';

  @override
  String get actionMoveDown => 'Bajar';

  @override
  String get validationNotADuration => 'No es un tiempo';

  @override
  String get validationNotADate => 'No es una fecha';

  @override
  String get validationPositiveWhole => 'Un número entero mayor que cero';

  @override
  String get validationUnknownPart =>
      'No hay ninguna pieza con ese número en este estudio';

  @override
  String get demandParts => 'Piezas';

  @override
  String get demandSequence => 'Secuencia';

  @override
  String get demandPartNumber => 'Número de pieza';

  @override
  String get demandDescription => 'Descripción';

  @override
  String get demandTotal => 'Total';

  @override
  String get demandOrderNumber => 'Pedido';

  @override
  String get demandBatchSize => 'Lote';

  @override
  String get demandNeedDate => 'Fecha requerida';

  @override
  String get demandMaterialDate => 'Fecha de material';

  @override
  String get demandMaterialDateHelp => 'opcional';

  @override
  String get demandUnbound => 'sin asignar';

  @override
  String get demandTimesHelp =>
      'Por pieza. Escriba 30:00:00, 1.5h, 90min o 2d; un número sin unidad se lee como horas. Deje la celda vacía si la pieza no pasa por ese paso. Pegue un bloque de Excel con Ctrl+V.';

  @override
  String get demandSequenceHelp =>
      'El orden en que la planta va a fabricar. Nada lo reordena salvo usted. Pegue un bloque de Excel con Ctrl+V.';

  @override
  String get demandNoSteps =>
      'Este flujo aún no tiene pasos de proceso, así que no hay contra qué costear una pieza.';

  @override
  String get demandNeedsPart => 'Agregue una pieza antes de agregar pedidos.';

  @override
  String get demandPartDeleteBody =>
      'Sus tiempos de proceso se van con ella, y todos sus pedidos salen de la secuencia.';

  @override
  String get takt => 'Takt';

  @override
  String get taktUnit => 'Unidad';

  @override
  String get taktEmpty =>
      'Aún no hay takt definido para esta línea de producción.';

  @override
  String get taktPeriodNew => 'Nuevo periodo de takt';

  @override
  String get taktPeriodDeleteTitle => '¿Eliminar este periodo de takt?';

  @override
  String get taktDaysHelp =>
      'Los días son relativos a la capacidad de cada centro de trabajo: un takt de 3 días son 68 h en una estación abierta 22:40 al día y 26:24 en una abierta 8:48.';

  @override
  String get taktLiteralHelp =>
      'Resulta en la misma duración en todos los centros de trabajo.';

  @override
  String get unitDays => 'días';

  @override
  String get unitHours => 'horas';

  @override
  String get unitMinutes => 'minutos';

  @override
  String get unitSeconds => 'segundos';

  @override
  String get unitDaysShort => 'd';

  @override
  String get unitHoursShort => 'h';

  @override
  String get unitMinutesShort => 'min';

  @override
  String get unitSecondsShort => 's';

  @override
  String get schedulePeriodNew => 'Nuevo periodo';

  @override
  String get schedulePeriodDeleteTitle =>
      '¿Eliminar este periodo de programación?';

  @override
  String get scheduleShifts => 'Turnos';

  @override
  String get scheduleOperatorsPerShift => 'Operarios por turno';

  @override
  String scheduleShiftsDerived(String count, String operators) {
    return 'Turnos: $count ($operators) — contados de los turnos con operarios, nunca almacenados aparte.';
  }

  @override
  String get availability => 'Disponibilidad';

  @override
  String get availabilityHelp =>
      'Fracción del tiempo abierto en que el centro de trabajo puede operar. Se aplica una sola vez, al tiempo de proceso.';

  @override
  String get availabilityInvalid => 'Debe ser mayor que 0% y como máximo 100%';

  @override
  String get rework => 'Retrabajo';

  @override
  String get reworkHelp =>
      'Fracción del trabajo que hay que rehacer. Aumenta el tiempo de proceso.';

  @override
  String get reworkInvalid => 'Debe ser 0% o más';

  @override
  String get occupation => 'Ocupación';

  @override
  String get workcentersTabEmpty =>
      'Añade pasos al flujo para programar aquí sus centros de trabajo.';

  @override
  String workcentersTabPattern(String shifts) {
    return 'Patrón de turnos: $shifts';
  }

  @override
  String get scheduleIssueEmpty =>
      'No hay periodos definidos. Nada aquí puede calcularse hasta que haya al menos uno.';

  @override
  String scheduleIssueOverlap(String from, String to) {
    return 'Dos periodos cubren $from hasta $to.';
  }

  @override
  String scheduleIssueGap(String from, String to) {
    return 'Ningún periodo cubre $from hasta $to.';
  }

  @override
  String scheduleIssueInverted(String from, String to) {
    return 'Un periodo termina ($to) antes de empezar ($from).';
  }

  @override
  String get periodPrevious => 'Periodo anterior';

  @override
  String get periodNext => 'Periodo siguiente';

  @override
  String get periodMonth => 'Mes';

  @override
  String get periodQuarterly => 'Trimestre';

  @override
  String get periodSemesterly => 'Semestre';

  @override
  String get periodYearly => 'Año';

  @override
  String periodQuarter(String quarter, String year) {
    return 'T$quarter $year';
  }

  @override
  String periodSemester(String half, String year) {
    return 'S$half $year';
  }

  @override
  String get periodVariesHelp =>
      'El takt o la dotación cambian dentro de este periodo. El mapa muestra el estado de su primer día.';

  @override
  String get footerTaktHelp =>
      'El ritmo de la línea de producción en este periodo — una unidad sale de la línea cada takt.';

  @override
  String get footerProcessTimeHelp =>
      'La suma del tiempo de proceso de todos los pasos. Solo tiempo que añade valor; la espera no cuenta.';

  @override
  String get footerLeadTimeHelp =>
      'Tiempo de proceso más todas las esperas entre pasos — lo que tarda una orden en cruzar el flujo.';

  @override
  String get footerPceHelp =>
      'Eficiencia del ciclo de proceso: tiempo de proceso ÷ lead time. La parte del tiempo transcurrido que añade valor.';

  @override
  String get flowDataSource => 'Línea de tiempo';

  @override
  String get flowSourceEquivalent => 'Equivalente del flujo';

  @override
  String get flowSourceSinglePart => 'Una pieza (requiere demanda)';

  @override
  String get flowSourceWeighted =>
      'Todas las variantes, ponderadas (requiere demanda)';

  @override
  String get exportPdf => 'Exportar PDF';

  @override
  String get flowSupplier => 'Proveedor';

  @override
  String get flowCustomer => 'Cliente';

  @override
  String get flowFitToScreen => 'Ajustar a la pantalla';

  @override
  String get flowZoomIn => 'Acercar';

  @override
  String get flowZoomOut => 'Alejar';

  @override
  String get flowInsertHere => 'Insertar aquí';

  @override
  String get flowInsertStep => 'Paso de proceso';

  @override
  String get flowInsertStepHelp =>
      'Se ejecuta en un centro de trabajo o un pool.';

  @override
  String get flowInsertInventory => 'Inventario';

  @override
  String get flowInsertInventoryHelp =>
      'Donde las órdenes esperan entre pasos.';

  @override
  String get flowStep => 'Paso de proceso';

  @override
  String get flowInventory => 'Inventario';

  @override
  String get flowStepTarget => 'Centro de trabajo o pool';

  @override
  String get flowStepTargetHelp =>
      'Un paso se ejecuta exactamente en uno. Un pool envía cada orden al miembro que se libere primero.';

  @override
  String get flowNodeLabel => 'Etiqueta';

  @override
  String get flowNodeLabelHelp =>
      'Se muestra en lugar del código del centro de trabajo.';

  @override
  String get flowMoveLeft => 'Mover antes';

  @override
  String get flowMoveRight => 'Mover después';

  @override
  String get flowDeleteNodeTitle => '¿Quitar este nodo del flujo?';

  @override
  String get stepProcessTime => 'Tiempo de proceso';

  @override
  String get stepChangeover => 'Cambio de formato';

  @override
  String get stepChangeoverHelp =>
      'Se cobra solo cuando la orden anterior en este centro de trabajo era de otra pieza.';

  @override
  String get stepOperators => 'Operarios';

  @override
  String get stepEquivalentTime => 'Takt time específico del proceso';

  @override
  String get stepEquivalentFollowsTakt => 'Sigue el takt';

  @override
  String get stepEquivalentHelp =>
      'El takt propio de este paso, usado por el equivalente del flujo en lugar del de la línea. Déjalo vacío para seguir el takt de la línea. Rellénalo cuando un takt completo desequilibraría la comparación — una inspección que vale solo una fracción. Los días son días productivos de esta estación, así que 1 día equivale a un día de takt.';

  @override
  String get stepProblemUnbound =>
      'No se ha seleccionado centro de trabajo ni pool.';

  @override
  String get stepProblemArchived =>
      'Su centro de trabajo ha sido archivado o eliminado.';

  @override
  String get stepProblemNoSchedule =>
      'Ningún periodo de programación cubre este mes.';

  @override
  String get stepProblemEmptyPool => 'Este pool no tiene miembros.';

  @override
  String stepPoolMembers(String count) {
    return 'Pool · $count centros de trabajo';
  }

  @override
  String get inventoryModeQuantity => 'Piezas';

  @override
  String get inventoryModeDuration => 'Espera fija';

  @override
  String get inventoryPieces => 'Piezas en espera';

  @override
  String get inventoryPiecesHelp =>
      'Contadas como días de stock: piezas × takt del periodo mostrado.';

  @override
  String get inventoryWait => 'Espera';

  @override
  String get inventoryWaitHelp =>
      'Aquí un día son 24 horas. Si esas horas pasan en el reloj o solo mientras la planta opera lo decide el interruptor de abajo.';

  @override
  String get inventoryWorkingTime => 'Solo tiempo laborable';

  @override
  String get inventoryWorkingTimeHelp =>
      'Desactivado para enfriamiento o transporte, que no paran el fin de semana. Activado para una cola que solo avanza mientras la planta opera.';

  @override
  String get footerProcessTime => 'Tiempo de proceso';

  @override
  String get footerLeadTime => 'Lead time';

  @override
  String get footerPce => 'PCE';

  @override
  String get footerEndDate => 'Fecha de fin';

  @override
  String footerRunningDays(String days, String date) {
    return '$days días corridos · $date';
  }

  @override
  String get footerEndDateHelp =>
      'Cuándo terminaría una orden iniciada el primer día de este periodo, recorriendo los calendarios reales. La diferencia con el lead time son los fines de semana y los paros.';

  @override
  String pdfGenerated(String build, String timestamp) {
    return 'FlowMap $build · generado $timestamp';
  }

  @override
  String pdfSaved(String path) {
    return 'Guardado en $path';
  }
}
