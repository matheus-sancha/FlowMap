// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'FlowMap';

  @override
  String get navProjects => 'Projetos';

  @override
  String get navTemplates => 'Modelos de estudo';

  @override
  String get navResources => 'Recursos';

  @override
  String get navSettings => 'Configurações';

  @override
  String get navAbout => 'Sobre';

  @override
  String get actionAdd => 'Adicionar';

  @override
  String get actionEdit => 'Editar';

  @override
  String get actionDelete => 'Excluir';

  @override
  String get actionArchive => 'Arquivar';

  @override
  String get actionRestore => 'Restaurar';

  @override
  String get actionSave => 'Salvar';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionClose => 'Fechar';

  @override
  String get actionDuplicate => 'Duplicar';

  @override
  String get actionRename => 'Renomear';

  @override
  String get fieldName => 'Nome';

  @override
  String get fieldCode => 'Código';

  @override
  String get fieldType => 'Tipo';

  @override
  String get fieldNotes => 'Observações';

  @override
  String get fieldStart => 'Início';

  @override
  String get fieldEnd => 'Fim';

  @override
  String get validationRequired => 'Obrigatório';

  @override
  String get validationNameTaken => 'Esse nome já está em uso aqui';

  @override
  String get resourcesTitle => 'Recursos';

  @override
  String get resourcesEmpty =>
      'Nenhuma planta ainda. Crie uma para começar a montar estudos.';

  @override
  String get resourcesShowArchived => 'Mostrar arquivados';

  @override
  String get resourcesArchivedBadge => 'Arquivado';

  @override
  String get plant => 'Planta';

  @override
  String get plantNew => 'Nova planta';

  @override
  String get plantDeleteBlocked =>
      'Esta planta possui células de produção. Arquive-a em vez de excluir.';

  @override
  String get productionCell => 'Célula de produção';

  @override
  String get productionCells => 'Células de produção';

  @override
  String get productionCellNew => 'Nova célula de produção';

  @override
  String get productionLine => 'Linha de produção';

  @override
  String get productionLines => 'Linhas de produção';

  @override
  String get productionLineNew => 'Nova linha de produção';

  @override
  String get workcenter => 'Centro de trabalho';

  @override
  String get workcenters => 'Centros de trabalho';

  @override
  String get workcenterNew => 'Novo centro de trabalho';

  @override
  String get workcenterType => 'Tipo de centro de trabalho';

  @override
  String get workcenterTypes => 'Tipos de centro de trabalho';

  @override
  String get workcenterTypeNew => 'Novo tipo de centro de trabalho';

  @override
  String get workcenterLines => 'Exibido sob estas linhas';

  @override
  String get workcenterLinesHelp =>
      'Apenas organizacional. Qualquer estudo de qualquer linha pode usar este centro de trabalho, marque o que marcar, e uma estação que atende duas linhas fica sob as duas.';

  @override
  String get workcenterNoLines =>
      'Esta planta ainda não tem linhas de produção.';

  @override
  String workcenterOnLines(String count) {
    return 'em $count linhas';
  }

  @override
  String workcenterRemoveFromLine(String line) {
    return 'Tirar de $line';
  }

  @override
  String get workcenterDeleteBody =>
      'Isto remove o centro de trabalho da planta, não só desta linha. Os horários vão junto.';

  @override
  String get workcenterTypeIcon => 'Ícone';

  @override
  String get workcenterTypeIconHelp =>
      'Os centros de trabalho deste tipo são desenhados com ele, na árvore e nos seletores.';

  @override
  String get workcenterTypeNone => 'Sem ícone';

  @override
  String get workcenterTypeEdit => 'Tipo de centro de trabalho';

  @override
  String get iconMachining => 'Usinagem';

  @override
  String get iconLathe => 'Torno';

  @override
  String get iconMilling => 'Fresamento';

  @override
  String get iconDrilling => 'Furação';

  @override
  String get iconGrinding => 'Retífica';

  @override
  String get iconCutting => 'Corte';

  @override
  String get iconBending => 'Dobra';

  @override
  String get iconPress => 'Prensa';

  @override
  String get iconWelding => 'Solda';

  @override
  String get iconCladding => 'Revestimento';

  @override
  String get iconHeatTreatment => 'Tratamento térmico';

  @override
  String get iconCoating => 'Camada';

  @override
  String get iconPainting => 'Pintura';

  @override
  String get iconCleaning => 'Limpeza';

  @override
  String get iconAssembly => 'Montagem';

  @override
  String get iconRobot => 'Robô';

  @override
  String get iconConveyor => 'Transportador';

  @override
  String get iconInspection => 'Inspeção';

  @override
  String get iconTesting => 'Ensaio';

  @override
  String get iconMeasuring => 'Medição';

  @override
  String get iconPacking => 'Embalagem';

  @override
  String get iconStorage => 'Armazém';

  @override
  String get workcenterPool => 'Pool de centros de trabalho';

  @override
  String get workcenterPools => 'Pools de centros de trabalho';

  @override
  String get workcenterPoolNew => 'Novo pool';

  @override
  String get workcenterPoolMembers => 'Membros';

  @override
  String get workcenterPoolEmpty =>
      'Um pool precisa de pelo menos um centro de trabalho.';

  @override
  String get shiftPattern => 'Padrão de turnos';

  @override
  String get shiftPatterns => 'Padrões de turnos';

  @override
  String get shiftPatternNew => 'Novo padrão de turnos';

  @override
  String get shiftPatternCycle => 'Ciclo';

  @override
  String get shiftPatternCycleFixedWeekly => 'Semanal fixo';

  @override
  String get shiftPatternCycleRotating => 'Revezamento (contínuo)';

  @override
  String get shiftPatternWorkingDays => 'Dias úteis base';

  @override
  String get shiftPatternShifts => 'Turnos';

  @override
  String get shiftPatternShiftNew => 'Adicionar turno';

  @override
  String get shiftPatternNoShifts =>
      'Um padrão precisa de pelo menos um turno.';

  @override
  String get shiftLabel => 'Identificação';

  @override
  String get shiftStart => 'Início';

  @override
  String get shiftEnd => 'Fim';

  @override
  String get shiftBreak => 'Intervalo';

  @override
  String get shiftCrossesMidnight => 'Vira o dia';

  @override
  String get shiftDuration => 'Duração líquida';

  @override
  String shiftOverlapWarning(String other) {
    return 'Este turno se sobrepõe a $other.';
  }

  @override
  String get weekdayMon => 'Seg';

  @override
  String get weekdayTue => 'Ter';

  @override
  String get weekdayWed => 'Qua';

  @override
  String get weekdayThu => 'Qui';

  @override
  String get weekdayFri => 'Sex';

  @override
  String get weekdaySat => 'Sáb';

  @override
  String get weekdaySun => 'Dom';

  @override
  String confirmDeleteTitle(String name) {
    return 'Excluir $name?';
  }

  @override
  String get confirmDeleteBody => 'Isso não pode ser desfeito.';

  @override
  String get confirmArchiveBody =>
      'Permanece disponível para projetos que já o utilizam, mas fica oculto nas listas de seleção.';

  @override
  String aboutVersion(String version) {
    return 'Versão $version';
  }

  @override
  String aboutBuild(String build) {
    return 'Build $build';
  }

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageSystem => 'Sistema';

  @override
  String get settingsDateFormat => 'Formato de data';

  @override
  String get settingsDateFormatLocale => 'Seguir o idioma';

  @override
  String get comingSoon => 'Em breve';

  @override
  String get valueNone => 'Nenhum';

  @override
  String get workcenterNameHelp =>
      'Como o chão de fábrica o chama, e o rótulo na caixa de processo — por exemplo CLAD04.';

  @override
  String get workcenterAddExisting => 'Adicionar existente';

  @override
  String get workcenterAddExistingHelp =>
      'Um centro de trabalho pertence à planta, então isso só muda onde ele aparece na árvore. Qualquer estudo de qualquer linha pode utilizá-lo de todo modo.';

  @override
  String get workcenterNoneToAdd =>
      'Todos os centros de trabalho desta planta já estão nesta linha.';

  @override
  String get workcenterHomeLine => 'Linha de produção principal';

  @override
  String get workcenterHomeLineHelp =>
      'Onde aparece na árvore. Estudos de outras linhas ainda podem utilizá-lo, e é esse uso compartilhado que a simulação disputa.';

  @override
  String get workcenterTypeUnset => 'Sem tipo';

  @override
  String get workcenterTypeDeleteBody =>
      'Os centros de trabalho que usam este tipo continuam funcionando; o tipo deles é limpo.';

  @override
  String get workcenterPoolNoCandidates =>
      'Esta planta ainda não tem centros de trabalho.';

  @override
  String get resourcesUnassigned => 'Fora de linha';

  @override
  String get resourcesUnassignedHelp =>
      'Centros de trabalho que pertencem à planta mas não estão sob uma linha de produção.';

  @override
  String get shiftPatternRotatingHelp =>
      'Opera todos os dias. Os turnos são janelas de tempo, não equipes — quatro equipes revezando em duas janelas de 12 horas são dois turnos aqui, porque a capacidade vem das janelas cobertas.';

  @override
  String get shiftPatternEveryDay => 'Todos os dias';

  @override
  String get shiftPatternNoWorkingDays => 'Sem dias úteis';

  @override
  String shiftPatternOpenPerDay(String duration) {
    return 'Aberto $duration/dia';
  }

  @override
  String get shiftBreakMinutes => 'Intervalo (min)';

  @override
  String shiftBreakOf(String duration) {
    return 'Intervalo $duration';
  }

  @override
  String get projectNew => 'Novo projeto';

  @override
  String get projectsEmpty => 'Nenhum projeto ainda.';

  @override
  String get projectMissing => 'Esse projeto não existe mais.';

  @override
  String get projectNeedsPlant =>
      'Crie uma planta em Recursos antes de iniciar um projeto.';

  @override
  String get projectPlantHelp =>
      'Não pode ser alterada depois: todo estudo, programação e etapa de fluxo do projeto aponta para os centros de trabalho desta planta.';

  @override
  String get projectPatternHelp =>
      'A divisão de turnos com que todo centro de trabalho deste projeto é dimensionado.';

  @override
  String get projectDeleteBody =>
      'Os estudos, programações e fluxos vão junto. Isso não pode ser desfeito.';

  @override
  String get studyNew => 'Novo estudo';

  @override
  String get studiesEmpty => 'Nenhum estudo neste projeto ainda.';

  @override
  String get studyNameHint => 'Situação atual';

  @override
  String get studyNeedsLine => 'Esta planta ainda não tem linhas de produção.';

  @override
  String get studyLineHelp =>
      'Um estudo pertence a uma linha. Vários estudos da mesma linha são cenários; só um pode ser selecionado para a simulação.';

  @override
  String get studyDeleteBody =>
      'O fluxo e as anotações vão junto. Isso não pode ser desfeito.';

  @override
  String get studyIncludeInSimulation => 'Incluir na simulação';

  @override
  String get studyExcludeFromSimulation => 'Excluir da simulação';

  @override
  String get studiesCollapse => 'Ocultar a lista de estudos';

  @override
  String get studiesExpand => 'Mostrar a lista de estudos';

  @override
  String get studyTabFlow => 'Fluxo';

  @override
  String get studyTabTakt => 'Takt';

  @override
  String get studyTabDemand => 'Demanda';

  @override
  String get studyTabSummary => 'Resumo';

  @override
  String get actionMoveUp => 'Subir';

  @override
  String get actionMoveDown => 'Descer';

  @override
  String get validationNotADuration => 'Não é um tempo';

  @override
  String get validationNotADate => 'Não é uma data';

  @override
  String get validationPositiveWhole => 'Um número inteiro maior que zero';

  @override
  String get validationUnknownPart =>
      'Nenhuma peça com esse número neste estudo';

  @override
  String get stepProblemNoProcessTime =>
      'Esta peça não tem tempo de processo aqui.';

  @override
  String get stepEquivalence => 'Equivalente';

  @override
  String get flowPart => 'Peça';

  @override
  String get flowNoParts => 'Ainda não há peças';

  @override
  String get footerEquivalence => 'Equivalente';

  @override
  String get footerEquivalenceHelp =>
      'O tempo de processo desta peça em todo o fluxo dividido pelo do equivalente de fluxo. 1,13 significa que consome 1,13 takts da capacidade da linha.';

  @override
  String get flowSourceNeedsDemand =>
      'Precisa de pelo menos uma peça na aba Demanda';

  @override
  String get mm3 => 'MM3';

  @override
  String get mm3Column => 'MM3';

  @override
  String get mm3Scope => 'Medido sobre';

  @override
  String get mm3WholeFlow => 'Fluxo inteiro';

  @override
  String get mm3Smoothness => 'Desvio médio';

  @override
  String get mm3SmoothnessHelp =>
      'O quanto a média móvel fica longe de 1,0 em média. 1,0 é um takt da capacidade do escopo por pedido, ou seja, uma sequência perfeitamente nivelada.';

  @override
  String get mm3SlotLoad => 'Carga do slot';

  @override
  String get mm3SlotLoadHelp =>
      'O equivalente da peça vezes o tamanho do lote — o que este slot de liberação custa ao fluxo. O MM3 faz a média disto, não do equivalente.';

  @override
  String get mm3NoSequence => 'Ainda não há pedidos na sequência.';

  @override
  String get mm3NotMeasurable =>
      'Nada a medir ainda: as peças desta sequência não têm tempos de processo neste escopo.';

  @override
  String get mm3Help =>
      'Uma média móvel centrada de três sobre a sequência, vazia nas duas pontas. Reordene na aba Sequência e veja achatar.';

  @override
  String get summaryOccupation => 'Ocupação por centro de trabalho';

  @override
  String get summaryDemandTakt => 'Takt de demanda';

  @override
  String get summaryRequired => 'Necessário';

  @override
  String get summaryAvailable => 'Disponível';

  @override
  String get summaryOperatorsAllocated => 'Operadores alocados';

  @override
  String get summaryOperatorsNeeded => 'Operadores necessários';

  @override
  String get summaryNoSteps =>
      'Este fluxo ainda não tem passos de processo vinculados.';

  @override
  String get summaryNothingToRank =>
      'Nada a classificar ainda: nenhum passo tem horário e demanda ao mesmo tempo.';

  @override
  String get summaryOverloaded =>
      'Acima de 100 %: esta estação não dá conta, seja qual for a ordem da sequência.';

  @override
  String get summaryWithinCapacity => 'Dentro da capacidade deste período.';

  @override
  String get summaryNoDemandTakt =>
      'Ainda não há takt de demanda: é preciso uma estação com horas e pedidos com data neste período.';

  @override
  String summaryBottleneck(String name, String occupation) {
    return 'Gargalo: $name a $occupation';
  }

  @override
  String summaryOrdersDue(String count) {
    return '$count pedidos no período';
  }

  @override
  String summaryVisitsHelp(String count) {
    return 'O fluxo passa $count vezes por esta estação, e cada visita a carrega.';
  }

  @override
  String summaryMissingTimes(String count) {
    return '$count peças do período não têm tempo de processo aqui, então as horas necessárias estão subestimadas.';
  }

  @override
  String summaryRequiredHelp(
    String work,
    String changeovers,
    String changeover,
  ) {
    return '$work de tempo de processo mais $changeovers setups valendo $changeover.';
  }

  @override
  String summaryOccupationHelp(
    String occupation,
    String required,
    String available,
  ) {
    return '$occupation = $required necessárias sobre $available disponíveis.';
  }

  @override
  String summaryPaceSetter(String name, String available) {
    return 'Medido em $name, a estação mais carregada, que tem $available disponíveis neste período.';
  }

  @override
  String get summaryTaktConfigured => 'Takt configurado';

  @override
  String get summaryTaktConfiguredHelp =>
      'O takt para o qual esta linha está configurada, resolvido na estação que dita o ritmo.';

  @override
  String get summaryTaktRaw => 'Takt de demanda bruto';

  @override
  String summaryTaktRawHelp(String orders) {
    return 'Tempo disponível sobre $orders pedidos no período. O que um visitante espera.';
  }

  @override
  String get summaryTaktAdjusted => 'Takt de demanda ajustado por equivalência';

  @override
  String summaryTaktAdjustedHelp(String equivalents) {
    return 'Tempo disponível sobre $equivalents equivalentes de peça no período. O que realmente importa com um mix variado: um pedido que vale dois takts conta em dobro.';
  }

  @override
  String get actionImport => 'Importar';

  @override
  String importTitle(String file) {
    return 'Importar de $file';
  }

  @override
  String get importSheet => 'Planilha';

  @override
  String get importMapping => 'As colunas deles para as nossas';

  @override
  String get importNotMapped => 'Sem vínculo';

  @override
  String importColumnNumber(String n) {
    return 'Coluna $n';
  }

  @override
  String importUnmapped(String columns) {
    return 'Nada encontrado para: $columns. Esses valores vão ficar como estão.';
  }

  @override
  String get importPreview => 'O que vai entrar';

  @override
  String importCountOk(String count) {
    return '$count linhas prontas';
  }

  @override
  String importCountSkipped(String count) {
    return '$count ignoradas';
  }

  @override
  String importCountWarned(String count) {
    return '$count para conferir';
  }

  @override
  String importPreviewTruncated(String count) {
    return 'e mais $count linhas';
  }

  @override
  String importAccept(String count) {
    return 'Importar $count linhas';
  }

  @override
  String importDone(String count) {
    return '$count linhas importadas.';
  }

  @override
  String importFailed(String error) {
    return 'Nada foi importado: $error';
  }

  @override
  String importUnreadable(String error) {
    return 'Não foi possível ler o arquivo: $error';
  }

  @override
  String get importEmpty =>
      'Esse arquivo não tem linhas abaixo de uma linha de cabeçalho.';

  @override
  String get importIssueMissingPart => 'Sem número de peça';

  @override
  String get importIssueDuplicatePart =>
      'Esta peça aparece duas vezes no arquivo';

  @override
  String get importIssueNeedBeforeMaterial =>
      'Necessária antes de o material chegar';

  @override
  String get fieldNote => 'Observação';

  @override
  String get exceptions => 'Exceções de calendário';

  @override
  String get exceptionNew => 'Nova exceção';

  @override
  String get exceptionsEmpty =>
      'Nenhuma. A planta segue seu padrão de turnos em todo dia útil.';

  @override
  String get exceptionsHelp =>
      'Feriados, paradas e horas extras. Vence o escopo mais específico, então uma parada de toda a planta pode ser anulada abrindo um centro de trabalho naquele sábado.';

  @override
  String get exceptionKindNonWorking => 'Fechado';

  @override
  String get exceptionKindExtraWorking => 'Horas extras';

  @override
  String get exceptionScope => 'Aplica-se a';

  @override
  String get exceptionScopePlant => 'Toda a planta';

  @override
  String get exceptionScopeHelp =>
      'Um grupo pode ser escolhido em Centro de trabalho; é salvo como uma exceção por membro.';

  @override
  String get exceptionOperatorsHelp =>
      'Quem está em cada turno naquele dia. Um zero fecha o turno.';

  @override
  String get exceptionDeleteTitle => 'Excluir esta exceção?';

  @override
  String get flowEndpointRename => 'Renomear extremidade';

  @override
  String get demandProject => 'Projeto';

  @override
  String get demandDeleteAll => 'Excluir todos os pedidos';

  @override
  String get demandDeleteAllBody =>
      'Todos os pedidos da sequência vão embora. As peças e seus tempos de processo ficam.';

  @override
  String get stepCycleTime => 'T/C de takt';

  @override
  String get demandParts => 'Peças';

  @override
  String get demandSequence => 'Sequência';

  @override
  String get demandPartNumber => 'Número da peça';

  @override
  String get demandDescription => 'Descrição';

  @override
  String get demandTotal => 'Total';

  @override
  String get demandOrderNumber => 'Pedido';

  @override
  String get demandBatchSize => 'Lote';

  @override
  String get demandNeedDate => 'Data necessária';

  @override
  String get demandMaterialDate => 'Data do material';

  @override
  String get demandMaterialDateHelp => 'opcional';

  @override
  String get demandUnbound => 'sem vínculo';

  @override
  String get demandTimesHelp =>
      'Por peça. Digite 30:00:00, 1.5h, 90min ou 2d; um número sem unidade é lido como horas. Deixe a célula vazia quando a peça não passa pelo passo. Cole um bloco do Excel com Ctrl+V.';

  @override
  String get demandSequenceHelp =>
      'A ordem em que a planta vai produzir. Nada a reordena além de você. Cole um bloco do Excel com Ctrl+V.';

  @override
  String get demandNoSteps =>
      'Este fluxo ainda não tem passos de processo, então não há contra o que custear uma peça.';

  @override
  String get demandNeedsPart => 'Adicione uma peça antes de adicionar pedidos.';

  @override
  String get demandPartDeleteBody =>
      'Os tempos de processo vão junto, e todos os pedidos dela saem da sequência.';

  @override
  String get takt => 'Takt';

  @override
  String get taktUnit => 'Unidade';

  @override
  String get taktEmpty =>
      'Nenhum takt definido para esta linha de produção ainda.';

  @override
  String get taktPeriodNew => 'Novo período de takt';

  @override
  String get taktPeriodDeleteTitle => 'Excluir este período de takt?';

  @override
  String get taktDaysHelp =>
      'Dias são relativos à capacidade de cada centro de trabalho: um takt de 3 dias vale 68 h em uma estação aberta 22:40 por dia e 26:24 em uma aberta 8:48.';

  @override
  String get taktLiteralHelp =>
      'Resulta na mesma duração em todos os centros de trabalho.';

  @override
  String get unitDays => 'dias';

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
  String get schedulePeriodNew => 'Novo período';

  @override
  String get schedulePeriodDeleteTitle =>
      'Excluir este período de programação?';

  @override
  String get scheduleShifts => 'Turnos';

  @override
  String get scheduleOperatorsPerShift => 'Operadores por turno';

  @override
  String scheduleShiftsDerived(String count, String operators) {
    return 'Turnos: $count ($operators) — contados a partir dos turnos com operadores, nunca armazenados à parte.';
  }

  @override
  String get availability => 'Disponibilidade';

  @override
  String get availabilityHelp =>
      'Fração do tempo aberto em que o centro de trabalho consegue operar. Aplicada uma única vez, ao tempo de processo.';

  @override
  String get availabilityInvalid => 'Deve ser maior que 0% e no máximo 100%';

  @override
  String get rework => 'Retrabalho';

  @override
  String get reworkHelp =>
      'Fração do trabalho que precisa ser refeita. Aumenta o tempo de processo.';

  @override
  String get reworkInvalid => 'Deve ser 0% ou mais';

  @override
  String get occupation => 'Ocupação';

  @override
  String get workcentersTabEmpty =>
      'Adicione etapas ao fluxo para programar seus centros de trabalho aqui.';

  @override
  String workcentersTabPattern(String shifts) {
    return 'Padrão de turnos: $shifts';
  }

  @override
  String get scheduleIssueEmpty =>
      'Nenhum período definido. Nada aqui pode ser calculado até existir pelo menos um.';

  @override
  String scheduleIssueOverlap(String from, String to) {
    return 'Dois períodos cobrem $from até $to.';
  }

  @override
  String scheduleIssueGap(String from, String to) {
    return 'Nenhum período cobre $from até $to.';
  }

  @override
  String scheduleIssueInverted(String from, String to) {
    return 'Um período termina ($to) antes de começar ($from).';
  }

  @override
  String get periodPrevious => 'Período anterior';

  @override
  String get periodNext => 'Próximo período';

  @override
  String get periodMonth => 'Mês';

  @override
  String get periodQuarterly => 'Trimestre';

  @override
  String get periodSemesterly => 'Semestre';

  @override
  String get periodYearly => 'Ano';

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
      'O takt ou o dimensionamento mudam dentro deste período. O mapa mostra a situação do primeiro dia.';

  @override
  String get footerTaktHelp =>
      'O ritmo da linha de produção neste período — uma unidade sai da linha a cada takt.';

  @override
  String get footerProcessTimeHelp =>
      'A soma do tempo de processo de todas as etapas. Somente tempo que agrega valor; a espera não entra.';

  @override
  String get footerLeadTimeHelp =>
      'Tempo de processo mais todas as esperas entre etapas — quanto uma ordem leva para atravessar o fluxo.';

  @override
  String get footerPceHelp =>
      'Eficiência do ciclo de processo: tempo de processo ÷ lead time. A parcela do tempo decorrido que agrega valor.';

  @override
  String get flowDataSource => 'Linha do tempo';

  @override
  String get flowSourceEquivalent => 'Equivalente do fluxo';

  @override
  String get flowSourceSinglePart => 'Um item (requer demanda)';

  @override
  String get flowSourceWeighted =>
      'Todas as variantes, ponderadas (requer demanda)';

  @override
  String get exportPdf => 'Exportar PDF';

  @override
  String get flowSupplier => 'Fornecedor';

  @override
  String get flowCustomer => 'Cliente';

  @override
  String get flowFitToScreen => 'Ajustar à tela';

  @override
  String get flowZoomIn => 'Ampliar';

  @override
  String get flowZoomOut => 'Reduzir';

  @override
  String get flowInsertHere => 'Inserir aqui';

  @override
  String get flowInsertStep => 'Etapa de processo';

  @override
  String get flowInsertStepHelp => 'Executa em um centro de trabalho ou pool.';

  @override
  String get flowInsertInventory => 'Estoque';

  @override
  String get flowInsertInventoryHelp => 'Onde as ordens esperam entre etapas.';

  @override
  String get flowStep => 'Etapa de processo';

  @override
  String get flowInventory => 'Estoque';

  @override
  String get flowStepTarget => 'Centro de trabalho ou pool';

  @override
  String get flowStepTargetHelp =>
      'Uma etapa executa em exatamente um. Um pool envia cada ordem para o membro que ficar livre primeiro.';

  @override
  String get flowNodeLabel => 'Rótulo';

  @override
  String get flowNodeLabelHelp =>
      'Exibido no lugar do código do centro de trabalho.';

  @override
  String get flowMoveLeft => 'Mover para antes';

  @override
  String get flowMoveRight => 'Mover para depois';

  @override
  String get flowDeleteNodeTitle => 'Remover este nó do fluxo?';

  @override
  String get stepProcessTime => 'Tempo de processo';

  @override
  String get stepChangeover => 'Setup';

  @override
  String get stepChangeoverHelp =>
      'Cobrado apenas quando a ordem anterior neste centro de trabalho era de outro item.';

  @override
  String get stepOperators => 'Operadores';

  @override
  String get stepEquivalentTime => 'Takt time específico do processo';

  @override
  String get stepEquivalentFollowsTakt => 'Segue o takt';

  @override
  String get stepEquivalentHelp =>
      'O takt próprio desta etapa, usado pelo equivalente do fluxo no lugar do takt da linha. Deixe em branco para seguir o takt da linha. Preencha quando um takt inteiro distorceria o balanceamento — uma inspeção que vale só uma fração dele. Dias são dias produtivos desta estação, então 1 dia equivale a um dia de takt.';

  @override
  String get stepProblemUnbound =>
      'Nenhum centro de trabalho ou pool selecionado.';

  @override
  String get stepProblemArchived =>
      'O centro de trabalho foi arquivado ou excluído.';

  @override
  String get stepProblemNoSchedule =>
      'Nenhum período de programação cobre este mês.';

  @override
  String get stepProblemEmptyPool => 'Este pool não tem membros.';

  @override
  String stepPoolMembers(String count) {
    return 'Pool · $count centros de trabalho';
  }

  @override
  String get inventoryModeQuantity => 'Peças';

  @override
  String get inventoryModeDuration => 'Espera fixa';

  @override
  String get inventoryPieces => 'Peças em espera';

  @override
  String get inventoryPiecesHelp =>
      'Contadas como dias de estoque: peças × takt do período exibido.';

  @override
  String get inventoryWait => 'Espera';

  @override
  String get inventoryWaitHelp =>
      'Aqui um dia são 24 horas. Se essas horas passam no relógio ou apenas enquanto a planta opera é o botão abaixo.';

  @override
  String get inventoryWorkingTime => 'Somente tempo útil';

  @override
  String get inventoryWorkingTimeHelp =>
      'Desligado para resfriamento ou transporte, que não param no fim de semana. Ligado para uma fila que só anda enquanto a planta opera.';

  @override
  String get footerProcessTime => 'Tempo de processo';

  @override
  String get footerLeadTime => 'Lead time';

  @override
  String get footerPce => 'PCE';

  @override
  String get footerEndDate => 'Data de término';

  @override
  String footerRunningDays(String days, String date) {
    return '$days dias corridos · $date';
  }

  @override
  String get footerEndDateHelp =>
      'Quando uma ordem iniciada no primeiro dia deste período terminaria, percorrendo os calendários reais. A diferença para o lead time são os fins de semana e as paradas.';

  @override
  String pdfGenerated(String build, String timestamp) {
    return 'FlowMap $build · gerado em $timestamp';
  }

  @override
  String pdfSaved(String path) {
    return 'Salvo em $path';
  }

  @override
  String get projectTabSimulation => 'Simulação';

  @override
  String get simulationRun => 'Simular';

  @override
  String get simulationRunning => 'Executando…';

  @override
  String get simulationDispatch => 'Despacho';

  @override
  String get simulationDispatchHelp =>
      'Como um centro de trabalho escolhe a próxima ordem em espera. Todas as regras desempatam por chegada, depois prioridade do estudo e depois sequência, então as mesmas entradas sempre produzem a mesma execução.';

  @override
  String get dispatchFifo => 'FIFO — por chegada';

  @override
  String get dispatchEarliestDueDate => 'Data de necessidade mais próxima';

  @override
  String get dispatchShortestProcessing => 'Menor tempo de processo';

  @override
  String simulationStudiesIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count estudos nesta execução',
      one: '1 estudo nesta execução',
      zero: 'Nenhum estudo selecionado',
    );
    return '$_temp0';
  }

  @override
  String get simulationNoStudies =>
      'Nenhum estudo está selecionado para simular';

  @override
  String get simulationNoStudiesHelp =>
      'Marque um estudo na barra lateral. Vários estudos de uma mesma linha são cenários de uma só realidade, então uma execução leva no máximo um de cada.';

  @override
  String get simulationNotReady => 'Não está pronto para simular';

  @override
  String get simProblemNoTakt =>
      'Nenhum período de takt cobre o dia em que esta execução começaria.';

  @override
  String get simProblemNoOrders =>
      'A sequência de demanda está vazia — não há o que liberar.';

  @override
  String get simProblemUnboundStep =>
      'Uma etapa não aponta para nenhum centro de trabalho, ou seu grupo está vazio.';

  @override
  String get simProblemNoPaceSetter =>
      'Nenhuma etapa pode ditar o ritmo das liberações: todas estão sem vínculo.';

  @override
  String get simulationNeverRun => 'Ainda não há nenhuma execução';

  @override
  String get simulationNeverRunHelp =>
      'Simular executa todos os estudos selecionados contra um único modelo da planta, de modo que as ordens de uma linha realmente atrasam as de outra.';

  @override
  String simulationAbortHorizon(String count) {
    return 'A demanda excede a capacidade. $count ordens nunca foram concluídas, e a execução foi abandonada em vez de seguir indefinidamente.';
  }

  @override
  String get simulationAbortNothingToRun =>
      'Nada pôde começar: o calendário de todas as estações está fechado, ou nenhum estudo tinha uma primeira ordem custeável.';

  @override
  String get simOnTimeDelivery => 'Entregas no prazo';

  @override
  String simOnTimeOfOrders(String onTime, String orders) {
    return '$onTime de $orders ordens no prazo';
  }

  @override
  String get simOnTimeHelp =>
      'Contado sobre todas as ordens, não apenas as entregues: uma ordem que nunca saiu não está no prazo, diga o que disser a data de necessidade.';

  @override
  String get simDelivered => 'Entregues';

  @override
  String simDeliveredOf(String delivered, String orders) {
    return '$delivered de $orders';
  }

  @override
  String get simAverageFloat => 'Folga média';

  @override
  String get simAverageFloatHelp =>
      'Data de necessidade menos entrega, na média das ordens que terminaram. Positivo é adiantado, com essa margem a favor; negativo é esse atraso. Uma ordem não entregue não tem folga e fica de fora daqui; acima ela continua contando como atrasada.';

  @override
  String get simAverageLeadTime => 'Lead time médio';

  @override
  String get simAverageLeadTimeHelp =>
      'Tempo de relógio dentro do fluxo, da liberação até a última etapa.';

  @override
  String get simTheoreticalLeadTime => 'Lead time teórico';

  @override
  String get simTheoreticalLeadTimeHelp =>
      'As mesmas ordens sem filas, cada uma percorrida desde sua própria liberação pelos calendários reais. Exclui o setup, que depende do que rodou antes e não é propriedade da peça.';

  @override
  String get simLeadTimeEfficiency => 'Eficiência do lead time';

  @override
  String get simLeadTimeEfficiencyHelp =>
      'Real ÷ teórico. 1,0 é sem filas e mais alto é pior; o excesso sobre 1,0 é exatamente a espera.';

  @override
  String get simEmptySlots => 'Janelas de liberação vazias';

  @override
  String get simEmptySlotsHelp =>
      'Janelas que chegaram sem nada para colocar nelas: a cabeça da sequência ainda não tinha material, ou o fluxo já estava no limite de WIP. A sequência é o que está sob estudo, então uma janela vazia é contada em vez de consertada em silêncio.';

  @override
  String get simByQueue => 'Ordenado por tempo em fila';

  @override
  String get simByShare => 'Ordenado por peso no fluxo';

  @override
  String get simRankingsHelp =>
      'As duas classificações estão aqui porque a discordância entre elas é o diagnóstico: uma fila longa numa estação pouco ocupada é problema de sequenciamento, não de capacidade.';

  @override
  String get simQueue => 'Fila';

  @override
  String get simQueueAverage => 'Fila média';

  @override
  String get simVisits => 'Visitas';

  @override
  String get simChangeovers => 'Setups';

  @override
  String get utilisation => 'Utilização';

  @override
  String get simUtilisationHelp =>
      'Tempo ocupado ÷ tempo aberto observado nesta execução. Não é o mesmo que ocupação, que é requerido ÷ disponível antes de simular: onde as duas discordam, o sequenciamento ou a falta de alimentação atrapalhou.';

  @override
  String get simContributed => 'Fila + processo';

  @override
  String get simShareOfFlow => 'Peso no fluxo';

  @override
  String get simPerPart => 'Por número de peça';

  @override
  String get simOrders => 'Ordens';

  @override
  String get simOnTime => 'No prazo';

  @override
  String get simNothingRanked => 'Nenhuma estação executou nada.';

  @override
  String simRunSpan(String start, String end) {
    return '$start → $end';
  }

  @override
  String get simEarlierRuns => 'Execuções anteriores';

  @override
  String simRunLabel(String timestamp, String rule) {
    return '$timestamp · $rule';
  }

  @override
  String get simRunDeleteBody =>
      'A execução e tudo o que ela registrou são apagados. Os estudos com que foi feita ficam intactos.';
}
