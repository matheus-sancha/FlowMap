// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'studies_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(studiesRepository)
final studiesRepositoryProvider = StudiesRepositoryProvider._();

final class StudiesRepositoryProvider
    extends
        $FunctionalProvider<
          StudiesRepository,
          StudiesRepository,
          StudiesRepository
        >
    with $Provider<StudiesRepository> {
  StudiesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'studiesRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$studiesRepositoryHash();

  @$internal
  @override
  $ProviderElement<StudiesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  StudiesRepository create(Ref ref) {
    return studiesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StudiesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StudiesRepository>(value),
    );
  }
}

String _$studiesRepositoryHash() => r'c827a101309f16eb309033c4ac75dfa906173efc';
