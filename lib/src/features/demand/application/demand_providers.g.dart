// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'demand_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(demandRepository)
final demandRepositoryProvider = DemandRepositoryProvider._();

final class DemandRepositoryProvider
    extends
        $FunctionalProvider<
          DemandRepository,
          DemandRepository,
          DemandRepository
        >
    with $Provider<DemandRepository> {
  DemandRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'demandRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$demandRepositoryHash();

  @$internal
  @override
  $ProviderElement<DemandRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DemandRepository create(Ref ref) {
    return demandRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DemandRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DemandRepository>(value),
    );
  }
}

String _$demandRepositoryHash() => r'd82f4c36da777c6dbf94c6b890849c40d991b336';

/// The part whose numbers the map shows under [FlowDataSource.singlePart].
///
/// Null means "the first one", resolved where the list is known — keeping a
/// concrete id here would go stale the moment that part was deleted.

@ProviderFor(SelectedDemandPart)
final selectedDemandPartProvider = SelectedDemandPartFamily._();

/// The part whose numbers the map shows under [FlowDataSource.singlePart].
///
/// Null means "the first one", resolved where the list is known — keeping a
/// concrete id here would go stale the moment that part was deleted.
final class SelectedDemandPartProvider
    extends $NotifierProvider<SelectedDemandPart, String?> {
  /// The part whose numbers the map shows under [FlowDataSource.singlePart].
  ///
  /// Null means "the first one", resolved where the list is known — keeping a
  /// concrete id here would go stale the moment that part was deleted.
  SelectedDemandPartProvider._({
    required SelectedDemandPartFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'selectedDemandPartProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$selectedDemandPartHash();

  @override
  String toString() {
    return r'selectedDemandPartProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SelectedDemandPart create() => SelectedDemandPart();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SelectedDemandPartProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$selectedDemandPartHash() =>
    r'b040e2f493fe03f6f7df5127e2c578a3e885ba26';

/// The part whose numbers the map shows under [FlowDataSource.singlePart].
///
/// Null means "the first one", resolved where the list is known — keeping a
/// concrete id here would go stale the moment that part was deleted.

final class SelectedDemandPartFamily extends $Family
    with
        $ClassFamilyOverride<
          SelectedDemandPart,
          String?,
          String?,
          String?,
          String
        > {
  SelectedDemandPartFamily._()
    : super(
        retry: null,
        name: r'selectedDemandPartProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The part whose numbers the map shows under [FlowDataSource.singlePart].
  ///
  /// Null means "the first one", resolved where the list is known — keeping a
  /// concrete id here would go stale the moment that part was deleted.

  SelectedDemandPartProvider call(String studyId) =>
      SelectedDemandPartProvider._(argument: studyId, from: this);

  @override
  String toString() => r'selectedDemandPartProvider';
}

/// The part whose numbers the map shows under [FlowDataSource.singlePart].
///
/// Null means "the first one", resolved where the list is known — keeping a
/// concrete id here would go stale the moment that part was deleted.

abstract class _$SelectedDemandPart extends $Notifier<String?> {
  late final _$args = ref.$arg as String;
  String get studyId => _$args;

  String? build(String studyId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
