// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mm3_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The scope MM3 is measured over, chosen by the user.
///
/// Kept separate from the series so switching scope does not reassemble the
/// steps — and so "not chosen yet" can resolve to the busiest station rather
/// than to a stored id that may no longer be in the flow.

@ProviderFor(Mm3ScopeSelection)
final mm3ScopeSelectionProvider = Mm3ScopeSelectionFamily._();

/// The scope MM3 is measured over, chosen by the user.
///
/// Kept separate from the series so switching scope does not reassemble the
/// steps — and so "not chosen yet" can resolve to the busiest station rather
/// than to a stored id that may no longer be in the flow.
final class Mm3ScopeSelectionProvider
    extends $NotifierProvider<Mm3ScopeSelection, String?> {
  /// The scope MM3 is measured over, chosen by the user.
  ///
  /// Kept separate from the series so switching scope does not reassemble the
  /// steps — and so "not chosen yet" can resolve to the busiest station rather
  /// than to a stored id that may no longer be in the flow.
  Mm3ScopeSelectionProvider._({
    required Mm3ScopeSelectionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'mm3ScopeSelectionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mm3ScopeSelectionHash();

  @override
  String toString() {
    return r'mm3ScopeSelectionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  Mm3ScopeSelection create() => Mm3ScopeSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Mm3ScopeSelectionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mm3ScopeSelectionHash() => r'28a0ab1efb842df0562314aeb73c6d5fc18baa26';

/// The scope MM3 is measured over, chosen by the user.
///
/// Kept separate from the series so switching scope does not reassemble the
/// steps — and so "not chosen yet" can resolve to the busiest station rather
/// than to a stored id that may no longer be in the flow.

final class Mm3ScopeSelectionFamily extends $Family
    with
        $ClassFamilyOverride<
          Mm3ScopeSelection,
          String?,
          String?,
          String?,
          String
        > {
  Mm3ScopeSelectionFamily._()
    : super(
        retry: null,
        name: r'mm3ScopeSelectionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The scope MM3 is measured over, chosen by the user.
  ///
  /// Kept separate from the series so switching scope does not reassemble the
  /// steps — and so "not chosen yet" can resolve to the busiest station rather
  /// than to a stored id that may no longer be in the flow.

  Mm3ScopeSelectionProvider call(String studyId) =>
      Mm3ScopeSelectionProvider._(argument: studyId, from: this);

  @override
  String toString() => r'mm3ScopeSelectionProvider';
}

/// The scope MM3 is measured over, chosen by the user.
///
/// Kept separate from the series so switching scope does not reassemble the
/// steps — and so "not chosen yet" can resolve to the busiest station rather
/// than to a stored id that may no longer be in the flow.

abstract class _$Mm3ScopeSelection extends $Notifier<String?> {
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
