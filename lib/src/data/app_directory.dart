import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The one directory every piece of on-device state lives under: the Drift
/// database, the diagnostics log, the window geometry file, and the base that a
/// `.flowmap` export's relative paths resolve against. They all must agree on
/// it, so they all resolve it through here rather than each calling
/// `path_provider` directly.
///
/// **Windows deliberately does not use the documents directory.**
/// `getApplicationDocumentsDirectory()` returns the *redirected* Documents
/// folder, and OneDrive's Known Folder Move — on by default in most Microsoft
/// 365 setups, which is exactly the environment a manufacturing engineer's PC
/// is in — places that inside a sync root. A sync client that uploads a live
/// SQLite file and its `-wal` sidecar mid-write can corrupt the database, and
/// can hold a lock while the app has the file open. Application Support
/// (`%APPDATA%\Matheus Sancha\FlowMap`) is never redirected.
///
/// **Its name is the exe's CompanyName and ProductName**, which is how
/// `path_provider` builds it — so editing `Runner.rc` moves every user's data.
/// 2.1.3 did exactly that, unnoticed; [adoptLegacyDataFolder] is the repair.
Future<Directory> appDataDirectory() {
  if (Platform.isWindows) return getApplicationSupportDirectory();
  return getApplicationDocumentsDirectory();
}

/// Where every build up to 2.1.2 kept its data: `%APPDATA%\com.sancha\flowmap`,
/// from the placeholder names `flutter create` wrote into `Runner.rc`.
Directory? legacyAppDataDirectory() {
  final appData = Platform.environment['APPDATA'];
  if (!Platform.isWindows || appData == null) return null;
  return Directory(p.join(appData, 'com.sancha', 'flowmap'));
}

/// What [adoptLegacyDataFolder] did, for the log.
typedef LegacyAdoption = ({List<String> copied, Object? error});

/// Brings the pre-2.1.3 data folder's contents into [current], once.
///
/// 2.1.3 corrected the exe's CompanyName and ProductName, and with them the
/// folder `path_provider` names — so an upgraded machine opened on an empty
/// database, and stored runs, settings and the log stayed behind where nothing
/// looks. Projects were never at risk; they are `.flowmap` files of the
/// user's own.
///
/// **Only when [current] has no database and [legacy] has one.** A machine
/// that already ran 2.1.3 has started a new database, and silently replacing it
/// with an older one would lose whatever was done since; the release notes
/// point those users at the old folder instead.
///
/// **Copied, never moved.** The old folder is left exactly as it was, so this
/// can go wrong in any way at all and nothing is lost. The database is written
/// under a temporary name and renamed last, so an interrupted copy leaves no
/// `flowmap.sqlite` and is simply tried again next launch. The
/// `flowmap.pre-v*.sqlite` backups stay behind: they are insurance for
/// upgrades long finished, and on a developer's machine they are gigabytes.
///
/// Returns null when there was nothing to do. Never throws: a copy that fails
/// must still let the app open, on a fresh database.
Future<LegacyAdoption?> adoptLegacyDataFolder({
  required Directory legacy,
  required Directory current,
}) async {
  const database = 'flowmap.sqlite';
  final copied = <String>[];
  try {
    if (!File(p.join(legacy.path, database)).existsSync()) return null;
    if (File(p.join(current.path, database)).existsSync()) return null;
    await current.create(recursive: true);

    Future<void> copy(String name, {bool overwrite = true}) async {
      final from = File(p.join(legacy.path, name));
      final to = File(p.join(current.path, name));
      if (!from.existsSync() || (!overwrite && to.existsSync())) return;
      await from.copy(to.path);
      copied.add(name);
    }

    // The sidecars first, and before the database appears: SQLite reads a
    // `-wal` beside the file it opens, so the pair has to arrive whole.
    await copy('$database-wal');
    await copy('$database-shm');
    // Not overwritten: after an interrupted attempt these already hold this
    // machine's newer state, and the database is what decides success.
    await copy('window.json', overwrite: false);
    await copy('log.txt', overwrite: false);

    final partial = File(p.join(current.path, '$database.adopting'));
    await File(p.join(legacy.path, database)).copy(partial.path);
    await partial.rename(p.join(current.path, database));
    copied.add(database);
    return (copied: copied, error: null);
  } catch (error) {
    return (copied: copied, error: error);
  }
}
