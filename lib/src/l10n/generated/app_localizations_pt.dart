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
  String get studyTabCapacity => 'Capacidade';

  @override
  String get exceptionsScope =>
      'Aplica-se ao projeto inteiro — a todos os seus estudos.';

  @override
  String get navExceptions => 'Exceções';

  @override
  String get calendarExceptions => 'Exceções';

  @override
  String get schedulesTaktScope =>
      'compartilhado por todos os estudos desta linha';

  @override
  String get schedulesStationsScope => 'o fluxo deste estudo';

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
  String get projectDeleteBody =>
      'Os estudos, programações e fluxos vão junto. Isso não pode ser desfeito.';

  @override
  String get study => 'Estudo';

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
  String get studiesCollapse => 'Ocultar a lista de estudos';

  @override
  String get studiesExpand => 'Mostrar a lista de estudos';

  @override
  String get studyTabSettings => 'Definições do estudo';

  @override
  String get studyTabTakt => 'Takt do fluxo';

  @override
  String get studySettingsIdentity => 'Identidade';

  @override
  String get studySettingsInRuns => 'Na simulação';

  @override
  String get studyName => 'Nome';

  @override
  String get studyLine => 'Linha de produção';

  @override
  String get studyIncludeInRuns => 'Incluir nas corridas';

  @override
  String get studyIncludeInRunsHelp =>
      'Uma corrida toma todos os estudos incluídos ao mesmo tempo, disputando a mesma fábrica.';

  @override
  String get studyWipCap => 'Limite de WIP';

  @override
  String get studyWipCapUnlimited => 'Sem limite';

  @override
  String get studyWipCapHelp =>
      'O máximo de ordens que este estudo pode ter no fluxo ao mesmo tempo. Uma liberação espera por uma conclusão, que é o que torna o fluxo puxado em vez de empurrado. Em branco é sem limite.';

  @override
  String get studyPriority => 'Prioridade';

  @override
  String get studyPriorityHelp =>
      'Qual estudo ganha quando dois querem o mesmo centro de trabalho no mesmo instante. O menor vai primeiro. Apenas desempata — nunca reordena uma fila por si só.';

  @override
  String get studyTabFlow => 'Fluxo';

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
  String get validationPositiveNumber => 'Um número maior que zero';

  @override
  String get validationUnknownUnit =>
      'Não é uma unidade — tente dias, horas, min ou s';

  @override
  String get validationNotAPercentage => 'Uma percentagem entre 0 e 100';

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
  String get demandBatchSize => 'Tamanho do lote';

  @override
  String get demandBatchNumber => 'N.º do lote';

  @override
  String get demandBatchNumberHelp =>
      'Seu próprio identificador para este lote desta peça — como a papelada o chamar. Texto livre: nada faz correspondência por ele, repetidos são permitidos e pode ficar em branco. Aparece no plano de produção para que uma ordem impressa seja encontrada no seu sistema.';

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
  String get flowSourceEquivalent => 'Equivalente do fluxo';

  @override
  String get flowSourceSinglePart => 'Um item (requer demanda)';

  @override
  String get flowSourceWeighted =>
      'Todas as variantes, ponderadas (requer demanda)';

  @override
  String get exportPdf => 'Exportar PDF';

  @override
  String get flowShowing => 'Mostrando';

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
  String get flowStep => 'Etapa de processo';

  @override
  String get flowStepTarget => 'Centro de trabalho ou pool';

  @override
  String get flowStepTargetHelp =>
      'Uma etapa executa em exatamente um. Um pool envia cada ordem para o membro que ficar livre primeiro.';

  @override
  String get flowNodeLabel => 'Rótulo';

  @override
  String get flowNodeNotes => 'Notas';

  @override
  String get flowNodeHasNotes => 'Tem notas';

  @override
  String get flowMoveLeft => 'Mover para antes';

  @override
  String get flowMoveRight => 'Mover para depois';

  @override
  String get flowDeleteNodeTitle => 'Remover este nó do fluxo?';

  @override
  String get stepProcessTime => 'Tempo de processo';

  @override
  String get stepSetup => 'Preparação';

  @override
  String get stepTeardown => 'Desmontagem';

  @override
  String get stepTeardownHelp =>
      'Desmontar a estação depois de uma ordem. Cobrada junto com a preparação da ordem seguinte, porque se é necessária depende do que vem a seguir.';

  @override
  String get stepSamePart => 'Mesma peça';

  @override
  String get stepSamePartHelp =>
      'Quanto da preparação e da desmontagem ainda é cobrado quando a ordem anterior era da mesma peça. 0% torna uma repetição gratuita; 100% significa que agrupar não economiza nada.';

  @override
  String get stepChangeover => 'Troca';

  @override
  String get laneCapacity => 'Capacidade da pista (ordens)';

  @override
  String get laneCapacityHelp =>
      'Quantas ordens cabem aqui. Deixe em branco para ilimitado. Quando está cheia, a estação anterior não consegue largar a ordem terminada e para, que é como o congestionamento sobe pela linha. Diferente das peças acima: aquele número é o que está aqui hoje, este é o que o chão permite.';

  @override
  String get workcenterParallelCapacity => 'Ordens ao mesmo tempo';

  @override
  String get workcenterParallelCapacityHelp =>
      'Quantas ordens esta estação processa em paralelo. Uma é uma única máquina. Acima de uma são unidades independentes, cada uma pagando suas próprias trocas de referência — e o dobro da capacidade em tudo que é medido. Use um pool quando as máquinas forem realmente separadas e você quiser ver qual fez o quê.';

  @override
  String get studyRunSettings => 'Ajustes da simulação';

  @override
  String get studyStartBuffer => 'Margem de início (dias corridos)';

  @override
  String get studyStartBufferHelp =>
      'Margem adicional antes do início calculado. Uma simulação começa na data de necessidade da primeira ordem, menos o lead time teórico dela, menos isto. Dias corridos, porque atrasos acontecem com a planta aberta ou não.';

  @override
  String get studyPaceSetter => 'Marca-passo';

  @override
  String get studyPaceSetterHelp =>
      'A estação cujo relógio define a cadência de liberação, e cuja pista decide quando outra ordem pode entrar. Deixe em automático para usar a etapa mais carregada.';

  @override
  String get studyPaceSetterAutomatic => 'Automático — a etapa mais carregada';

  @override
  String get simBlocked => 'Bloqueado';

  @override
  String get simBlockedHelp =>
      'Tempo que a estação passou segurando uma ordem terminada porque a pista seguinte estava cheia. Não conta como ocupado: uma estação travada está ocupada e não produz nada.';

  @override
  String get simEmptySlotLaneFull => 'Pista cheia';

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
  String get footerProcessTime => 'Tempo de processo';

  @override
  String get footerLeadTime => 'Lead time (dias úteis)';

  @override
  String get footerLeadTimeRunning => 'Lead time (dias corridos)';

  @override
  String get footerLeadTimeRunningHelp =>
      'O lead time em dias úteis × 1,4, a convenção usual de sete sobre cinco. É um número de planeamento, não uma medição: uma simulação percorre o calendário real de cada centro de trabalho, portanto os dois podem divergir e a corrida é o que aconteceu.';

  @override
  String get footerPce => 'Eficiência de processo';

  @override
  String exportGenerated(String build, String timestamp) {
    return 'FlowMap $build · gerado em $timestamp';
  }

  @override
  String exportSaved(String path) {
    return 'Salvo em $path';
  }

  @override
  String get simFilterStudies => 'Estudos';

  @override
  String get simFilterCells => 'Células';

  @override
  String get simFilterLines => 'Linhas';

  @override
  String get simFilterPeriod => 'Período';

  @override
  String get simFilterPeriodHelp =>
      'Seleciona as ordens pela data de necessidade — a única das datas de uma ordem que nunca está vazia, portanto uma ordem que a corrida nunca completou continua a aparecer no seu período. A utilização e o tempo bloqueado dos centros continuam a descrever a corrida inteira, porque a corrida não guarda o que seria preciso para os limitar.';

  @override
  String get simFilterAll => 'todos';

  @override
  String get simFilterProjects => 'Projetos';

  @override
  String get simFilterParts => 'Números de peça';

  @override
  String get simFilterOrders => 'Ordens';

  @override
  String get simFilterOrdersHint => 'ex.: 5, 12';

  @override
  String get simFilterNoProject => '(sem projeto)';

  @override
  String simFilterOrdersEachStudy(int count) {
    return 'Os números de ordem se repetem em cada estudo — há $count estudos à vista';
  }

  @override
  String get simFilterClear => 'Limpar filtros';

  @override
  String get simWorkspace => 'Simulação';

  @override
  String get simStationsWholeRun =>
      'Utilização e Bloqueado descrevem a corrida inteira — a corrida não guarda o que seria preciso para limitar o tempo aberto. As demais colunas seguem o filtro.';

  @override
  String get simulationRun => 'Simular';

  @override
  String get simulationRunning => 'Executando…';

  @override
  String get simulationRunSettings => 'Configurações da execução';

  @override
  String get dispatchFifo => 'FIFO — por chegada';

  @override
  String get dispatchLifo => 'LIFO';

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
      'Data de necessidade menos fim da ordem, na média das ordens que terminaram. Positivo é adiantado, com essa margem a favor; negativo é esse atraso. Uma ordem que nunca terminou não tem folga e fica de fora daqui; acima ela continua contando como atrasada.';

  @override
  String get simAverageLeadTime => 'Lead time médio';

  @override
  String get simAverageLeadTimeHelp =>
      'Tempo de relógio dentro do fluxo, da liberação até a última etapa.';

  @override
  String get simTheoreticalLeadTime => 'Lead time teórico';

  @override
  String get simTheoreticalLeadTimeHelp =>
      'O que estas ordens levariam atravessando a planta como ela está — o trabalho, um setup completo em cada etapa e o estoque parado em cada fila — percorrido desde a liberação de cada ordem pelos calendários reais.';

  @override
  String get simLeadTimeEfficiency => 'Eficiência do lead time';

  @override
  String get simLeadTimeEfficiencyHelp =>
      'Teórico ÷ real. Acima de 100% o fluxo esperou menos do que o padrão prevê; abaixo de 100% esperou mais. As ordens de aquecimento — liberadas antes da primeira entrega da sua linha, quando o fluxo ainda estava vazio — ficam de fora.';

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
  String get utilization => 'Utilização';

  @override
  String get simUtilizationHelp =>
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
  String get simViewResults => 'Ver resultados';

  @override
  String get simulationRunFailed => 'Não foi possível concluir a simulação';

  @override
  String get simProductionPlan =>
      'Plano de produção — ordens ao longo do tempo';

  @override
  String get simProductionPlanHelp =>
      'O que esta simulação diz que cada ordem faz. As linhas seguem a ordem da sequência, que é também a ordem de liberação: o motor libera sempre a partir do início da sequência e nunca a reordena. Colunas em branco são de uma simulação anterior ao registro delas.';

  @override
  String get simPlanOrder => 'Ordem';

  @override
  String get simPlanOrderStart => 'Início';

  @override
  String get simPlanOrderEnd => 'Fim';

  @override
  String get simPlanTheoreticalLeadTime => 'LT teórico';

  @override
  String get simPlanActualLeadTime => 'LT real';

  @override
  String get simPlanLeadTimeEfficiency => 'Eficiência';

  @override
  String get simRunQueuesMixed => 'misto';

  @override
  String simRunQueueRow(String name, String rule) {
    return '$name: $rule';
  }

  @override
  String get simRunDeleteBody =>
      'A execução e tudo o que ela registrou são apagados. Os estudos com que foi feita ficam intactos.';

  @override
  String get simResultsView => 'Resultados';

  @override
  String get simGanttView => 'Gantt';

  @override
  String get simGanttEmpty =>
      'Esta execução não registrou nenhum passo, então não há o que desenhar.';

  @override
  String get simGanttGapHelp =>
      'Uma linha por estação, uma barra por ordem, todos os estudos juntos: uma estação é compartilhada, então separar o gráfico por estudo a desenharia parada enquanto processava a ordem de outra linha. Uma barra é a estação comprometida com aquela ordem, incluindo as horas fechadas. Um vão é uma estação que não está processando: fechada ou sem material. Quanto desse vão estava sequer aberto é respondido na tabela de filas.';

  @override
  String simGanttOrder(String number) {
    return 'Ordem $number';
  }

  @override
  String get simGanttProject => 'Projeto';

  @override
  String get simGanttCommitted => 'Comprometida';

  @override
  String get simGanttWaited => 'Espera antes de começar';

  @override
  String get simGanttChangeover => 'Houve troca de referência para começá-la';

  @override
  String simScheduleTail(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count pedidos terminaram depois de $date usando o último calendário definido',
      one:
          '1 pedido terminou depois de $date usando o último calendário definido',
    );
    return '$_temp0';
  }

  @override
  String get simScheduleTailHelp =>
      'Os períodos de takt e de calendário dos centros de trabalho terminam nessa data, então a simulação prolongou o último para além dela. Não é um erro — uma simulação corre até o último pedido terminar — mas os números depois dessa data descrevem uma capacidade que ninguém definiu. Estenda os períodos e simule de novo para confirmá-los.';

  @override
  String get settingsDisplay => 'Apresentação';

  @override
  String get settingsDateFormatHelp =>
      'Como as datas são escritas e lidas em toda a aplicação, incluindo a exportação para Excel. Independente do idioma da interface. Datas ISO são sempre aceitas ao digitar, qualquer que seja o formato escolhido.';

  @override
  String get dateFormatLocale => 'Seguir o idioma do sistema';

  @override
  String get dateFormatDayMonthYear => 'Dia/mês/ano';

  @override
  String get dateFormatMonthDayYear => 'Mês/dia/ano';

  @override
  String get dateFormatIso => 'Ano-mês-dia (ISO)';

  @override
  String simGanttLaneHolds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'A pista comporta $count pedidos',
      one: 'A pista comporta 1 pedido',
    );
    return '$_temp0';
  }

  @override
  String get simGanttLaneUncapped => 'A pista não tem limite';

  @override
  String get simGanttStillWaiting =>
      'Ainda estava aqui ao terminar a simulação';

  @override
  String get simGanttRowsStations => 'Centros';

  @override
  String get simGanttRowsWithLanes => 'Centros + carris';

  @override
  String get simGanttRowsHelp =>
      'Se as faixas de fila entre centros são desenhadas. Sem elas o gráfico lê-se como um fluxo; com elas, como uma fila.';

  @override
  String get simGanttZoomIn => 'Aproximar';

  @override
  String get simGanttZoomOut => 'Afastar';

  @override
  String simGanttFloored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count barras desenhadas mais largas do que são',
      one: '1 barra desenhada mais larga do que é',
    );
    return '$_temp0';
  }

  @override
  String get simGanttFlooredHelp =>
      'Neste zoom esses passos são mais finos que um pixel, então são desenhados na largura mínima para continuarem visíveis. A posição é exata; a largura não. Ao aproximar, o aviso some.';

  @override
  String get exportExcel => 'Exportar para Excel';

  @override
  String get simExportRunSheet => 'Execução';

  @override
  String get flowQueueEdit => 'Definir a fila diante deste passo';

  @override
  String flowQueueTitle(String target) {
    return 'Fila diante de $target';
  }

  @override
  String flowQueueShared(String target) {
    return 'Uma fila por estação: todos os passos que alimentam $target esperam nesta, neste estudo e nos outros.';
  }

  @override
  String get flowQueueName => 'Nome';

  @override
  String get flowQueueType => 'Tipo de fila';

  @override
  String get flowQueueTypeHelp =>
      'Como a estação seguinte escolhe a próxima ordem desta fila. Um empurre é uma pilha à qual ninguém deu uma ordem; as quatro regras são canais, e o mapa desenha cada uma diferente.';

  @override
  String get flowQueueStock => 'O que está aqui agora';

  @override
  String get queueTypePush => 'Empurre — uma pilha, sem regra';

  @override
  String get queueTypeSupermarket => 'Supermercado — ainda não';

  @override
  String get flowBatchHelp =>
      'Quantas peças cada caixa custa. Os tempos de processo são por peça, então uma ordem de dez ocupa a estação dez vezes mais — que é o que a simulação cobra. Deixe vazio para seguir as ordens que esta peça tem.';

  @override
  String get validationNumber => 'Digite um número';

  @override
  String get validationAboveZero => 'Digite um número maior que zero';

  @override
  String get simEmptySlotAwaitingMaterial => 'Aguardando material';

  @override
  String get simEmptySlotWipCap => 'Limite de WIP atingido';

  @override
  String get flowEndStockInbound => 'Estoque de matéria-prima';

  @override
  String get flowEndStockOutbound => 'Estoque de produto acabado';

  @override
  String get flowEndStockEdit => 'Definir o estoque nesta extremidade do fluxo';

  @override
  String get flowEndStockQuantity => 'Peças paradas aqui';

  @override
  String get flowEndStockHelp =>
      'Uma observação do que está hoje no chão de fábrica, em peças, mostrada como dias pelo takt do período em tela. Conta para o lead time e para os dias de estoque, e nada é despachado a partir dele: os pedidos são liberados por takt, não retirados de uma prateleira. Deixe em branco se ninguém contou.';

  @override
  String get flowEndStockNone => 'Não contado';

  @override
  String get flowEndStockDays => 'Dias de estoque';

  @override
  String get stepBalancedMark => '⇄';

  @override
  String stepBalancedHelp(String type, String measured) {
    return 'Reequilibrado entre as estações de $type vizinhas neste fluxo: cada uma enche até o seu takt e a última fica com o resto, então mudar o takt move a divisão sem nenhuma outra edição. Aqui foram medidos $measured, e a tabela de demanda continua guardando esse valor.';
  }

  @override
  String get stepRebalance =>
      'Reequilibrar com máquinas vizinhas do mesmo tipo';

  @override
  String get stepRebalanceHelp =>
      'Estações do mesmo tipo lado a lado dividem o trabalho: cada uma enche até o seu takt e a última fica com o resto, então mudar o takt move a divisão sem nenhuma outra edição. Desligue para fixar esta estação no que foi medido nela.';

  @override
  String stepRebalanceNoType(String name) {
    return '$name não tem tipo de centro de trabalho, então nada diz que ela é igual às vizinhas.';
  }

  @override
  String stepRebalanceNoNeighbour(String type) {
    return 'Nenhum passo vizinho compartilha o tipo $type.';
  }

  @override
  String get stepRebalanceNoWork =>
      'Esta peça não tem tempo aqui, então a estação não divide trabalho.';

  @override
  String stepRebalanceOn(String type) {
    return 'Dividindo trabalho com as estações $type vizinhas.';
  }

  @override
  String simRunTakt(String takt) {
    return 'Executado com $takt';
  }

  @override
  String simRunTaktChanges(String date) {
    return 'O takt muda em $date, dentro do período desta execução.';
  }

  @override
  String get simRunTaktMixed => 'misto';

  @override
  String flowTaktChanges(String from, String to, String date, String shown) {
    return 'Takt $from → $to em $date — mostrando $shown';
  }
}
