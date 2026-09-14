// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'projects_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(projectsRepository)
final projectsRepositoryProvider = ProjectsRepositoryProvider._();

final class ProjectsRepositoryProvider
    extends
        $FunctionalProvider<
          ProjectsRepository,
          ProjectsRepository,
          ProjectsRepository
        >
    with $Provider<ProjectsRepository> {
  ProjectsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'projectsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$projectsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProjectsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProjectsRepository create(Ref ref) {
    return projectsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProjectsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProjectsRepository>(value),
    );
  }
}

String _$projectsRepositoryHash() =>
    r'c17ea1de10b31a0163442f4ce752ed310d31af61';

@ProviderFor(plantMove)
final plantMoveProvider = PlantMoveProvider._();

final class PlantMoveProvider
    extends $FunctionalProvider<PlantMove, PlantMove, PlantMove>
    with $Provider<PlantMove> {
  PlantMoveProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'plantMoveProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$plantMoveHash();

  @$internal
  @override
  $ProviderElement<PlantMove> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PlantMove create(Ref ref) {
    return plantMove(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlantMove value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlantMove>(value),
    );
  }
}

String _$plantMoveHash() => r'd873e0d0bf9ef3c87e5402751e3649c3d9964074';
