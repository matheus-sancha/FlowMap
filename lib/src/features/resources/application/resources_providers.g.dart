// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'resources_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(resourcesRepository)
final resourcesRepositoryProvider = ResourcesRepositoryProvider._();

final class ResourcesRepositoryProvider
    extends
        $FunctionalProvider<
          ResourcesRepository,
          ResourcesRepository,
          ResourcesRepository
        >
    with $Provider<ResourcesRepository> {
  ResourcesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'resourcesRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$resourcesRepositoryHash();

  @$internal
  @override
  $ProviderElement<ResourcesRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ResourcesRepository create(Ref ref) {
    return resourcesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ResourcesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ResourcesRepository>(value),
    );
  }
}

String _$resourcesRepositoryHash() =>
    r'a9307a3be1047644316d9761020bfd21e6885417';

/// Whether archived resources are listed.
///
/// Archiving would otherwise be one-way: a row that leaves every list has no
/// affordance left to restore it. One toggle covers every list at once, which
/// is why the stream providers above all read it rather than taking a flag.

@ProviderFor(ShowArchived)
final showArchivedProvider = ShowArchivedProvider._();

/// Whether archived resources are listed.
///
/// Archiving would otherwise be one-way: a row that leaves every list has no
/// affordance left to restore it. One toggle covers every list at once, which
/// is why the stream providers above all read it rather than taking a flag.
final class ShowArchivedProvider extends $NotifierProvider<ShowArchived, bool> {
  /// Whether archived resources are listed.
  ///
  /// Archiving would otherwise be one-way: a row that leaves every list has no
  /// affordance left to restore it. One toggle covers every list at once, which
  /// is why the stream providers above all read it rather than taking a flag.
  ShowArchivedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'showArchivedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$showArchivedHash();

  @$internal
  @override
  ShowArchived create() => ShowArchived();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$showArchivedHash() => r'8ca5cd466f66d2933a096b54acfce368ce6a4b13';

/// Whether archived resources are listed.
///
/// Archiving would otherwise be one-way: a row that leaves every list has no
/// affordance left to restore it. One toggle covers every list at once, which
/// is why the stream providers above all read it rather than taking a flag.

abstract class _$ShowArchived extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The plant the Resources screen is showing.
///
/// A project specifies one plant (DESIGN.md §3), but Resources spans them all,
/// so the screen needs its own selection. Null means "the first one", resolved
/// where it is read so the initial load needs no write.

@ProviderFor(SelectedPlant)
final selectedPlantProvider = SelectedPlantProvider._();

/// The plant the Resources screen is showing.
///
/// A project specifies one plant (DESIGN.md §3), but Resources spans them all,
/// so the screen needs its own selection. Null means "the first one", resolved
/// where it is read so the initial load needs no write.
final class SelectedPlantProvider
    extends $NotifierProvider<SelectedPlant, String?> {
  /// The plant the Resources screen is showing.
  ///
  /// A project specifies one plant (DESIGN.md §3), but Resources spans them all,
  /// so the screen needs its own selection. Null means "the first one", resolved
  /// where it is read so the initial load needs no write.
  SelectedPlantProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedPlantProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedPlantHash();

  @$internal
  @override
  SelectedPlant create() => SelectedPlant();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$selectedPlantHash() => r'7554077022087c82e63f75f58661e845d62dc27a';

/// The plant the Resources screen is showing.
///
/// A project specifies one plant (DESIGN.md §3), but Resources spans them all,
/// so the screen needs its own selection. Null means "the first one", resolved
/// where it is read so the initial load needs no write.

abstract class _$SelectedPlant extends $Notifier<String?> {
  String? build();
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
    return element.handleCreate(ref, build);
  }
}
