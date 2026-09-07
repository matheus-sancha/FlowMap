// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'studies_pane.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(StudiesPaneCollapsed)
final studiesPaneCollapsedProvider = StudiesPaneCollapsedProvider._();

final class StudiesPaneCollapsedProvider
    extends $NotifierProvider<StudiesPaneCollapsed, bool> {
  StudiesPaneCollapsedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'studiesPaneCollapsedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$studiesPaneCollapsedHash();

  @$internal
  @override
  StudiesPaneCollapsed create() => StudiesPaneCollapsed();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$studiesPaneCollapsedHash() =>
    r'30e3220a8e7746054f09e34a6b3708cdcbc61d88';

abstract class _$StudiesPaneCollapsed extends $Notifier<bool> {
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
