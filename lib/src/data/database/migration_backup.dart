import 'dart:io';
import 'dart:typed_data';

/// Copies the database aside before a migration is allowed to touch it.
///
/// **A migration cannot be made safe from the inside.** `onUpgrade`'s own
/// preamble says why: `alterTable` needs foreign keys off, SQLite refuses to
/// change that mid-transaction, so a step that throws leaves the file *part*
/// upgraded with its version counter unchanged. A machine here reached exactly
/// that state and could not be opened again at all. Every step now asks the
/// database what it has rather than trusting `from`, which is a real mitigation
/// — and it was learned when the only user was the author.
///
/// This does not prevent that failure. It makes it recoverable: the file as it
/// stood before the upgrade is sitting in the same folder, one rename away, and
/// *About → Open folder* is how a person who cannot read a stack trace is
/// walked to it.
///
/// **One backup, overwritten each time.** Keeping a chain was rejected: three
/// files that all look equally plausible to someone already in trouble, on a
/// disk nobody can inspect, at 170 MB each.
///
/// **What it protects is not the first drop.** A fresh install *creates* the
/// schema at the current version through `onCreate` rather than migrating to
/// it, so an employee's first launch runs no migration at all. This protects
/// the machine that already holds data — the developer's, and everyone's from
/// the second build onwards.
class MigrationBackup {
  const MigrationBackup._();

  /// The name a backup of [database] takes for a database at version [from].
  ///
  /// Named for the version being left rather than the one being entered: at the
  /// moment of copying, that is the only one that is true of the contents.
  static String backupNameFor(String databaseFileName, int from) {
    final stem = databaseFileName.endsWith('.sqlite')
        ? databaseFileName.substring(0, databaseFileName.length - 7)
        : databaseFileName;
    return '$stem.pre-v$from.sqlite';
  }

  /// Copies [file] aside when opening it would run a migration.
  ///
  /// Returns the backup written, or null when none was needed — a fresh
  /// install, a database already at [schemaVersion], or one whose version
  /// cannot be read.
  ///
  /// **Never throws.** A backup that fails must not be the thing that stops the
  /// app opening: the copy is insurance, and insurance that can deny you the
  /// building is worse than none. A failure is reported through [onError] so
  /// the caller can log it, and the open proceeds.
  static Future<File?> copyAside(
    File file, {
    required int schemaVersion,
    void Function(Object error)? onError,
  }) async {
    try {
      if (!file.existsSync()) return null;

      final from = _userVersion(file);
      // 0 is a database with no schema yet — `onCreate` territory, nothing to
      // lose. A version at or above ours runs no upgrade step.
      if (from == null || from == 0 || from >= schemaVersion) return null;

      final name = backupNameFor(_basename(file.path), from);
      final backup = File('${_dirname(file.path)}$name');
      await file.copy(backup.path);
      return backup;
    } catch (error) {
      onError?.call(error);
      return null;
    }
  }

  /// Reads `user_version` out of the file header, opening no connection.
  ///
  /// The SQLite file format fixes it: a 100-byte header beginning with the
  /// string `SQLite format 3\0`, carrying `user_version` as a **4-byte
  /// big-endian integer at offset 60**. Reading it as bytes is what lets this
  /// answer *"would opening this migrate it?"* **strictly before** anything is
  /// in a position to — a connection, even a read-only one, can create sidecar
  /// files and take locks on the very file we are about to copy.
  ///
  /// Returns null for a file that is not a SQLite database, or is too short to
  /// be one: both mean there is nothing here worth copying.
  static int? _userVersion(File file) {
    RandomAccessFile? handle;
    try {
      handle = file.openSync();
      final header = handle.readSync(64);
      if (header.length < 64) return null;

      const magic = 'SQLite format 3';
      for (var i = 0; i < magic.length; i++) {
        if (header[i] != magic.codeUnitAt(i)) return null;
      }

      return ByteData.sublistView(header).getUint32(60);
    } catch (_) {
      return null;
    } finally {
      handle?.closeSync();
    }
  }

  static String _basename(String path) {
    final i = path.lastIndexOf(RegExp(r'[/\\]'));
    return i == -1 ? path : path.substring(i + 1);
  }

  static String _dirname(String path) {
    final i = path.lastIndexOf(RegExp(r'[/\\]'));
    return i == -1 ? '' : path.substring(0, i + 1);
  }
}
