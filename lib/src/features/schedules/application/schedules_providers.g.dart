// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedules_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(schedulesRepository)
final schedulesRepositoryProvider = SchedulesRepositoryProvider._();

final class SchedulesRepositoryProvider
    extends
        $FunctionalProvider<
          SchedulesRepository,
          SchedulesRepository,
          SchedulesRepository
        >
    with $Provider<SchedulesRepository> {
  SchedulesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'schedulesRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$schedulesRepositoryHash();

  @$internal
  @override
  $ProviderElement<SchedulesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SchedulesRepository create(Ref ref) {
    return schedulesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SchedulesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SchedulesRepository>(value),
    );
  }
}

String _$schedulesRepositoryHash() =>
    r'4fd76ed9692817b477e1697ac75da9f6e58c47a0';
