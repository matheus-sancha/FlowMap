import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'document_migration.dart';

/// One document the user has opened before.
class RecentDocument {
  const RecentDocument({
    required this.path,
    required this.name,
    required this.openedAt,
  });

  final String path;

  /// The project's name as the document last reported it, so the list reads in
  /// the user's words rather than in file names.
  final String name;
  final DateTime openedAt;

  String get fileName => p.basename(path);
  String get folder => p.dirname(path);

  /// Whether the file is there **right now**.
  ///
  /// Deliberately asked at render time rather than stored. A document on a
  /// network share or in OneDrive is missing whenever the drive is — which is
  /// a temporary fact about the machine, not a reason to forget the document.
  bool get exists => File(path).existsSync();

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'opened_at': openedAt.toIso8601String(),
  };

  static RecentDocument? fromJson(Map<String, dynamic> json) {
    final path = json['path'];
    if (path is! String || path.isEmpty) return null;
    return RecentDocument(
      path: path,
      name: json['name'] as String? ?? p.basenameWithoutExtension(path),
      openedAt:
          DateTime.tryParse(json['opened_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// The documents this machine has opened, newest first.
///
/// **A missing file is never pruned.** The documents this is built for live on
/// shared drives and in synced folders, so "not there" usually means the VPN
/// dropped rather than the work is gone. The list reports what it knows and the
/// screen says which entries it cannot currently see.
class RecentDocuments {
  const RecentDocuments(this._settings);

  final SettingsAccess _settings;

  static const settingKey = 'documents.recent';
  static const limit = 10;

  Future<List<RecentDocument>> load() async {
    final raw = await _settings.get(settingKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final entry in list)
          if (entry is Map<String, dynamic>)
            ?RecentDocument.fromJson(entry),
      ];
    } catch (_) {
      // A corrupt list is a lost convenience, never a lost document — the files
      // are still on disk and Open still works.
      return const [];
    }
  }

  /// Records [path] as the most recently opened, and returns the new list.
  ///
  /// Paths are compared case-insensitively on Windows, so opening the same
  /// document through `C:\` and `c:\` does not leave two entries that look
  /// identical and behave as one.
  Future<List<RecentDocument>> remember(
    String path, {
    required String name,
    DateTime? now,
  }) async {
    final existing = await load();
    final entry = RecentDocument(
      path: path,
      name: name,
      openedAt: now ?? DateTime.now(),
    );
    final kept = [
      entry,
      ...existing.where((d) => !_samePath(d.path, path)),
    ].take(limit).toList();
    await _save(kept);
    return kept;
  }

  /// Removes one entry — for a document the user has finished with, not for one
  /// that merely could not be found.
  Future<List<RecentDocument>> forget(String path) async {
    final kept = [
      for (final doc in await load())
        if (!_samePath(doc.path, path)) doc,
    ];
    await _save(kept);
    return kept;
  }

  Future<void> _save(List<RecentDocument> documents) => _settings.set(
    settingKey,
    jsonEncode([for (final doc in documents) doc.toJson()]),
  );

  static bool _samePath(String a, String b) => Platform.isWindows
      ? p.equals(a.toLowerCase(), b.toLowerCase())
      : p.equals(a, b);
}
