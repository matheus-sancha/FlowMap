import 'dart:io';

import 'package:flowmap/src/features/documents/application/documents_providers.dart';
import 'package:flowmap/src/features/documents/data/recent_documents.dart';
import 'package:flowmap/src/features/documents/presentation/documents_screen.dart';
import 'package:flowmap/src/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Nothing in this suite renders a pixel, which every phase of this map says of
/// itself — so none of this claims the screen *looks* right. What it holds down
/// is the part a drive sheet cannot check cheaply: that a document which is not
/// currently reachable still appears, still names its folder, and says so in
/// words rather than by vanishing.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('flowmap_screen'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<AppLocalizations> pump(
    WidgetTester tester, {
    required List<RecentDocument> recents,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recentDocumentsProvider.overrideWith((ref) async => recents),
          // The conversion is a one-machine affair with its own tests; the
          // screen only has to not wait on it.
          convertedDocumentsProvider.overrideWith((ref) async => <File>[]),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: DocumentsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.delegate.load(const Locale('en'));
  }

  testWidgets('with nothing open it offers a way in, not an empty list', (
    tester,
  ) async {
    final l10n = await pump(tester, recents: const []);

    expect(find.text(l10n.documentsNone), findsOneWidget);
    expect(find.text(l10n.documentsOpen), findsOneWidget);
    expect(find.text(l10n.documentsNew), findsOneWidget);
    // No recent heading when there is nothing recent: an empty heading is
    // furniture.
    expect(find.text(l10n.documentsRecent), findsNothing);
  });

  testWidgets('a recent document shows its project name, not its file name', (
    tester,
  ) async {
    final file = File(p.join(dir.path, 'Celula-11.flowmap'))
      ..writeAsBytesSync([1]);
    final l10n = await pump(
      tester,
      recents: [
        RecentDocument(
          path: file.path,
          name: 'Plan Q1',
          openedAt: DateTime(2026, 9, 12),
        ),
      ],
    );

    // The list reads in the user's words; the file name is a detail of where it
    // happens to live.
    expect(find.text(l10n.documentsRecent), findsOneWidget);
    expect(find.text('Plan Q1'), findsOneWidget);
    expect(find.textContaining(dir.path), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
  });

  testWidgets('a document on a drive that is not connected still appears', (
    tester,
  ) async {
    // The claim that matters. These files live on shares and in synced folders,
    // so "not there" is usually a fact about this minute — it must not read as
    // "gone", and the entry must not quietly disappear.
    final l10n = await pump(
      tester,
      recents: [
        RecentDocument(
          path: r'\\fileserver\flowmap\Celula-11.flowmap',
          name: 'On the share',
          openedAt: DateTime(2026, 9, 12),
        ),
      ],
    );

    expect(find.text('On the share'), findsOneWidget);
    expect(find.textContaining(l10n.documentsMissing), findsOneWidget);
    expect(find.textContaining(r'\\fileserver\flowmap'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
  });
}
