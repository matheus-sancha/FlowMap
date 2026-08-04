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
