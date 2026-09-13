// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'templates_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The templates folder, read from disk rather than from a table.
///
/// **Nothing records what is on the shelf.** A template is a file; dropping one
/// into the folder installs it and deleting it removes it, with no list to keep
/// in step. That is the same reason the recent-documents list is a convenience
/// and never a record.

@ProviderFor(templates)
final templatesProvider = TemplatesProvider._();

/// The templates folder, read from disk rather than from a table.
///
/// **Nothing records what is on the shelf.** A template is a file; dropping one
/// into the folder installs it and deleting it removes it, with no list to keep
/// in step. That is the same reason the recent-documents list is a convenience
/// and never a record.

final class TemplatesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TemplateOnDisk>>,
          List<TemplateOnDisk>,
          FutureOr<List<TemplateOnDisk>>
        >
    with
        $FutureModifier<List<TemplateOnDisk>>,
        $FutureProvider<List<TemplateOnDisk>> {
  /// The templates folder, read from disk rather than from a table.
  ///
  /// **Nothing records what is on the shelf.** A template is a file; dropping one
  /// into the folder installs it and deleting it removes it, with no list to keep
  /// in step. That is the same reason the recent-documents list is a convenience
  /// and never a record.
  TemplatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'templatesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$templatesHash();

  @$internal
  @override
  $FutureProviderElement<List<TemplateOnDisk>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<TemplateOnDisk>> create(Ref ref) {
    return templates(ref);
  }
}

String _$templatesHash() => r'2abffe37999a520848237cfa5be3ecc92d09548d';

/// Saves one study from the open document as a template.

@ProviderFor(saveStudyAsTemplate)
final saveStudyAsTemplateProvider = SaveStudyAsTemplateFamily._();

/// Saves one study from the open document as a template.

final class SaveStudyAsTemplateProvider
    extends $FunctionalProvider<AsyncValue<File>, File, FutureOr<File>>
    with $FutureModifier<File>, $FutureProvider<File> {
  /// Saves one study from the open document as a template.
  SaveStudyAsTemplateProvider._({
    required SaveStudyAsTemplateFamily super.from,
    required ({String studyId, bool includeDemand}) super.argument,
  }) : super(
         retry: null,
         name: r'saveStudyAsTemplateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$saveStudyAsTemplateHash();

  @override
  String toString() {
    return r'saveStudyAsTemplateProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<File> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<File> create(Ref ref) {
    final argument = this.argument as ({String studyId, bool includeDemand});
    return saveStudyAsTemplate(
      ref,
      studyId: argument.studyId,
      includeDemand: argument.includeDemand,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SaveStudyAsTemplateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$saveStudyAsTemplateHash() =>
    r'371631bbff2c243994579386a067b82a218b39ae';

/// Saves one study from the open document as a template.

final class SaveStudyAsTemplateFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<File>,
          ({String studyId, bool includeDemand})
        > {
  SaveStudyAsTemplateFamily._()
    : super(
        retry: null,
        name: r'saveStudyAsTemplateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Saves one study from the open document as a template.

  SaveStudyAsTemplateProvider call({
    required String studyId,
    required bool includeDemand,
  }) => SaveStudyAsTemplateProvider._(
    argument: (studyId: studyId, includeDemand: includeDemand),
    from: this,
  );

  @override
  String toString() => r'saveStudyAsTemplateProvider';
}

/// Applies a template to the project that is open.
///
/// Throws when nothing is open: a template has nowhere to land without a plant
/// to bind against, which is why the screen disables Apply rather than letting
/// it fail here.

@ProviderFor(applyTemplate)
final applyTemplateProvider = ApplyTemplateFamily._();

/// Applies a template to the project that is open.
///
/// Throws when nothing is open: a template has nowhere to land without a plant
/// to bind against, which is why the screen disables Apply rather than letting
/// it fail here.

final class ApplyTemplateProvider
    extends
        $FunctionalProvider<
          AsyncValue<BindingResult>,
          BindingResult,
          FutureOr<BindingResult>
        >
    with $FutureModifier<BindingResult>, $FutureProvider<BindingResult> {
  /// Applies a template to the project that is open.
  ///
  /// Throws when nothing is open: a template has nowhere to land without a plant
  /// to bind against, which is why the screen disables Apply rather than letting
  /// it fail here.
  ApplyTemplateProvider._({
    required ApplyTemplateFamily super.from,
    required File super.argument,
  }) : super(
         retry: null,
         name: r'applyTemplateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$applyTemplateHash();

  @override
  String toString() {
    return r'applyTemplateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<BindingResult> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BindingResult> create(Ref ref) {
    final argument = this.argument as File;
    return applyTemplate(ref, file: argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ApplyTemplateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$applyTemplateHash() => r'91b65f7dd14ba79ce2e87268ffc72afee7ec4d59';

/// Applies a template to the project that is open.
///
/// Throws when nothing is open: a template has nowhere to land without a plant
/// to bind against, which is why the screen disables Apply rather than letting
/// it fail here.

final class ApplyTemplateFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<BindingResult>, File> {
  ApplyTemplateFamily._()
    : super(
        retry: null,
        name: r'applyTemplateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Applies a template to the project that is open.
  ///
  /// Throws when nothing is open: a template has nowhere to land without a plant
  /// to bind against, which is why the screen disables Apply rather than letting
  /// it fail here.

  ApplyTemplateProvider call({required File file}) =>
      ApplyTemplateProvider._(argument: file, from: this);

  @override
  String toString() => r'applyTemplateProvider';
}
