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

String _$templatesHash() => r'4893f848cab6725c33ecb658017d3285f5cb16a9';
