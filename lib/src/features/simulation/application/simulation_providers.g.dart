// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'simulation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(simulationRepository)
final simulationRepositoryProvider = SimulationRepositoryProvider._();

final class SimulationRepositoryProvider
    extends
        $FunctionalProvider<
          SimulationRepository,
          SimulationRepository,
          SimulationRepository
        >
    with $Provider<SimulationRepository> {
  SimulationRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'simulationRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$simulationRepositoryHash();

  @$internal
  @override
  $ProviderElement<SimulationRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SimulationRepository create(Ref ref) {
    return simulationRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SimulationRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SimulationRepository>(value),
    );
  }
}

String _$simulationRepositoryHash() =>
    r'81a2513ba3c021528ad01de2593c51a000fc46b9';

@ProviderFor(simulationRunsRepository)
final simulationRunsRepositoryProvider = SimulationRunsRepositoryProvider._();

final class SimulationRunsRepositoryProvider
    extends
        $FunctionalProvider<
          SimulationRunsRepository,
          SimulationRunsRepository,
          SimulationRunsRepository
        >
    with $Provider<SimulationRunsRepository> {
  SimulationRunsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'simulationRunsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$simulationRunsRepositoryHash();

  @$internal
  @override
  $ProviderElement<SimulationRunsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SimulationRunsRepository create(Ref ref) {
    return simulationRunsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SimulationRunsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SimulationRunsRepository>(value),
    );
  }
}

String _$simulationRunsRepositoryHash() =>
    r'4d62fb559e545c30d9e05e157bc2b471942c6c34';

/// Which rule the workcenters dispatch by (§7.4).
///
/// Per project and held in memory, not stored: it is the knob the experiment
/// turns, and a run records the rule it was made with, so the answer to "what
/// did EDD do here" lives on the run rather than on the project.

@ProviderFor(DispatchRuleSelection)
final dispatchRuleSelectionProvider = DispatchRuleSelectionFamily._();

/// Which rule the workcenters dispatch by (§7.4).
///
/// Per project and held in memory, not stored: it is the knob the experiment
/// turns, and a run records the rule it was made with, so the answer to "what
/// did EDD do here" lives on the run rather than on the project.
final class DispatchRuleSelectionProvider
    extends $NotifierProvider<DispatchRuleSelection, DispatchRule> {
  /// Which rule the workcenters dispatch by (§7.4).
  ///
  /// Per project and held in memory, not stored: it is the knob the experiment
  /// turns, and a run records the rule it was made with, so the answer to "what
  /// did EDD do here" lives on the run rather than on the project.
  DispatchRuleSelectionProvider._({
    required DispatchRuleSelectionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'dispatchRuleSelectionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dispatchRuleSelectionHash();

  @override
  String toString() {
    return r'dispatchRuleSelectionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  DispatchRuleSelection create() => DispatchRuleSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DispatchRule value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DispatchRule>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DispatchRuleSelectionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dispatchRuleSelectionHash() =>
    r'747ed811674a2d7dabfe07acb317d09e34b62ae7';

/// Which rule the workcenters dispatch by (§7.4).
///
/// Per project and held in memory, not stored: it is the knob the experiment
/// turns, and a run records the rule it was made with, so the answer to "what
/// did EDD do here" lives on the run rather than on the project.

final class DispatchRuleSelectionFamily extends $Family
    with
        $ClassFamilyOverride<
          DispatchRuleSelection,
          DispatchRule,
          DispatchRule,
          DispatchRule,
          String
        > {
  DispatchRuleSelectionFamily._()
    : super(
        retry: null,
        name: r'dispatchRuleSelectionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Which rule the workcenters dispatch by (§7.4).
  ///
  /// Per project and held in memory, not stored: it is the knob the experiment
  /// turns, and a run records the rule it was made with, so the answer to "what
  /// did EDD do here" lives on the run rather than on the project.

  DispatchRuleSelectionProvider call(String projectId) =>
      DispatchRuleSelectionProvider._(argument: projectId, from: this);

  @override
  String toString() => r'dispatchRuleSelectionProvider';
}

/// Which rule the workcenters dispatch by (§7.4).
///
/// Per project and held in memory, not stored: it is the knob the experiment
/// turns, and a run records the rule it was made with, so the answer to "what
/// did EDD do here" lives on the run rather than on the project.

abstract class _$DispatchRuleSelection extends $Notifier<DispatchRule> {
  late final _$args = ref.$arg as String;
  String get projectId => _$args;

  DispatchRule build(String projectId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DispatchRule, DispatchRule>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DispatchRule, DispatchRule>,
              DispatchRule,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// The run being looked at, and the button that makes a new one.
///
/// Opening the tab shows the run that was last made rather than an empty
/// screen — most of what storing a run buys (§7.10). Pressing Simulate stores
/// a new one, the list stream emits, and this rebuilds onto it.

@ProviderFor(SimulationRunner)
final simulationRunnerProvider = SimulationRunnerFamily._();

/// The run being looked at, and the button that makes a new one.
///
/// Opening the tab shows the run that was last made rather than an empty
/// screen — most of what storing a run buys (§7.10). Pressing Simulate stores
/// a new one, the list stream emits, and this rebuilds onto it.
final class SimulationRunnerProvider
    extends $AsyncNotifierProvider<SimulationRunner, StoredRun?> {
  /// The run being looked at, and the button that makes a new one.
  ///
  /// Opening the tab shows the run that was last made rather than an empty
  /// screen — most of what storing a run buys (§7.10). Pressing Simulate stores
  /// a new one, the list stream emits, and this rebuilds onto it.
  SimulationRunnerProvider._({
    required SimulationRunnerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'simulationRunnerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$simulationRunnerHash();

  @override
  String toString() {
    return r'simulationRunnerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SimulationRunner create() => SimulationRunner();

  @override
  bool operator ==(Object other) {
    return other is SimulationRunnerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$simulationRunnerHash() => r'f3ba67a66060d06c08e7229e0a016067c7c7694a';

/// The run being looked at, and the button that makes a new one.
///
/// Opening the tab shows the run that was last made rather than an empty
/// screen — most of what storing a run buys (§7.10). Pressing Simulate stores
/// a new one, the list stream emits, and this rebuilds onto it.

final class SimulationRunnerFamily extends $Family
    with
        $ClassFamilyOverride<
          SimulationRunner,
          AsyncValue<StoredRun?>,
          StoredRun?,
          FutureOr<StoredRun?>,
          String
        > {
  SimulationRunnerFamily._()
    : super(
        retry: null,
        name: r'simulationRunnerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The run being looked at, and the button that makes a new one.
  ///
  /// Opening the tab shows the run that was last made rather than an empty
  /// screen — most of what storing a run buys (§7.10). Pressing Simulate stores
  /// a new one, the list stream emits, and this rebuilds onto it.

  SimulationRunnerProvider call(String projectId) =>
      SimulationRunnerProvider._(argument: projectId, from: this);

  @override
  String toString() => r'simulationRunnerProvider';
}

/// The run being looked at, and the button that makes a new one.
///
/// Opening the tab shows the run that was last made rather than an empty
/// screen — most of what storing a run buys (§7.10). Pressing Simulate stores
/// a new one, the list stream emits, and this rebuilds onto it.

abstract class _$SimulationRunner extends $AsyncNotifier<StoredRun?> {
  late final _$args = ref.$arg as String;
  String get projectId => _$args;

  FutureOr<StoredRun?> build(String projectId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<StoredRun?>, StoredRun?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<StoredRun?>, StoredRun?>,
              AsyncValue<StoredRun?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
