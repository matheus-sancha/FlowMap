// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flow_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The period the map is showing (`Aug 2026`, `Q3 2026`, `2026`).
///
/// Every derived number on the map is period-dependent — takt, staffing,
/// availability — so the map needs a span to be about. Kept per study so
/// switching between two studies does not reset the other's period.

@ProviderFor(ViewedPeriod)
final viewedPeriodProvider = ViewedPeriodFamily._();

/// The period the map is showing (`Aug 2026`, `Q3 2026`, `2026`).
///
/// Every derived number on the map is period-dependent — takt, staffing,
/// availability — so the map needs a span to be about. Kept per study so
/// switching between two studies does not reset the other's period.
final class ViewedPeriodProvider
    extends $NotifierProvider<ViewedPeriod, ViewedPeriodState> {
  /// The period the map is showing (`Aug 2026`, `Q3 2026`, `2026`).
  ///
  /// Every derived number on the map is period-dependent — takt, staffing,
  /// availability — so the map needs a span to be about. Kept per study so
  /// switching between two studies does not reset the other's period.
  ViewedPeriodProvider._({
    required ViewedPeriodFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'viewedPeriodProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$viewedPeriodHash();

  @override
  String toString() {
    return r'viewedPeriodProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ViewedPeriod create() => ViewedPeriod();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ViewedPeriodState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ViewedPeriodState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ViewedPeriodProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$viewedPeriodHash() => r'b95af39087717f6fed332070506923de1c88a329';

/// The period the map is showing (`Aug 2026`, `Q3 2026`, `2026`).
///
/// Every derived number on the map is period-dependent — takt, staffing,
/// availability — so the map needs a span to be about. Kept per study so
/// switching between two studies does not reset the other's period.

final class ViewedPeriodFamily extends $Family
    with
        $ClassFamilyOverride<
          ViewedPeriod,
          ViewedPeriodState,
          ViewedPeriodState,
          ViewedPeriodState,
          String
        > {
  ViewedPeriodFamily._()
    : super(
        retry: null,
        name: r'viewedPeriodProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The period the map is showing (`Aug 2026`, `Q3 2026`, `2026`).
  ///
  /// Every derived number on the map is period-dependent — takt, staffing,
  /// availability — so the map needs a span to be about. Kept per study so
  /// switching between two studies does not reset the other's period.

  ViewedPeriodProvider call(String studyId) =>
      ViewedPeriodProvider._(argument: studyId, from: this);

  @override
  String toString() => r'viewedPeriodProvider';
}

/// The period the map is showing (`Aug 2026`, `Q3 2026`, `2026`).
///
/// Every derived number on the map is period-dependent — takt, staffing,
/// availability — so the map needs a span to be about. Kept per study so
/// switching between two studies does not reset the other's period.

abstract class _$ViewedPeriod extends $Notifier<ViewedPeriodState> {
  late final _$args = ref.$arg as String;
  String get studyId => _$args;

  ViewedPeriodState build(String studyId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ViewedPeriodState, ViewedPeriodState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ViewedPeriodState, ViewedPeriodState>,
              ViewedPeriodState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

/// Which numbers the process boxes show.
///
/// Only [FlowDataSource.flowEquivalent] is computable until the demand table
/// lands (M3); the others are offered but disabled, so the shape of the choice
/// is visible from the start.

@ProviderFor(FlowDataSourceSelection)
final flowDataSourceSelectionProvider = FlowDataSourceSelectionFamily._();

/// Which numbers the process boxes show.
///
/// Only [FlowDataSource.flowEquivalent] is computable until the demand table
/// lands (M3); the others are offered but disabled, so the shape of the choice
/// is visible from the start.
final class FlowDataSourceSelectionProvider
    extends $NotifierProvider<FlowDataSourceSelection, FlowDataSource> {
  /// Which numbers the process boxes show.
  ///
  /// Only [FlowDataSource.flowEquivalent] is computable until the demand table
  /// lands (M3); the others are offered but disabled, so the shape of the choice
  /// is visible from the start.
  FlowDataSourceSelectionProvider._({
    required FlowDataSourceSelectionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'flowDataSourceSelectionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$flowDataSourceSelectionHash();

  @override
  String toString() {
    return r'flowDataSourceSelectionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  FlowDataSourceSelection create() => FlowDataSourceSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FlowDataSource value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FlowDataSource>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FlowDataSourceSelectionProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$flowDataSourceSelectionHash() =>
    r'ba85be665f26df1d873b0a21db653d19fd119435';

/// Which numbers the process boxes show.
///
/// Only [FlowDataSource.flowEquivalent] is computable until the demand table
/// lands (M3); the others are offered but disabled, so the shape of the choice
/// is visible from the start.

final class FlowDataSourceSelectionFamily extends $Family
    with
        $ClassFamilyOverride<
          FlowDataSourceSelection,
          FlowDataSource,
          FlowDataSource,
          FlowDataSource,
          String
        > {
  FlowDataSourceSelectionFamily._()
    : super(
        retry: null,
        name: r'flowDataSourceSelectionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Which numbers the process boxes show.
  ///
  /// Only [FlowDataSource.flowEquivalent] is computable until the demand table
  /// lands (M3); the others are offered but disabled, so the shape of the choice
  /// is visible from the start.

  FlowDataSourceSelectionProvider call(String studyId) =>
      FlowDataSourceSelectionProvider._(argument: studyId, from: this);

  @override
  String toString() => r'flowDataSourceSelectionProvider';
}

/// Which numbers the process boxes show.
///
/// Only [FlowDataSource.flowEquivalent] is computable until the demand table
/// lands (M3); the others are offered but disabled, so the shape of the choice
/// is visible from the start.

abstract class _$FlowDataSourceSelection extends $Notifier<FlowDataSource> {
  late final _$args = ref.$arg as String;
  String get studyId => _$args;

  FlowDataSource build(String studyId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<FlowDataSource, FlowDataSource>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FlowDataSource, FlowDataSource>,
              FlowDataSource,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
