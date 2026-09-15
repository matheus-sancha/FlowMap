import 'dart:convert';
import 'dart:io';

import 'package:flowmap/src/features/documents/data/document_migration.dart';
import 'package:flowmap/src/features/documents/data/recent_documents.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A recent list is a convenience, so the only real risk is that it starts
/// behaving as though it were a record — forgetting a document because a drive
/// was offline, or refusing to work because its own storage went bad.
class _MemorySettings implements SettingsAccess {
  final _values = <String, String>{};
  @override
  Future<String?> get(String key) async => _values[key];
  @override
  Future<void> set(String key, String value) async => _values[key] = value;
}

void main() {
  late _MemorySettings settings;
  late RecentDocuments recents;

  setUp(() {
    settings = _MemorySettings();
    recents = RecentDocuments(settings);
  });

  test('the newest is first', () async {
    await recents.remember(r'C:\a.flowmap', name: 'A');
    await recents.remember(r'C:\b.flowmap', name: 'B');

    final list = await recents.load();
    expect(list.map((d) => d.name), ['B', 'A']);
  });

  test('reopening a document moves it up rather than duplicating it', () async {
    await recents.remember(r'C:\a.flowmap', name: 'A');
    await recents.remember(r'C:\b.flowmap', name: 'B');
    await recents.remember(r'C:\a.flowmap', name: 'A');

    final list = await recents.load();
    expect(list.map((d) => d.name), ['A', 'B']);
  });

  test('the name follows the project, not the file', () async {
    // The list reads in the user's words. A project renamed inside the document
    // shows its new name the next time it is opened.
    await recents.remember(r'C:\plan.flowmap', name: 'Plan Q1');
    await recents.remember(r'C:\plan.flowmap', name: 'Plan Q2');

    expect((await recents.load()).single.name, 'Plan Q2');
  });

  test('the list is capped', () async {
    for (var i = 0; i < RecentDocuments.limit + 5; i++) {
      await recents.remember('C:\\doc$i.flowmap', name: 'Doc $i');
    }
    final list = await recents.load();
    expect(list, hasLength(RecentDocuments.limit));
    expect(list.first.name, 'Doc ${RecentDocuments.limit + 4}');
  });

  test('a document that cannot be found is kept, not pruned', () async {
    // These files live on shared drives and in synced folders, so "not there"
    // usually means the VPN dropped — a fact about the machine, never a reason
    // to forget the work.
    await recents.remember(r'\\fileserver\flowmap\Celula-11.flowmap', name: 'C');

    final list = await recents.load();
    expect(list, hasLength(1));
    expect(list.single.exists, isFalse);
    expect(list.single.folder, r'\\fileserver\flowmap');
  });

  test('forgetting removes one deliberately', () async {
    await recents.remember(r'C:\a.flowmap', name: 'A');
    await recents.remember(r'C:\b.flowmap', name: 'B');

    final list = await recents.forget(r'C:\a.flowmap');
    expect(list.map((d) => d.name), ['B']);
  });

  test('a corrupt list costs the convenience and nothing else', () async {
    await settings.set(RecentDocuments.settingKey, 'not json at all');
    expect(await recents.load(), isEmpty);

    // And it recovers the moment something is opened.
    await recents.remember(r'C:\a.flowmap', name: 'A');
    expect((await recents.load()).single.name, 'A');
  });

  test('an entry missing its fields is skipped, not fatal', () async {
    await settings.set(
      RecentDocuments.settingKey,
      jsonEncode([
        {'name': 'no path at all'},
        {'path': r'C:\good.flowmap', 'name': 'Good'},
      ]),
    );

    final list = await recents.load();
    expect(list.map((d) => d.name), ['Good']);
  });

  test('an entry with only a path still names itself', () async {
    await settings.set(
      RecentDocuments.settingKey,
      jsonEncode([
        {'path': r'C:\Celula-11.flowmap'},
      ]),
    );
    expect((await recents.load()).single.name, 'Celula-11');
  });

  test('a real file reports that it exists', () async {
    final dir = Directory.systemTemp.createTempSync('flowmap_recent');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'here.flowmap'))
      ..writeAsBytesSync([1]);

    await recents.remember(file.path, name: 'Here');
    expect((await recents.load()).single.exists, isTrue);
  });
}
