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
  String get studyTabFlow => 'Fluxo';

  @override
  String get studyTabTakt => 'Takt';

  @override
  String get studyTabDemand => 'Demanda';

  @override
  String get studyTabSummary => 'Resumo';

  @override
  String get milestoneSummary => 'O resumo chega no próximo marco.';

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
  String get mm3NoSequence => 'Ainda não há pedidos na sequência.';

  @override
  String get mm3NotMeasurable =>
      'Nada a medir ainda: as peças desta sequência não têm tempos de processo neste escopo.';

  @override
  String get mm3Help =>
      'Uma média móvel centrada de três sobre a sequência, vazia nas duas pontas. Reordene na aba Sequência e veja achatar.';

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
}
