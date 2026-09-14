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
/// The flow equivalent is the default because it is the only one that needs no
/// demand: a study opens showing something true about its own capacity before
/// a single part has been typed.

@ProviderFor(FlowDataSourceSelection)
final flowDataSourceSelectionProvider = FlowDataSourceSelectionFamily._();

/// Which numbers the process boxes show.
///
/// The flow equivalent is the default because it is the only one that needs no
/// demand: a study opens showing something true about its own capacity before
/// a single part has been typed.
final class FlowDataSourceSelectionProvider
    extends $NotifierProvider<FlowDataSourceSelection, FlowDataSource> {
  /// Which numbers the process boxes show.
  ///
  /// The flow equivalent is the default because it is the only one that needs no
  /// demand: a study opens showing something true about its own capacity before
  /// a single part has been typed.
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
/// The flow equivalent is the default because it is the only one that needs no
/// demand: a study opens showing something true about its own capacity before
/// a single part has been typed.

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
  /// The flow equivalent is the default because it is the only one that needs no
  /// demand: a study opens showing something true about its own capacity before
  /// a single part has been typed.

  FlowDataSourceSelectionProvider call(String studyId) =>
      FlowDataSourceSelectionProvider._(argument: studyId, from: this);

  @override
  String toString() => r'flowDataSourceSelectionProvider';
}

/// Which numbers the process boxes show.
///
/// The flow equivalent is the default because it is the only one that needs no
/// demand: a study opens showing something true about its own capacity before
/// a single part has been typed.

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

/// A batch size typed on the Flow toolbar, or null to follow the demand table.
///
/// **Null is a real state rather than a missing one.** It means "whatever this
/// part's orders actually use", so switching parts follows the new part instead
/// of carrying the last one's lot across — and typing a number is the lot-sizing
/// experiment §7.6 says Batch Size exists to be. Held in memory per study, like
/// the period and the data source: it is a question being asked of the map, not
/// a property of the study.

@ProviderFor(FlowBatchOverride)
final flowBatchOverrideProvider = FlowBatchOverrideFamily._();

/// A batch size typed on the Flow toolbar, or null to follow the demand table.
///
/// **Null is a real state rather than a missing one.** It means "whatever this
/// part's orders actually use", so switching parts follows the new part instead
/// of carrying the last one's lot across — and typing a number is the lot-sizing
/// experiment §7.6 says Batch Size exists to be. Held in memory per study, like
/// the period and the data source: it is a question being asked of the map, not
/// a property of the study.
final class FlowBatchOverrideProvider
    extends $NotifierProvider<FlowBatchOverride, int?> {
  /// A batch size typed on the Flow toolbar, or null to follow the demand table.
  ///
  /// **Null is a real state rather than a missing one.** It means "whatever this
  /// part's orders actually use", so switching parts follows the new part instead
  /// of carrying the last one's lot across — and typing a number is the lot-sizing
  /// experiment §7.6 says Batch Size exists to be. Held in memory per study, like
  /// the period and the data source: it is a question being asked of the map, not
  /// a property of the study.
  FlowBatchOverrideProvider._({
    required FlowBatchOverrideFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'flowBatchOverrideProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$flowBatchOverrideHash();

  @override
  String toString() {
    return r'flowBatchOverrideProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  FlowBatchOverride create() => FlowBatchOverride();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FlowBatchOverrideProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$flowBatchOverrideHash() => r'679bf7a0b33e0c336c226578500b7fd1d0e299f0';

/// A batch size typed on the Flow toolbar, or null to follow the demand table.
///
/// **Null is a real state rather than a missing one.** It means "whatever this
/// part's orders actually use", so switching parts follows the new part instead
/// of carrying the last one's lot across — and typing a number is the lot-sizing
/// experiment §7.6 says Batch Size exists to be. Held in memory per study, like
/// the period and the data source: it is a question being asked of the map, not
/// a property of the study.

final class FlowBatchOverrideFamily extends $Family
    with $ClassFamilyOverride<FlowBatchOverride, int?, int?, int?, String> {
  FlowBatchOverrideFamily._()
    : super(
        retry: null,
        name: r'flowBatchOverrideProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A batch size typed on the Flow toolbar, or null to follow the demand table.
  ///
  /// **Null is a real state rather than a missing one.** It means "whatever this
  /// part's orders actually use", so switching parts follows the new part instead
  /// of carrying the last one's lot across — and typing a number is the lot-sizing
  /// experiment §7.6 says Batch Size exists to be. Held in memory per study, like
  /// the period and the data source: it is a question being asked of the map, not
  /// a property of the study.

  FlowBatchOverrideProvider call(String studyId) =>
      FlowBatchOverrideProvider._(argument: studyId, from: this);

  @override
  String toString() => r'flowBatchOverrideProvider';
}

/// A batch size typed on the Flow toolbar, or null to follow the demand table.
///
/// **Null is a real state rather than a missing one.** It means "whatever this
/// part's orders actually use", so switching parts follows the new part instead
/// of carrying the last one's lot across — and typing a number is the lot-sizing
/// experiment §7.6 says Batch Size exists to be. Held in memory per study, like
/// the period and the data source: it is a question being asked of the map, not
/// a property of the study.

abstract class _$FlowBatchOverride extends $Notifier<int?> {
  late final _$args = ref.$arg as String;
  String get studyId => _$args;

  int? build(String studyId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int?, int?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int?, int?>,
              int?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
