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
  String get studyTabCapacity => 'Capacidad';

  @override
  String get exceptionsScope =>
      'Se aplica a todo el proyecto — a todos sus estudios.';

  @override
  String get projectSettings => 'Ajustes del proyecto';

  @override
  String get projectSettingsIdentity => 'Identidad';

  @override
  String get projectPatternHelp =>
      'El patrón de turnos del que cada centro de trabajo de este proyecto lee sus horas abiertas. Cambiarlo recalcula el horario de todas las estaciones, y toda cifra derivada de ellas.';

  @override
  String get calendarExceptions => 'Excepciones';

  @override
  String get schedulesTaktScope =>
      'compartido por todos los estudios de esta línea';

  @override
  String get schedulesStationsScope => 'el flujo de este estudio';

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
  String get workcenterLines => 'Se muestra bajo estas líneas';

  @override
  String get workcenterLinesHelp =>
      'Solo organizativo. Cualquier estudio de cualquier línea puede usar este centro de trabajo marque lo que marque, y una estación que sirve a dos líneas va bajo las dos.';

  @override
  String get workcenterNoLines =>
      'Esta planta aún no tiene líneas de producción.';

  @override
  String workcenterOnLines(String count) {
    return 'en $count líneas';
  }

  @override
  String workcenterRemoveFromLine(String line) {
    return 'Quitar de $line';
  }

  @override
  String get workcenterDeleteBody =>
      'Esto elimina el centro de trabajo de la planta, no solo de esta línea. Sus horarios se van con él.';

  @override
  String get workcenterTypeIcon => 'Icono';

  @override
  String get workcenterTypeNone => 'Sin icono';

  @override
  String get workcenterTypeEdit => 'Tipo de centro de trabajo';

  @override
  String get iconMachining => 'Mecanizado';

  @override
  String get iconLathe => 'Torno';

  @override
  String get iconMilling => 'Fresado';

  @override
  String get iconDrilling => 'Taladrado';

  @override
  String get iconGrinding => 'Rectificado';

  @override
  String get iconCutting => 'Corte';

  @override
  String get iconBending => 'Plegado';

  @override
  String get iconPress => 'Prensa';

  @override
  String get iconWelding => 'Soldadura';

  @override
  String get iconCladding => 'Recubrimiento';

  @override
  String get iconHeatTreatment => 'Tratamiento térmico';

  @override
  String get iconCoating => 'Capa';

  @override
  String get iconPainting => 'Pintura';

  @override
  String get iconCleaning => 'Limpieza';

  @override
  String get iconAssembly => 'Montaje';

  @override
  String get iconRobot => 'Robot';

  @override
  String get iconConveyor => 'Transportador';

  @override
  String get iconInspection => 'Inspección';

  @override
  String get iconTesting => 'Ensayo';

  @override
  String get iconMeasuring => 'Medición';

  @override
  String get iconPacking => 'Embalaje';

  @override
  String get iconStorage => 'Almacén';

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
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageSystem => 'Seguir el sistema';

  @override
  String get settingsDateFormat => 'Formato de fecha';

  @override
  String get comingSoon => 'Próximamente';

  @override
  String get valueNone => 'Ninguno';

  @override
  String get workcenterAddExisting => 'Añadir existente';

  @override
  String get workcenterNoneToAdd =>
      'Todos los centros de trabajo de esta planta ya están en esta línea.';

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
  String get projectDeleteBody =>
      'Sus estudios, programaciones y flujos se van con él. Esto no se puede deshacer.';

  @override
  String get study => 'Estudio';

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
  String get studiesCollapse => 'Ocultar la lista de estudios';

  @override
  String get studiesExpand => 'Mostrar la lista de estudios';

  @override
  String get studyTabSettings => 'Ajustes del estudio';

  @override
  String get studyTabTakt => 'Takt del flujo';

  @override
  String get studySettingsIdentity => 'Identidad';

  @override
  String get studySettingsInRuns => 'Ajustes de simulación';

  @override
  String get studyName => 'Nombre';

  @override
  String get studyLine => 'Línea de producción';

  @override
  String get studyIncludeInRuns => 'Incluir en la simulación';

  @override
  String get studyIncludeInRunsHelp =>
      'Una corrida toma todos los estudios incluidos a la vez, compitiendo por la misma planta.';

  @override
  String get studyWipCap => 'Límite de WIP';

  @override
  String get studyWipCapUnlimited => 'Sin límite';

  @override
  String get studyWipCapHelp =>
      'El máximo de pedidos que este estudio puede tener en el flujo a la vez. Una liberación espera a que algo termine, que es lo que hace que el flujo se jale en vez de empujarse. En blanco es sin límite.';

  @override
  String get studyTabFlow => 'Flujo';

  @override
  String get studyTabDemand => 'Demanda';

  @override
  String get studyTabSummary => 'Resumen';

  @override
  String get actionMoveUp => 'Subir';

  @override
  String get actionMoveDown => 'Bajar';

  @override
  String get validationNotADuration => 'No es un tiempo';

  @override
  String get validationNotADate => 'No es una fecha';

  @override
  String get validationPositiveNumber => 'Un número mayor que cero';

  @override
  String get validationUnknownUnit =>
      'No es una unidad — prueba días, horas, min o s';

  @override
  String get validationNotAPercentage => 'Un porcentaje entre 0 y 100';

  @override
  String get validationPositiveWhole => 'Un número entero mayor que cero';

  @override
  String get validationUnknownPart =>
      'No hay ninguna pieza con ese número en este estudio';

  @override
  String get stepProblemNoProcessTime =>
      'Esta pieza no tiene tiempo de proceso aquí.';

  @override
  String get stepEquivalence => 'Equivalente';

  @override
  String get footerEquivalence => 'Equivalente';

  @override
  String get footerEquivalenceHelp =>
      'El tiempo de proceso de esta pieza en todo el flujo dividido por el del equivalente de flujo. 1,13 significa que consume 1,13 takts de la capacidad de la línea.';

  @override
  String get flowSourceNeedsDemand =>
      'Necesita al menos una pieza en la pestaña Demanda';

  @override
  String get mm3 => 'MM3';

  @override
  String get mm3Column => 'MM3';

  @override
  String get mm3Scope => 'Medido sobre';

  @override
  String get mm3WholeFlow => 'Todo el flujo';

  @override
  String get mm3Smoothness => 'Desviación media';

  @override
  String get mm3SmoothnessHelp =>
      'Qué tan lejos de 1,0 queda la media móvil en promedio. 1,0 es un takt de la capacidad del alcance por pedido, es decir una secuencia perfectamente nivelada.';

  @override
  String get mm3SlotLoad => 'Carga del hueco';

  @override
  String get mm3NoSequence => 'Aún no hay pedidos en la secuencia.';

  @override
  String get mm3NotMeasurable =>
      'Nada que medir todavía: las piezas de esta secuencia no tienen tiempos de proceso en este alcance.';

  @override
  String get mm3Help =>
      'Una media móvil centrada de tres sobre la secuencia, vacía en ambos extremos.';

  @override
  String get summaryOccupation => 'Ocupación por centro de trabajo';

  @override
  String get summaryDemandTakt => 'Takt de demanda';

  @override
  String get summaryRequired => 'Requerido';

  @override
  String get summaryAvailable => 'Disponible';

  @override
  String get summaryOperatorsAllocated => 'Operarios asignados';

  @override
  String get summaryOperatorsNeeded => 'Operarios necesarios';

  @override
  String get summaryNoSteps =>
      'Este flujo aún no tiene pasos de proceso asignados.';

  @override
  String get summaryNothingToRank =>
      'Nada que clasificar todavía: ningún paso tiene horario y demanda a la vez.';

  @override
  String get summaryOverloaded =>
      'Por encima del 100 %: esta estación no puede con ello, se ordene como se ordene la secuencia.';

  @override
  String get summaryWithinCapacity => 'Dentro de la capacidad de este periodo.';

  @override
  String get summaryNoDemandTakt =>
      'Aún no hay takt de demanda: hace falta una estación con horas y pedidos con fecha en este periodo.';

  @override
  String summaryBottleneck(String name, String occupation) {
    return 'Cuello de botella: $name al $occupation';
  }

  @override
  String summaryOrdersDue(String count) {
    return '$count pedidos requeridos';
  }

  @override
  String summaryVisitsHelp(String count) {
    return 'El flujo pasa $count veces por esta estación, y cada visita la carga.';
  }

  @override
  String summaryMissingTimes(String count) {
    return '$count piezas requeridas aquí no tienen tiempo de proceso, así que las horas requeridas se quedan cortas.';
  }

  @override
  String summaryRequiredHelp(
    String work,
    String changeovers,
    String changeover,
  ) {
    return '$work de tiempo de proceso más $changeovers cambios por $changeover.';
  }

  @override
  String summaryOccupationHelp(
    String occupation,
    String required,
    String available,
  ) {
    return '$occupation = $required requeridas sobre $available disponibles.';
  }

  @override
  String summaryPaceSetter(String name, String available) {
    return 'Medido en $name, la estación más cargada, que tiene $available disponibles este periodo.';
  }

  @override
  String get summaryTaktConfigured => 'Takt configurado';

  @override
  String get summaryTaktConfiguredHelp =>
      'El takt al que está configurada esta línea, resuelto en la estación que marca el ritmo.';

  @override
  String get summaryTaktRaw => 'Takt de demanda bruto';

  @override
  String summaryTaktRawHelp(String orders) {
    return 'Tiempo disponible sobre $orders pedidos requeridos. Lo que espera un visitante.';
  }

  @override
  String get summaryTaktAdjusted => 'Takt de demanda ajustado por equivalencia';

  @override
  String summaryTaktAdjustedHelp(String equivalents) {
    return 'Tiempo disponible sobre $equivalents equivalentes de pieza requeridos. Lo que de verdad importa con una mezcla variada: un pedido que vale dos takts cuenta doble.';
  }

  @override
  String get actionImport => 'Importar';

  @override
  String importTitle(String file) {
    return 'Importar desde $file';
  }

  @override
  String get importSheet => 'Hoja';

  @override
  String get importMapping => 'Sus columnas a las nuestras';

  @override
  String get importNotMapped => 'Sin asignar';

  @override
  String importColumnNumber(String n) {
    return 'Columna $n';
  }

  @override
  String importUnmapped(String columns) {
    return 'No se encontró nada para: $columns. Esos valores se quedarán como están.';
  }

  @override
  String get importPreview => 'Lo que va a entrar';

  @override
  String importCountOk(String count) {
    return '$count filas listas';
  }

  @override
  String importCountSkipped(String count) {
    return '$count omitidas';
  }

  @override
  String importCountWarned(String count) {
    return '$count para revisar';
  }

  @override
  String importPreviewTruncated(String count) {
    return 'y $count filas más';
  }

  @override
  String importAccept(String count) {
    return 'Importar $count filas';
  }

  @override
  String importDone(String count) {
    return 'Se importaron $count filas.';
  }

  @override
  String importFailed(String error) {
    return 'No se importó nada: $error';
  }

  @override
  String importUnreadable(String error) {
    return 'No se pudo leer el archivo: $error';
  }

  @override
  String get importEmpty =>
      'Ese archivo no tiene filas debajo de una fila de encabezado.';

  @override
  String get importIssueMissingPart => 'Sin número de pieza';

  @override
  String get importIssueDuplicatePart =>
      'Esta pieza aparece dos veces en el archivo';

  @override
  String get importIssueNeedBeforeMaterial =>
      'Requerida antes de que llegue su material';

  @override
  String get fieldNote => 'Nota';

  @override
  String get exceptions => 'Excepciones de calendario';

  @override
  String get exceptionNew => 'Nueva excepción';

  @override
  String get exceptionsEmpty =>
      'Ninguna. La planta sigue su patrón de turnos todos los días laborables.';

  @override
  String get exceptionsHelp =>
      'Festivos, paradas y horas extra. Gana el alcance más específico, así que una parada de toda la planta puede anularse abriendo un centro de trabajo ese sábado.';

  @override
  String get exceptionKindNonWorking => 'Cerrado';

  @override
  String get exceptionKindExtraWorking => 'Horas extra';

  @override
  String get exceptionScope => 'Se aplica a';

  @override
  String get exceptionScopePlant => 'Toda la planta';

  @override
  String get exceptionScopeHelp =>
      'Se puede elegir un grupo en Centro de trabajo; se guarda como una excepción por miembro.';

  @override
  String get exceptionOperatorsHelp =>
      'Quién está en cada turno ese día. Un cero cierra ese turno.';

  @override
  String get exceptionDeleteTitle => '¿Eliminar esta excepción?';

  @override
  String get flowEndpointRename => 'Renombrar extremo';

  @override
  String get demandProject => 'Proyecto';

  @override
  String get demandDeleteAll => 'Eliminar todos los pedidos';

  @override
  String get demandDeleteAllBody =>
      'Se van todos los pedidos de la secuencia. Las piezas y sus tiempos de proceso se quedan.';

  @override
  String get stepCycleTime => 'C/T de takt';

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
  String get demandBatchSize => 'Tamaño de lote';

  @override
  String get demandBatchNumber => 'N.º de lote';

  @override
  String get demandBatchNumberHelp =>
      'Tu propio identificador para este lote de esta pieza — como lo llame el papeleo. Texto libre: nada lo usa para emparejar, se permiten repetidos y puede quedar vacío. Aparece en el plan de producción para que una orden impresa se encuentre en tu sistema.';

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
      'Por pieza. Escriba 30:00:00, 1.5h, 90min o 2d; un número sin unidad se lee como horas. Deje la celda vacía si la pieza no pasa por ese paso.';

  @override
  String get demandSequenceHelp =>
      'El orden en que la planta va a fabricar. Nada lo reordena salvo usted.';

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
  String get taktPeriodDeleteTitle => '¿Eliminar este periodo de takt?';

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
  String get schedulePeriodDeleteTitle =>
      '¿Eliminar este periodo de programación?';

  @override
  String get scheduleShifts => 'Turnos';

  @override
  String get scheduleOperatorsPerShift => 'Operarios por turno';

  @override
  String get availability => 'Disponibilidad';

  @override
  String get rework => 'Retrabajo';

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
  String get flowSourceEquivalent => 'Equivalente del flujo';

  @override
  String get flowSourceSinglePart => 'Una pieza (requiere demanda)';

  @override
  String get flowSourceWeighted =>
      'Todas las variantes, ponderadas (requiere demanda)';

  @override
  String get exportPdf => 'Exportar PDF';

  @override
  String get flowShowing => 'Mostrando';

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
  String get flowStep => 'Paso de proceso';

  @override
  String get flowStepTarget => 'Centro de trabajo o pool';

  @override
  String get flowStepTargetHelp =>
      'Un paso se ejecuta exactamente en uno. Un pool envía cada orden al miembro que se libere primero.';

  @override
  String get flowNodeNotes => 'Notas';

  @override
  String get flowMoveLeft => 'Mover antes';

  @override
  String get flowMoveRight => 'Mover después';

  @override
  String get flowDeleteNodeTitle => '¿Quitar este nodo del flujo?';

  @override
  String get stepProcessTime => 'Tiempo de proceso';

  @override
  String get stepSetup => 'Preparación';

  @override
  String get stepTeardown => 'Desmontaje';

  @override
  String get stepTeardownHelp =>
      'Desmontar la estación después de una orden. Se cobra junto con la preparación de la orden siguiente, porque si hace falta depende de lo que venga después.';

  @override
  String get stepSamePart => 'Misma pieza';

  @override
  String get stepSamePartHelp =>
      'Qué parte de la preparación y el desmontaje se sigue cobrando cuando la orden anterior era de la misma pieza. 0% hace gratis una repetición; 100% significa que agrupar no ahorra nada.';

  @override
  String get stepChangeover => 'Cambio de formato';

  @override
  String get laneCapacity => 'Capacidad del carril (órdenes)';

  @override
  String get laneCapacityHelp =>
      'Cuántas órdenes caben aquí. Déjalo vacío para ilimitado. Cuando está lleno, la estación anterior no puede dejar la orden terminada y se detiene, que es como la congestión sube por la línea. Distinto de las piezas de arriba: esa cifra es lo que hay hoy, esta es lo que permite el suelo.';

  @override
  String get workcenterParallelCapacity => 'Órdenes a la vez';

  @override
  String get workcenterParallelCapacityHelp =>
      'Cuántas órdenes procesa esta estación en paralelo. Uno es una sola máquina. Más de uno son unidades independientes, cada una con sus propios cambios de referencia — y el doble de capacidad en todo lo que se mide. Usa un pool cuando las máquinas sean realmente separadas y quieras ver cuál hizo qué.';

  @override
  String get studyStartBuffer => 'Margen de inicio (días naturales)';

  @override
  String get studyStartBufferHelp =>
      'Margen adicional antes del inicio calculado. Una simulación empieza en la fecha de necesidad de la primera orden, menos su lead time teórico, menos esto. Días naturales, porque los retrasos ocurren esté la planta abierta o no.';

  @override
  String get studyPaceSetter => 'Marcapasos';

  @override
  String get studyPaceSetterHelp =>
      'La estación cuyo reloj marca la cadencia de liberación, y cuyo carril decide cuándo puede entrar otra orden. Déjalo en automático para usar el paso más cargado.';

  @override
  String get studyPaceSetterAutomatic => 'Automático — el paso más cargado';

  @override
  String get simBlocked => 'Bloqueado';

  @override
  String get simBlockedHelp =>
      'Tiempo que la estación pasó sujetando una orden terminada porque el carril siguiente estaba lleno. No cuenta como ocupado: una estación atascada está ocupada y no produce nada.';

  @override
  String get simEmptySlotLaneFull => 'Carril lleno';

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
  String get footerProcessTime => 'Tiempo de proceso';

  @override
  String get footerLeadTime => 'Lead time (días hábiles)';

  @override
  String get footerLeadTimeRunning => 'Lead time (días corridos)';

  @override
  String get footerLeadTimeRunningHelp =>
      'El lead time en días hábiles × 1,4, la convención habitual de siete sobre cinco. Es una cifra de planificación, no una medición: una simulación recorre el calendario real de cada centro de trabajo, así que ambas pueden diferir y la corrida es lo que ocurrió.';

  @override
  String get footerPce => 'Eficiencia de proceso';

  @override
  String exportGenerated(String build, String timestamp) {
    return 'FlowMap $build · generado $timestamp';
  }

  @override
  String exportSaved(String path) {
    return 'Guardado en $path';
  }

  @override
  String get simFilterStudies => 'Estudios';

  @override
  String get simFilterCells => 'Células';

  @override
  String get simFilterLines => 'Líneas';

  @override
  String get simFilterPeriod => 'Periodo';

  @override
  String get simFilterPeriodHelp =>
      'Selecciona los pedidos por su fecha de necesidad — la única de las fechas de un pedido que nunca está vacía, así que un pedido que la corrida nunca completó sigue apareciendo en su periodo. La utilización y el tiempo bloqueado de los centros siguen describiendo la corrida completa, porque la corrida no guarda lo que haría falta para acotarlos.';

  @override
  String get simFilterAll => 'todos';

  @override
  String get simFilterProjects => 'Proyectos';

  @override
  String get simFilterParts => 'Números de pieza';

  @override
  String get simFilterOrders => 'Órdenes';

  @override
  String get simFilterOrdersHint => 'p. ej. 5, 12';

  @override
  String get simFilterNoProject => '(sin proyecto)';

  @override
  String simFilterOrdersEachStudy(int count) {
    return 'Los números de orden se repiten en cada estudio — hay $count estudios a la vista';
  }

  @override
  String get simFilterClear => 'Quitar filtros';

  @override
  String get simWorkspace => 'Simulación';

  @override
  String get simStationsWholeRun =>
      'Utilización y Bloqueado describen la corrida completa — la corrida no guarda lo que haría falta para acotar el tiempo abierto. Las demás columnas siguen el filtro.';

  @override
  String get simulationRun => 'Simular';

  @override
  String get simulationRunning => 'Ejecutando…';

  @override
  String get dispatchFifo => 'FIFO — por llegada';

  @override
  String get dispatchLifo => 'LIFO';

  @override
  String get dispatchEarliestDueDate => 'Fecha de necesidad más próxima';

  @override
  String get dispatchShortestProcessing => 'Menor tiempo de proceso';

  @override
  String get simulationNoStudies =>
      'Ningún estudio está seleccionado para simular';

  @override
  String get simulationNoStudiesHelp =>
      'Marca un estudio en la barra lateral. Varios estudios de una misma línea son escenarios de una sola realidad, así que una ejecución toma como máximo uno de cada.';

  @override
  String get simProblemNoTakt =>
      'Ningún periodo de takt cubre el día en que empezaría esta ejecución.';

  @override
  String get simProblemNoOrders =>
      'La secuencia de demanda está vacía: no hay nada que lanzar.';

  @override
  String get simProblemUnboundStep =>
      'Un paso no apunta a ningún centro de trabajo, o su grupo está vacío.';

  @override
  String get simProblemNoPaceSetter =>
      'Ningún paso puede marcar el ritmo de los lanzamientos: todos están sin asignar.';

  @override
  String get simulationNeverRun => 'Aún no hay ninguna ejecución';

  @override
  String get simulationNeverRunHelp =>
      'Simular ejecuta todos los estudios seleccionados contra un único modelo de la planta, de modo que las órdenes de una línea retrasan realmente las de otra.';

  @override
  String simulationAbortHorizon(String count) {
    return 'La demanda supera la capacidad. $count órdenes nunca se completaron y la ejecución se abandonó en lugar de seguir indefinidamente.';
  }

  @override
  String get simulationAbortNothingToRun =>
      'No se pudo empezar nada: el calendario de todas las estaciones está cerrado, o ningún estudio tenía una primera orden costeable.';

  @override
  String get simOnTimeDelivery => 'Entregas a tiempo';

  @override
  String simOnTimeOfOrders(String onTime, String orders) {
    return '$onTime de $orders órdenes a tiempo';
  }

  @override
  String get simOnTimeHelp =>
      'Se cuenta sobre todas las órdenes, no solo las entregadas: una orden que nunca salió no está a tiempo, diga lo que diga su fecha de necesidad.';

  @override
  String get simDelivered => 'Entregadas';

  @override
  String simDeliveredOf(String delivered, String orders) {
    return '$delivered de $orders';
  }

  @override
  String get simAverageFloat => 'Holgura media';

  @override
  String get simAverageFloatHelp =>
      'Fecha de necesidad menos fin de la orden, promediado sobre las órdenes que terminaron. Positivo es adelanto, con ese margen a favor; negativo es ese retraso. Una orden que nunca terminó no tiene holgura y queda fuera de aquí; arriba sigue contando como tarde.';

  @override
  String get simAverageLeadTime => 'Lead time medio';

  @override
  String get simAverageLeadTimeHelp =>
      'Tiempo de reloj dentro del flujo, desde el lanzamiento hasta el último paso.';

  @override
  String get simTheoreticalLeadTime => 'Lead time teórico';

  @override
  String get simTheoreticalLeadTimeHelp =>
      'Lo que tardarían estas órdenes atravesando la planta tal como está — el trabajo, un cambio de referencia completo en cada paso y el stock parado en cada cola — recorrido desde el lanzamiento de cada orden por los calendarios reales.';

  @override
  String get simLeadTimeEfficiency => 'Eficiencia del lead time';

  @override
  String get simLeadTimeEfficiencyHelp =>
      'Teórico ÷ real. Por encima del 100% el flujo esperó menos de lo que el estándar prevé; por debajo del 100% esperó más. Las órdenes de arranque — lanzadas antes de la primera entrega de su línea, cuando el flujo aún estaba vacío — quedan fuera.';

  @override
  String get simEmptySlots => 'Ranuras de lanzamiento vacías';

  @override
  String get simEmptySlotsHelp =>
      'Ranuras que llegaron sin nada que poner en ellas: la cabeza de la secuencia aún no tenía material, o el flujo ya estaba en su límite de WIP. La secuencia es lo que se estudia, así que una ranura vacía se cuenta en lugar de repararse en silencio.';

  @override
  String get simByQueue => 'Ordenado por tiempo en cola';

  @override
  String get simByShare => 'Ordenado por peso en el flujo';

  @override
  String get simRankingsHelp =>
      'Ambas clasificaciones están aquí porque su desacuerdo es el diagnóstico: una cola larga en una estación poco ocupada es un problema de secuenciación, no de capacidad.';

  @override
  String get simQueue => 'Cola';

  @override
  String get simQueueAverage => 'Cola media';

  @override
  String get simVisits => 'Visitas';

  @override
  String get simChangeovers => 'Cambios de referencia';

  @override
  String get utilization => 'Utilización';

  @override
  String get simUtilizationHelp =>
      'Tiempo ocupado ÷ tiempo abierto observado en esta ejecución. No es lo mismo que la ocupación, que es requerido ÷ disponible antes de simular: donde ambas discrepan, la secuenciación o la falta de alimentación se interpusieron.';

  @override
  String get simContributed => 'Cola + proceso';

  @override
  String get simShareOfFlow => 'Peso en el flujo';

  @override
  String get simPerPart => 'Por número de pieza';

  @override
  String get simOrders => 'Órdenes';

  @override
  String get simOnTime => 'A tiempo';

  @override
  String get simNothingRanked => 'Ninguna estación ejecutó nada.';

  @override
  String simRunSpan(String start, String end) {
    return '$start → $end';
  }

  @override
  String get simEarlierRuns => 'Ejecuciones anteriores';

  @override
  String simRunLabel(String timestamp, String rule) {
    return '$timestamp · $rule';
  }

  @override
  String get simViewResults => 'Resultados de simulación';

  @override
  String get simulationRunFailed => 'No se pudo completar la simulación';

  @override
  String get simProductionPlanHelp =>
      'Las filas van en orden de secuencia, que es también el orden de liberación: el motor libera siempre desde la cabeza de la secuencia y nunca la reordena. Las columnas vacías son de una simulación anterior a que FlowMap las registrara.';

  @override
  String get simPlanOrder => 'Orden';

  @override
  String get simPlanOrderStart => 'Inicio';

  @override
  String get simPlanOrderEnd => 'Fin';

  @override
  String get simPlanTakt => 'Takt';

  @override
  String get simPlanTheoreticalLeadTime => 'LT teórico';

  @override
  String get simPlanActualLeadTime => 'LT real';

  @override
  String get simPlanLeadTimeEfficiency => 'Eficiencia';

  @override
  String get simRunQueuesMixed => 'mixto';

  @override
  String simRunQueueRow(String name, String rule) {
    return '$name: $rule';
  }

  @override
  String get simRunDeleteBody =>
      'Se borra la ejecución y todo lo que registró. Los estudios con los que se hizo no se tocan.';

  @override
  String get simGanttView => 'Gantt de producción';

  @override
  String get simGanttEmpty =>
      'Esta ejecución no registró ningún paso, así que no hay nada que dibujar.';

  @override
  String get simGanttGapHelp =>
      'Una barra es la estación comprometida con esa orden, incluidas las horas cerradas. Un hueco es una estación que no está procesando: cerrada o sin material. Cuánto de ese hueco estaba siquiera abierto se responde en la tabla de colas.';

  @override
  String simGanttOrder(String number) {
    return 'Orden $number';
  }

  @override
  String get simGanttProject => 'Proyecto';

  @override
  String get simGanttCommitted => 'Comprometida';

  @override
  String get simGanttTakt => 'Takt';

  @override
  String get simGanttProcess => 'Tiempo de proceso';

  @override
  String get simGanttWaited => 'Espera antes de empezar';

  @override
  String get simGanttChangeover =>
      'Se pagó un cambio de referencia para empezarla';

  @override
  String simScheduleTail(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count pedidos terminaron después del $date usando el último calendario definido',
      one:
          '1 pedido terminó después del $date usando el último calendario definido',
    );
    return '$_temp0';
  }

  @override
  String get simScheduleTailHelp =>
      'Los periodos de takt y de calendario de los centros de trabajo terminan en esa fecha, así que la simulación prolongó el último más allá de ella. No es un error —una simulación corre hasta que termina el último pedido— pero las cifras posteriores a esa fecha describen una capacidad que nadie ha definido. Amplíe los periodos y vuelva a simular para confirmarlas.';

  @override
  String get settingsDisplay => 'Presentación';

  @override
  String get settingsDateFormatHelp =>
      'Cómo se escriben y se leen las fechas en toda la aplicación, incluida la exportación a Excel. Independiente del idioma de la interfaz. Las fechas ISO siempre se aceptan al escribir, sea cual sea el formato elegido.';

  @override
  String get dateFormatLocale => 'Seguir el idioma del sistema';

  @override
  String get dateFormatDayMonthYear => 'Día/mes/año';

  @override
  String get dateFormatMonthDayYear => 'Mes/día/año';

  @override
  String get dateFormatIso => 'Año-mes-día (ISO)';

  @override
  String simGanttLaneHolds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'El carril admite $count pedidos',
      one: 'El carril admite 1 pedido',
    );
    return '$_temp0';
  }

  @override
  String get simGanttLaneUncapped => 'El carril no tiene límite';

  @override
  String get simGanttStillWaiting => 'Seguía aquí al terminar la simulación';

  @override
  String get simGanttRowsStations => 'Centros';

  @override
  String get simGanttRowsWithLanes => 'Centros + carriles';

  @override
  String get simGanttRowsHelp =>
      'Si se dibujan las bandas de cola entre centros. Sin ellas el gráfico se lee como un flujo; con ellas, como una cola.';

  @override
  String get simGanttZoomIn => 'Acercar';

  @override
  String get simGanttZoomOut => 'Alejar';

  @override
  String simGanttFloored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count barras dibujadas más anchas de lo que son',
      one: '1 barra dibujada más ancha de lo que es',
    );
    return '$_temp0';
  }

  @override
  String get simGanttFlooredHelp =>
      'A este zoom estos pasos son más finos que un píxel, así que se dibujan al ancho mínimo para que se vean. Su posición es exacta; su ancho no. Al acercar, el aviso desaparece.';

  @override
  String get exportExcel => 'Exportar a Excel';

  @override
  String get simExportRunSheet => 'Ejecución';

  @override
  String get flowQueueEdit => 'Definir la cola delante de este paso';

  @override
  String flowQueueShared(String target) {
    return 'Una cola por estación: todos los pasos que alimentan $target esperan en esta, en este estudio y en los demás.';
  }

  @override
  String get flowQueueName => 'Nombre';

  @override
  String get flowQueueType => 'Tipo de cola';

  @override
  String get flowQueueTypeHelp =>
      'Cómo elige la estación siguiente la próxima orden de esta cola. Una cola sin tipo es una fila a la que nadie ha dado una regla; las cuatro reglas son disciplinas, y el mapa dibuja cada una distinta. El rótulo de la cola en el mapa es este tipo y la estación ante la que está.';

  @override
  String get flowQueueStock => 'Lo que hay ahora';

  @override
  String get queueTypeQueue => 'Cola — una fila, sin regla';

  @override
  String get queueShortFifo => 'FIFO';

  @override
  String get queueShortLifo => 'LIFO';

  @override
  String get queueShortEarliestDueDate => 'EDD';

  @override
  String get queueShortShortestProcessing => 'SPT';

  @override
  String get queueShortQueue => 'Cola';

  @override
  String get queueTypeSupermarket => 'Supermercado — todavía no';

  @override
  String get flowBatchHelp =>
      'Cuántas piezas cuesta cada caja. Los tiempos de proceso son por pieza, así que una orden de diez ocupa la estación diez veces más — que es lo que cobra la simulación. Déjalo vacío para seguir las órdenes que esta pieza tiene.';

  @override
  String get validationNumber => 'Introduce un número';

  @override
  String get validationAboveZero => 'Introduce un número mayor que cero';

  @override
  String get simEmptySlotAwaitingMaterial => 'Esperando material';

  @override
  String get simEmptySlotWipCap => 'Límite de WIP alcanzado';

  @override
  String get flowEndStockInbound => 'Stock de materia prima';

  @override
  String get flowEndStockOutbound => 'Stock de producto terminado';

  @override
  String get flowEndStockQuantity => 'Piezas presentes aquí';

  @override
  String get flowEndStockHelp =>
      'Una observación de lo que hay hoy en planta, en piezas, mostrada como días según el takt del período en pantalla. Cuenta para el lead time y para los días de stock, y nada se despacha desde aquí: los pedidos se liberan por takt, no se retiran de una estantería. Déjalo en blanco si nadie lo ha contado.';

  @override
  String get flowEndStockNone => 'Sin contar';

  @override
  String get stepBalancedMark => '⇄';

  @override
  String stepBalancedHelp(String type, String measured) {
    return 'Reequilibrado entre las estaciones de $type contiguas en este flujo: cada una se llena hasta su takt y la última se queda con el resto, así que cambiar el takt mueve el reparto sin ninguna otra edición. Aquí se midió $measured, y la tabla de demanda lo sigue guardando.';
  }

  @override
  String get stepRebalance =>
      'Reequilibrar con máquinas contiguas del mismo tipo';

  @override
  String get stepRebalanceHelp =>
      'Las estaciones del mismo tipo que están una al lado de la otra reparten su trabajo: cada una se llena hasta su takt y la última se queda con el resto, así que cambiar el takt mueve el reparto sin ninguna otra edición. Desactívalo para fijar esta estación en lo que se midió en ella.';

  @override
  String stepRebalanceNoType(String name) {
    return '$name no tiene tipo de centro de trabajo, así que nada dice que sea igual a sus vecinas.';
  }

  @override
  String stepRebalanceNoNeighbour(String type) {
    return 'Ningún paso contiguo comparte el tipo $type.';
  }

  @override
  String get stepRebalanceNoWork =>
      'Esta pieza no tiene tiempo aquí, así que la estación no reparte trabajo.';

  @override
  String stepRebalanceOn(String type) {
    return 'Repartiendo trabajo con las estaciones $type contiguas.';
  }

  @override
  String simRunTakt(String takt) {
    return 'Ejecutado con $takt';
  }

  @override
  String simRunTaktChanges(String date) {
    return 'El takt cambió el $date, dentro de esta simulación.';
  }

  @override
  String get simRunTaktMixed => 'mixto';

  @override
  String flowTaktChanges(String from, String to, String date, String shown) {
    return 'Takt $from → $to el $date — mostrando $shown';
  }

  @override
  String simRunCadenceEnded(String study, String date, int count) {
    return '$study dejó de abrir pedidos el $date: su calendario de takt termina ahí y $count no se abrieron.';
  }

  @override
  String get settingsLanguageHelp =>
      'En qué idioma se muestra la aplicación. Seguir el sistema usa el idioma de Windows.';

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
    return 'Comparte trabajo con las estaciones $type contiguas. Llenada hasta $filled de $capacity: con un $rework% de retrabajo, ese contenido ocupa un takt completo.';
  }

  @override
  String stepRebalanceRemainder(String type, String filled, String capacity) {
    return 'Comparte trabajo con las estaciones $type contiguas. Ellas se llenan hasta su takt y esta se queda con lo que sobra: $filled, dentro de las $capacity que cabe en un takt.';
  }

  @override
  String stepRebalanceRemainderOver(
    String type,
    String filled,
    String capacity,
  ) {
    return 'Comparte trabajo con las estaciones $type contiguas. Ellas se llenan hasta su takt y esta se queda con lo que sobra: $filled, por encima de las $capacity que cabe en un takt. El grupo necesita más de lo que tienen sus estaciones.';
  }

  @override
  String get occupationView => 'Ocupación';

  @override
  String get occupationType => 'Tipo';

  @override
  String get occupationStation => 'Estación';

  @override
  String get occupationLine => 'Línea';

  @override
  String get occupationUngraphable =>
      'Esta simulación se hizo antes de que la app registrara cuánto valía un mes de una estación, así que no se puede graficar. Vuelve a simular para obtener el gráfico.';

  @override
  String get projectSettingsFloat => 'Umbrales de holgura';

  @override
  String get projectSettingsFloatHelp =>
      'Dónde la matriz de holgura se pone roja y verde. Entre las dos, ámbar.';

  @override
  String get projectFloatRed => 'Rojo en o por debajo de (días)';

  @override
  String get projectFloatGreen => 'Verde en o por encima de (días)';

  @override
  String get projectFloatRedHelp =>
      'Un pedido con esta holgura o menos se dibuja en rojo. Cero significa que un pedido entregado justo en su fecha no tiene ninguna.';

  @override
  String get projectFloatGreenHelp =>
      'Un pedido con al menos esta holgura se dibuja en verde.';

  @override
  String get floatMatrixTitle => 'Holgura de entrega';

  @override
  String get floatMatrixHelp =>
      'Las columnas son el mes de la fecha de necesidad del pedido; las filas, su orden dentro de ese mes por fecha. Las celdas son holgura en días: positivo es adelantado.';

  @override
  String get floatMatrixUndelivered => 'Nunca entregado';

  @override
  String get floatMatrixEmpty =>
      'Ningún pedido de este corte tiene fecha de necesidad que situar.';

  @override
  String floatLegendRed(String days) {
    return '$days d o menos';
  }

  @override
  String floatLegendAmber(String red, String green) {
    return 'Entre $red d y $green d';
  }

  @override
  String floatLegendGreen(String days) {
    return '$days d o más';
  }

  @override
  String get workspaceModeStudy => 'Estudio';

  @override
  String get simTabOverview => 'Resumen de simulación';

  @override
  String get simTabPlan => 'Plan de producción';

  @override
  String get simPlanByStudy => 'Por estudio';

  @override
  String get simPlanCombined => 'Combinado';

  @override
  String get simPlanStudy => 'Estudio';

  @override
  String get simPlanCell => 'Célula';

  @override
  String get simPlanLine => 'Línea';

  @override
  String get simRunCovers => 'Estudios en esta simulación';

  @override
  String get simRunCoversFiltered => 'excluido por el filtro';

  @override
  String simulationStudiesNotReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count estudios no están listos para simular',
      one: '1 estudio no está listo para simular',
    );
    return '$_temp0';
  }

  @override
  String get occupationByWorkcenter => 'Por centro de trabajo';

  @override
  String get occupationByLine => 'Por línea';

  @override
  String get occupationUnitPercent => '%';

  @override
  String get occupationUnitHours => 'Horas';

  @override
  String get occupationUnitGap => 'Diferencia';

  @override
  String get occupationWorkcenter => 'Centro de trabajo';

  @override
  String get occupationAmberAbove => 'Ámbar por encima de';

  @override
  String get occupationRedAbove => 'Rojo por encima de';

  @override
  String get occupationBands =>
      'Dónde la cuadrícula de ocupación pasa a ámbar y a rojo. Un centro al que se le piden más horas de las que tiene abiertas está excedido por definición; la banda ámbar es el margen que queda para el cambio que trae el siguiente pedido.';

  @override
  String get occupationProcess => 'Proceso';

  @override
  String get occupationRework => 'Retrabajo';

  @override
  String get occupationChangeover => 'Cambio';

  @override
  String get occupationOutsideFilter => 'Fuera del filtro';

  @override
  String occupationStations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count centros agregados',
      one: '1 centro agregado',
    );
    return '$_temp0';
  }

  @override
  String get occupationTipDemand => 'Demanda';

  @override
  String get occupationTipCapacity => 'Capacidad';

  @override
  String occupationHours(Object hours) {
    return '$hours h';
  }

  @override
  String get occupationTotal => 'TOTAL';

  @override
  String get occupationAllMonths => 'todos los meses mostrados';

  @override
  String get floatAverage => 'PROM';

  @override
  String floatAverageHelp(Object days) {
    return '$days días de holgura en promedio.';
  }

  @override
  String get demandPasteHint =>
      'Escriba un valor, o pegue un bloque de Excel con Ctrl+V.';

  @override
  String get occupationBandsTitle => 'Bandas de ocupación';
}
