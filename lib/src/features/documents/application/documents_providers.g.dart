// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'documents_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(recentDocumentsStore)
final recentDocumentsStoreProvider = RecentDocumentsStoreProvider._();

final class RecentDocumentsStoreProvider
    extends
        $FunctionalProvider<RecentDocuments, RecentDocuments, RecentDocuments>
    with $Provider<RecentDocuments> {
  RecentDocumentsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentDocumentsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentDocumentsStoreHash();

  @$internal
  @override
  $ProviderElement<RecentDocuments> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RecentDocuments create(Ref ref) {
    return recentDocumentsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RecentDocuments value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RecentDocuments>(value),
    );
  }
}

String _$recentDocumentsStoreHash() =>
    r'586b7b06bc66aa666d41a850c6ea2bcc7663609f';

/// The recent list, newest first.

@ProviderFor(recentDocuments)
final recentDocumentsProvider = RecentDocumentsProvider._();

/// The recent list, newest first.

final class RecentDocumentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<RecentDocument>>,
          List<RecentDocument>,
          FutureOr<List<RecentDocument>>
        >
    with
        $FutureModifier<List<RecentDocument>>,
        $FutureProvider<List<RecentDocument>> {
  /// The recent list, newest first.
  RecentDocumentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'recentDocumentsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$recentDocumentsHash();

  @$internal
  @override
  $FutureProviderElement<List<RecentDocument>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<RecentDocument>> create(Ref ref) {
    return recentDocuments(ref);
  }
}

String _$recentDocumentsHash() => r'90a5d765f68cd77f8b534766c5169367ecdfe52b';

/// Converts any pre-document projects the first time the app runs, and reports
/// what it wrote so the start screen can show them.
///
/// Runs once per machine and is a no-op everywhere else — see
/// [DocumentMigration].

@ProviderFor(convertedDocuments)
final convertedDocumentsProvider = ConvertedDocumentsProvider._();

/// Converts any pre-document projects the first time the app runs, and reports
/// what it wrote so the start screen can show them.
///
/// Runs once per machine and is a no-op everywhere else — see
/// [DocumentMigration].

final class ConvertedDocumentsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<File>>,
          List<File>,
          FutureOr<List<File>>
        >
    with $FutureModifier<List<File>>, $FutureProvider<List<File>> {
  /// Converts any pre-document projects the first time the app runs, and reports
  /// what it wrote so the start screen can show them.
  ///
  /// Runs once per machine and is a no-op everywhere else — see
  /// [DocumentMigration].
  ConvertedDocumentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'convertedDocumentsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$convertedDocumentsHash();

  @$internal
  @override
  $FutureProviderElement<List<File>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<File>> create(Ref ref) {
    return convertedDocuments(ref);
  }
}

String _$convertedDocumentsHash() =>
    r'fca42d4ebd97e471dc1facea3c1ef2b97004daaa';

/// The document that is open, or null when the app is showing the start screen.
///
/// **Resources and Settings stay reachable with nothing open.** With no
/// document, Resources shows the *library* — the plant `New project` seeds from
/// — which is what #37 left the local database holding. With a document open it
/// shows that document's plant, because a load replaces the working tables
/// whole.

@ProviderFor(OpenDocument)
final openDocumentProvider = OpenDocumentProvider._();

/// The document that is open, or null when the app is showing the start screen.
///
/// **Resources and Settings stay reachable with nothing open.** With no
/// document, Resources shows the *library* — the plant `New project` seeds from
/// — which is what #37 left the local database holding. With a document open it
/// shows that document's plant, because a load replaces the working tables
/// whole.
final class OpenDocumentProvider
    extends $NotifierProvider<OpenDocument, DocumentSession?> {
  /// The document that is open, or null when the app is showing the start screen.
  ///
  /// **Resources and Settings stay reachable with nothing open.** With no
  /// document, Resources shows the *library* — the plant `New project` seeds from
  /// — which is what #37 left the local database holding. With a document open it
  /// shows that document's plant, because a load replaces the working tables
  /// whole.
  OpenDocumentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openDocumentProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openDocumentHash();

  @$internal
  @override
  OpenDocument create() => OpenDocument();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DocumentSession? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DocumentSession?>(value),
    );
  }
}

String _$openDocumentHash() => r'cf22df8375ed40a473e9cabae42af771e3ac0f58';

/// The document that is open, or null when the app is showing the start screen.
///
/// **Resources and Settings stay reachable with nothing open.** With no
/// document, Resources shows the *library* — the plant `New project` seeds from
/// — which is what #37 left the local database holding. With a document open it
/// shows that document's plant, because a load replaces the working tables
/// whole.

abstract class _$OpenDocument extends $Notifier<DocumentSession?> {
  DocumentSession? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DocumentSession?, DocumentSession?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DocumentSession?, DocumentSession?>,
              DocumentSession?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
